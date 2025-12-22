//
//  CameraPermissionErrorView.swift
//
//  Camera permission error screen
//

import SwiftUI

struct CameraPermissionErrorView: View {
    @Environment(\.dismiss) private var dismiss
    let onOpenSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Oh no!")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
            
            Text("We can't see your camera")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("In order to scan your food, you must enable camera permissions")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                onOpenSettings()
            } label: {
                Text("Open settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(25)
            }
            .padding(.top, 8)
            
            Spacer()
            
            // Bottom bar
            HStack {
                Text("3 free scans left")
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    // Show premium
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("Premium")
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(20)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .overlay(
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    Button {
                        // Help
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        )
    }
}

#Preview {
    CameraPermissionErrorView {
        // Open settings
    }
}

