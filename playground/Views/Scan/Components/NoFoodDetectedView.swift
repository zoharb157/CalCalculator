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
    
    @State private var showingTips = false
    
    var body: some View {
        VStack(spacing: 24) {
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
            
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 40))
                .foregroundStyle(Color.orange)
        }
    }
    
    private var messageSection: some View {
        VStack(spacing: 8) {
            Text("No Food Detected")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message ?? "We couldn't identify any food in this image.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
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
                    Text("Tips for better results")
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
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            
            Button(action: onRetake) {
                Label("Take New Photo", systemImage: "camera.fill")
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
