//
//  CaptureOptionsView.swift
//  playground
//
//  Scan view - Initial capture options
//

import SwiftUI

struct CaptureOptionsView: View {
    let onCamera: () -> Void
    let onPhotoLibrary: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        VStack(spacing: 32) {
            Spacer()
            iconView
            titleSection
            Spacer()
            actionButtons
        }
    }
    
    // MARK: - Private Views
    
    private var iconView: some View {
        Image(systemName: "camera.viewfinder")
            .font(.system(size: 80))
            .foregroundStyle(gradientStyle)
    }
    
    private var gradientStyle: LinearGradient {
        .linearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            titleText
            subtitleText
        }
    }
    
    private var titleText: some View {
        Text(localizationManager.localizedString(for: AppStrings.Scanning.captureYourMeal))
            .font(.title2)
            .fontWeight(.bold)
    }
    
    private var subtitleText: some View {
        Text(localizationManager.localizedString(for: AppStrings.Scanning.takePhotoOrChoose))
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            cameraButton
            libraryButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private var cameraButton: some View {
        Button(action: {
            onCamera()
        }) {
            Label(localizationManager.localizedString(for: AppStrings.Scanning.takePhoto), systemImage: "camera.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
    
    private var libraryButton: some View {
        Button(action: {
            onPhotoLibrary()
        }) {
            Label(localizationManager.localizedString(for: AppStrings.Scanning.chooseFromLibrary), systemImage: "photo.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.accentColor)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Preview

#Preview {
    CaptureOptionsView(
        onCamera: {},
        onPhotoLibrary: {}
    )
}
