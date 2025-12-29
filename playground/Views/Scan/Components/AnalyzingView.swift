//
//  AnalyzingView.swift
//  playground
//
//  Scan view - Analyzing progress indicator with improved UX
//

import SwiftUI

struct AnalyzingView: View {
    let progress: Double
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var animating = false
    @State private var currentTip = 0
    
    private let tips = [
        "Identifying ingredients...",
        "Calculating portion sizes...",
        "Estimating nutritional values...",
        "Analyzing macros..."
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            progressIndicator
            textContent
            tipSection
            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            animating = true
            startTipRotation()
        }
    }
    
    // MARK: - Private Views
    
    private var progressIndicator: some View {
        ZStack {
            backgroundCircle
            progressCircle
            innerContent
        }
    }
    
    private var backgroundCircle: some View {
        Circle()
            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
            .frame(width: 120, height: 120)
    }
    
    private var progressCircle: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(gradientStyle, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .frame(width: 120, height: 120)
            .rotationEffect(.degrees(-90))
            .animation(.easeInOut(duration: 0.3), value: progress)
    }
    
    private var gradientStyle: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var innerContent: some View {
        VStack(spacing: 4) {
            sparkleIcon
            progressPercentage
        }
    }
    
    private var sparkleIcon: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 32))
            .foregroundStyle(iconGradient)
            .scaleEffect(animating ? 1.1 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: animating
            )
    }
    
    private var progressPercentage: some View {
        Text("\(Int(progress * 100))%")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
    }
    
    private var iconGradient: LinearGradient {
        .linearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var textContent: some View {
        VStack(spacing: 8) {
            titleText
            descriptionText
        }
    }
    
    private var titleText: some View {
        Text(localizationManager.localizedString(for: AppStrings.Food.analyzingYourMeal))
            .id("analyzing-meal-\(localizationManager.currentLanguage)")
            .font(.title3)
            .fontWeight(.semibold)
    }
    
    private var descriptionText: some View {
        Text(localizationManager.localizedString(for: AppStrings.Scanning.aiProcessing))
            .id("ai-processing-\(localizationManager.currentLanguage)")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
    }
    
    private var tipSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.purple.opacity(0.7))
            
            Text(tips[currentTip])
                .font(.footnote)
                .foregroundColor(.secondary)
                .animation(.easeInOut, value: currentTip)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.purple.opacity(0.1))
        .clipShape(Capsule())
    }
    
    // MARK: - Private Methods
    
    private func startTipRotation() {
        // Tip rotation removed - tips will be shown statically
        // If rotation is needed, it should be driven by actual analysis progress
    }
}

#Preview {
    AnalyzingView(progress: 0.6)
}
