//
//  SelectedImageView.swift
//  playground
//
//  Scan view - Selected image preview with actions
//

import SwiftUI

struct SelectedImageView: View {
    let image: UIImage
    let onAnalyze: () -> Void
    let onRetake: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return
        VStack(spacing: 24) {
            imagePreview
            Spacer()
            actionButtons
        }
    }
    
    // MARK: - Private Views
    
    private var imagePreview: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.horizontal)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            analyzeButton
            retakeButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private var analyzeButton: some View {
        Button(action: onAnalyze) {
            Label(localizationManager.localizedString(for: AppStrings.Scanning.analyzeMeal), systemImage: "sparkles")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(gradientBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
    
    private var gradientBackground: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var retakeButton: some View {
        Button(action: onRetake) {
            Text(localizationManager.localizedString(for: AppStrings.Scanning.retake))
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    SelectedImageView(
        image: UIImage(systemName: "photo.fill")!,
        onAnalyze: {},
        onRetake: {}
    )
}
