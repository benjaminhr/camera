//
//  Camera.swift
//  camera
//
//  Created by Benjamin Robson on 12.6.2025.
//

import AVFoundation
import SwiftUI
import Vision

final class Camera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    
    @Published var detectedObjects: [CGRect] = []
    @Published var loaded: Bool = false
    @Published var deviceISO: Float = 0.0
    
    
    private var detectedObjectsWithTimestamp: [(rect: CGRect, timestamp: Date)] = []
    
    private lazy var context: CIContext = CIContext(options: nil)
    private lazy var colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()

    
    func start() {
        let device = self.getDevice()
        
        captureSession.beginConfiguration()
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: device),
            captureSession.canAddInput(videoDeviceInput)
            else { return }
        captureSession.addInput(videoDeviceInput)
        
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoFrameQueue"))
        
        captureSession.sessionPreset = .high
        captureSession.commitConfiguration()
            
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    func getDevice() -> AVCaptureDevice {
        if let device = AVCaptureDevice.default(.builtInDualCamera,
                                                for: .video, position: .back) {
            return device
        } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video, position: .back) {
            return device
        } else {
            fatalError("Missing expected back camera device.")
        }
    }
    
    func setExposureAndISO(exposureDuration: CMTime, iso: Float) {
        guard let device = (captureSession.inputs.first as? AVCaptureDeviceInput)?.device else {
            print("Camera device not available.")
            return
        }
        
        do {
            try device.lockForConfiguration()
            let clampedISO = max(device.activeFormat.minISO, min(iso, device.activeFormat.maxISO))
            
            let minDuration = device.activeFormat.minExposureDuration
            let maxDuration = device.activeFormat.maxExposureDuration
            
            print("iso", device.activeFormat.minISO, device.activeFormat.maxISO)
            print("exposure", minDuration, maxDuration)
            
            let clampedDuration = CMTimeMaximum(minDuration, CMTimeMinimum(exposureDuration, maxDuration))
            
            device.setExposureModeCustom(duration: clampedDuration, iso: clampedISO, completionHandler: nil)
            device.unlockForConfiguration()
            
        } catch {
            print("Failed to configure exposure/ISO: \(error)")
        }
    }
    
    func adjustISO(basedOn currentBrightness: Float) {
        guard let device = (captureSession.inputs.first as? AVCaptureDeviceInput)?.device else {
            print("Camera device not available.")
            return
        }
        
        do {
            try device.lockForConfiguration()
            let minISO = device.activeFormat.minISO
            let maxISO = device.activeFormat.maxISO
            let currentISO: Float = device.iso
            
            let targetBrightness: Float = 0.5
            let smoothingFactor: Float = 0.05
            
            let error = targetBrightness - currentBrightness
            
            let baseGain: Float = 100.0
            let powerFactor: Float = 2.0
            let minEffectiveGain: Float = 1.0

            let effectiveGain = baseGain * pow(abs(error), powerFactor)
            let clampedEffectiveGain = max(effectiveGain, minEffectiveGain)
            let isoAdjustment = pow(2, error * clampedEffectiveGain)
            
            var newISO = currentISO * isoAdjustment
            newISO = max(minISO, min(newISO, maxISO))
            let smoothedISO: Float = (currentISO * (1.0 - smoothingFactor)) + (newISO * smoothingFactor)
            
            device.setExposureModeCustom(duration: device.exposureDuration, iso: smoothedISO, completionHandler: nil)
            self.deviceISO = device.iso
            
            device.unlockForConfiguration()
          } catch {
            print("Error locking configuration: \(error)")
          }
    }
    
    func setWhiteBalance(temperature: Float, tint: Float) {
        guard let device = (captureSession.inputs.first as? AVCaptureDeviceInput)?.device else {
            print("Camera device not available.")
            return
        }
        
        let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
            temperature: temperature,
            tint: tint
        )
        
        let gains = device.deviceWhiteBalanceGains(for: temperatureAndTint)
        let clampedGains = clampWhiteBalanceGains(gains, device: device)
        
        do {
            try device.lockForConfiguration()
            device.setWhiteBalanceModeLocked(with: clampedGains, completionHandler: nil)
            device.unlockForConfiguration()
        } catch {
            print("Failed to set white balance: \(error)")
        }
    }
    
    private func clampWhiteBalanceGains(_ gains: AVCaptureDevice.WhiteBalanceGains, device: AVCaptureDevice) -> AVCaptureDevice.WhiteBalanceGains {
        var clampedGains = gains
        clampedGains.redGain = max(1.0, min(gains.redGain, device.maxWhiteBalanceGain))
        clampedGains.greenGain = max(1.0, min(gains.greenGain, device.maxWhiteBalanceGain))
        clampedGains.blueGain = max(1.0, min(gains.blueGain, device.maxWhiteBalanceGain))
        return clampedGains
    }
    
    func averageBrightness(ciImage: CIImage) -> Float {
        let extent = ciImage.extent
        let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: CIVector(cgRect: extent)])!
        guard let outputImage = filter.outputImage else { return 0 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        
        self.context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: self.colorSpace
        )

        let r = Float(bitmap[0]) / 255.0
        let g = Float(bitmap[1]) / 255.0
        let b = Float(bitmap[2]) / 255.0

        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let brightness = averageBrightness(ciImage: ciImage)
        
        DispatchQueue.main.async {
            self.adjustISO(basedOn: brightness)
        }
//
//        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
//        
//        do {
//            try handler.perform([visionRequest])
//        } catch {
//            print("Failed to perform Vision request: \(error)")
//        }
    }
    
    lazy var visionRequest: VNCoreMLRequest = {
        print("vision request")
        do {
            let model = try VNCoreMLModel(for: YOLOv3(configuration: MLModelConfiguration()).model)
            
            DispatchQueue.main.async {
                self.loaded = true
            }       
            
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
                let now = Date()
                
                DispatchQueue.main.async {
                    for result in results {
                        self?.detectedObjectsWithTimestamp.append((rect: result.boundingBox, timestamp: now))
                    }
                    
                    self?.detectedObjectsWithTimestamp = self?.detectedObjectsWithTimestamp.filter {
                        now.timeIntervalSince($0.timestamp) < 3
                    } ?? []
                    
                    if self?.detectedObjectsWithTimestamp.count ?? 0 > 10 {
                        self?.detectedObjectsWithTimestamp.removeFirst()
                    }
                    
                    withAnimation {
                        self?.detectedObjects = self?.detectedObjectsWithTimestamp.map { $0.rect } ?? []
                    }
//                    self?.detectedObjects = results.map { $0.boundingBox }
                }
            }
            request.imageCropAndScaleOption = .scaleFill
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
}
