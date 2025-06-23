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
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            CameraPreview(session: camera.captureSession)
                .ignoresSafeArea()
                .onAppear {
                    camera.start()
                }

            VStack {
                if camera.mode == "algo" {
                    HStack {
                        Spacer()
                        Button(action: {
                            showSettings.toggle()
                        }) {
                            Image(systemName: "slider.horizontal.2.square")
                                .font(.title)
                                .padding(12)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Rectangle())
                                .cornerRadius(10)
                                .foregroundColor(Color.white)
                        }
                    }
                }
                
                
                HStack {
                    Spacer()
                    Button(action: {
                        if camera.mode == "vision" {
                            camera.mode = "algo"
                        } else {
                            camera.mode = "vision"
                        }
                    }) {
                        Image(systemName: "camera.aperture")
                            .font(.title)
                            .padding(12)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Rectangle())
                            .cornerRadius(10)
                            .foregroundColor(Color.white)
                    }
                    .padding(.top)
                }
            }
            .padding()

            if showSettings {
                CameraControlsPreview(camera: camera)
            }
            
            if camera.mode == "vision" {
                if !camera.loaded {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.3)
                        .padding(12)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Rectangle())
                        .cornerRadius(10)
                        .foregroundColor(Color.white)
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
                                    .frame(width: rect.width, height: rect.height)
                                    .position(x: rect.midX, y: rect.midY)
                                    .animation(.easeOut(duration: 0.3), value: camera.detectedObjects)
                                    .onAppear {
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                    }
                            }
                    }
                }
            }
            
        }
    }
}

