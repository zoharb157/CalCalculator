//
//  NoFoodDetectedView.swift
//  playground
//
//  Scan view - No food detected state
//

import SwiftUI

struct NoFoodDetectedView: View {
    let message: String?
    let image: Image?
    let onRetry: () -> Void
    let onRetake: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var showingTips = false
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(spacing: 24) {
            if let image = image {
                thumbnailImage(image)
            }
            
            iconSection
            messageSection
            tipsSection
            Spacer()
            actionButtons
        }
        .padding()
    }
    
    // MARK: - Private Views
    
    private func thumbnailImage(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.orange.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var iconSection: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.1))
                .frame(width: 80, height: 80)
            
            Image(systemName: iconName)
                .font(.system(size: 40))
                .foregroundStyle(Color.orange)
        }
    }
    
    private var iconName: String {
        // Check if the message indicates the item is not food (vs just no food detected)
        if let message = message?.lowercased() {
            let notFoodKeywords = ["not food", "not a food", "is not food", "does not contain food", "shows a", "this is not", "unable to provide"]
            if notFoodKeywords.contains(where: { message.contains($0) }) {
                return "exclamationmark.triangle.fill"
            }
        }
        return "fork.knife.circle"
    }
    
    private var messageSection: some View {
        VStack(spacing: 12) {
            Text(messageTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            if let message = message, !message.isEmpty {
                Text(message)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text(localizationManager.localizedString(for: AppStrings.Scanning.noFoodInImage))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .id("no-food-image-\(localizationManager.currentLanguage)")
            }
        }
        .padding(.horizontal)
    }
    
    private var messageTitle: String {
        // Check if the message indicates the item is not food (vs just no food detected)
        if let message = message?.lowercased() {
            let notFoodKeywords = ["not food", "not a food", "is not food", "does not contain food", "shows a", "this is not", "unable to provide"]
            if notFoodKeywords.contains(where: { message.contains($0) }) {
                return "Not Food Detected"
            }
        }
        return "No Food Detected"
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation {
                    showingTips.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(localizationManager.localizedString(for: AppStrings.Scanning.tipsForBetterResults))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: showingTips ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            
            if showingTips {
                VStack(alignment: .leading, spacing: 8) {
                    tipRow(icon: "sun.max.fill", text: "Use good lighting")
                    tipRow(icon: "camera.viewfinder", text: "Center the food in frame")
                    tipRow(icon: "arrow.up.left.and.arrow.down.right", text: "Get closer to the food")
                    tipRow(icon: "eye.fill", text: "Ensure food is clearly visible")
                }
                .padding(.horizontal, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button(action: onRetry) {
                Label(localizationManager.localizedString(for: AppStrings.Scanning.tryAgain), systemImage: "arrow.clockwise")
                    .id("try-again-scan-\(localizationManager.currentLanguage)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            
            Button(action: onRetake) {
                Label(localizationManager.localizedString(for: AppStrings.Scanning.takeNewPhoto), systemImage: "camera.fill")
                    .id("take-new-photo-\(localizationManager.currentLanguage)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.accentColor)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
}

#Preview {
    NoFoodDetectedView(
        message: "No food items detected in the image. Please ensure the image clearly shows food.",
        image: Image(systemName: "photo"),
        onRetry: {},
        onRetake: {}
    )
}
