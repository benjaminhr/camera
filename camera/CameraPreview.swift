//
//  CameraUI.swift
//  camera
//
//  Created by Benjamin Robson on 13.6.2025.
//

import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    
    let session: AVCaptureSession
    
    class PreviewView: UIView {
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
        
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }
    }
    
    func makeUIView(context: Context) -> some PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
    
}
