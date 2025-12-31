//
//  CameraPermissionErrorView.swift
//
//  Camera permission error screen
//

import SwiftUI

struct CameraPermissionErrorView: View {
    @Environment(\.dismiss) private var dismiss
    let onOpenSettings: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(spacing: 24) {
            Spacer()
            
            Text(localizationManager.localizedString(for: AppStrings.Scanning.ohNo))
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
            
            Text(localizationManager.localizedString(for: AppStrings.Scanning.weCantSeeYourCamera))
                .font(.title2)
                .foregroundColor(.white)
            
            Text(localizationManager.localizedString(for: AppStrings.Scanning.enableCameraPermissions))
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                onOpenSettings()
            } label: {
                Text(localizationManager.localizedString(for: AppStrings.Scanning.openSettings))
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
                Text(localizationManager.localizedString(for: AppStrings.Scanning.freeScansLeft))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    // Show premium
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text(localizationManager.localizedString(for: AppStrings.Premium.premium))
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

