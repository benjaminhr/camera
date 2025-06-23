//
//  CameraControlsPreview.swift
//  camera
//
//  Created by Benjamin Robson on 14.6.2025.
//

import SwiftUI
import AVFoundation

struct CameraControlsPreview: View {
    @StateObject var camera: Camera
    
//    @State private var iso: Float = 800
    @State private var exposureValue: Double = 0.01
    @State private var temperature: Float = 5000
    @State private var tint: Float = 0
    
    var body: some View {
        VStack(spacing: 24) {
            Group {
                VStack(alignment: .leading) {
                    Text("ISO")
                        .font(.headline)
                    HStack {
                        Slider(value: Binding(
                            get: { Double(camera.deviceISO) },
                            set: { camera.deviceISO = Float($0) }
                        ), in: 35...3260, step: 100)
                            .accentColor(.orange)
                        Text("\(Int(camera.deviceISO))")
                            .frame(width: 50, alignment: .trailing)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Exposure")
                        .font(.headline)
                    HStack {
                        Slider(value: $exposureValue, in: 0.000014...1, step: 0.001)
                            .accentColor(.blue)
                        Text("1/\(max(1, Int(1.0 / exposureValue)))s")
                            .frame(width: 70, alignment: .trailing)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Group {
                VStack(alignment: .leading) {
                    Text("Temperature")
                        .font(.headline)
                    HStack {
                        Slider(value: $temperature, in: 3000...8000, step: 100)
                            .accentColor(.red)
                        Text("\(Int(temperature))K")
                            .frame(width: 60, alignment: .trailing)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Tint")
                        .font(.headline)
                    HStack {
                        Slider(value: $tint, in: -100...100, step: 1)
                            .accentColor(.green)
                        Text("\(Int(tint))")
                            .frame(width: 40, alignment: .trailing)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Button(action: {
                let exposureTime = CMTimeMakeWithSeconds(exposureValue, preferredTimescale: 1_000_000)
                camera.setExposureAndISO(exposureDuration: exposureTime, iso: Float(camera.deviceISO))
                camera.setWhiteBalance(temperature: temperature, tint: tint)
            }) {
                Text("Apply")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
}
