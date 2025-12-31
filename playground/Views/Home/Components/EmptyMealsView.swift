//
//  EmptyMealsView.swift
//  playground
//
//  Empty state view for meals
//

import SwiftUI

struct EmptyMealsView: View {
    var onScanTapped: (() -> Void)? = nil
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return
        VStack(spacing: 12) {
            emptyIcon
            titleText
            descriptionText
            if onScanTapped != nil {
                actionButton
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    
    // MARK: - Private Views
    
    private var emptyIcon: some View {
        Image(systemName: "fork.knife.circle")
            .font(.system(size: 40))
            .foregroundColor(.gray.opacity(0.5))
    }
    
    private var titleText: some View {
        Text(localizationManager.localizedString(for: AppStrings.Home.noMealsYet))
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.primary)
    }
    
    private var descriptionText: some View {
        Text(localizationManager.localizedString(for: AppStrings.Home.tapToAddFirstMeal))
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if let onScanTapped = onScanTapped {
            Button(action: {
                HapticManager.shared.impact(.medium)
                onScanTapped()
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text(localizationManager.localizedString(for: AppStrings.Food.scan))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
            }
        }
    }
}

#Preview("Empty State") {
    EmptyMealsView()
}
