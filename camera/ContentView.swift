//
//  ContentView.swift
//  camera
//
//  Created by Benjamin Robson on 14.6.2025.
//

import SwiftUI
import Vision

struct ContentView: View {
    @StateObject private var camera = Camera()
            
    var body: some View {
        ZStack {
            CameraPreview(session: camera.captureSession)
                .onAppear {
                    camera.start()
                }
                .ignoresSafeArea()
                
            if !camera.loaded {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                GeometryReader { geometry in
                    ForEach(Array(camera.detectedObjects.enumerated()), id: \.offset) { index, boundingBox in
                        let rect = VNImageRectForNormalizedRect(
                            boundingBox,
                            Int(geometry.size.width),
                            Int(geometry.size.height)
                        )
                        
                        RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 4)
                                .shadow(color: Color.white.opacity(0.6), radius: 10)
                                .blur(radius: 5)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                                .animation(.easeOut(duration: 0.6), value: camera.detectedObjects)
                                .onAppear {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }
                        }

//                        Path { path in
//                            path.addRect(rect)
//                        }
//                        .stroke(Color.white, lineWidth: 4)
//                        .shadow(color: Color.white.opacity(0.6), radius: 20)
//                        .transition(.scale.combined(with: .opacity))
//                        .animation(.easeInOut(duration: 1), value: camera.detectedObjects)
//                        .onAppear {
//                            let generator = UIImpactFeedbackGenerator(style: .medium)
//                            generator.impactOccurred()
//                        }
//                    }
                }
            }
        }
    }
}
