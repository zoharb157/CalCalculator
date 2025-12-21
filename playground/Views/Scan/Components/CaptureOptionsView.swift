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
    
    var body: some View {
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
        Text("Capture Your Meal")
            .font(.title2)
            .fontWeight(.bold)
    }
    
    private var subtitleText: some View {
        Text("Take a photo or choose from your library")
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
        Button(action: onCamera) {
            Label("Take Photo", systemImage: "camera.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
    
    private var libraryButton: some View {
        Button(action: onPhotoLibrary) {
            Label("Choose from Library", systemImage: "photo.fill")
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
