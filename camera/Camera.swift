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
    
    private var detectedObjectsWithTimestamp: [(rect: CGRect, timestamp: Date)] = []

    
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
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([visionRequest])
        } catch {
            print("Failed to perform Vision request: \(error)")
        }
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
