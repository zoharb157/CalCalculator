//
//  PaywallDeclineConfirmationView.swift
//  playground
//
//  Modal confirmation when user declines to purchase premium
//

import SwiftUI
import SDK

struct PaywallDeclineConfirmationView: View {
    @Environment(TheSDK.self) private var sdk
    @Binding var isPresented: Bool
    @Binding var showPaywall: Bool
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var paywallTask: Task<Void, Never>?
    @State private var animationTask: Task<Void, Never>?
    @State private var isAnimated: Bool = false
    
    private var isSmallScreen: Bool {
        UIScreen.main.bounds.width < 375 // iPhone SE and similar small devices
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return ZStack {
            // Full screen semi-transparent overlay - brighter for better visibility
            Color.black.opacity(0.4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all)
            
            // Modal card - centered both horizontally and vertically
            VStack(spacing: isSmallScreen ? 16 : 20) {
                // Title - exact text from image
                Text(localizationManager.localizedString(for: AppStrings.Premium.areYouSure))
                    .font(.system(size: isSmallScreen ? 18 : 20, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .id("are-you-sure-\(localizationManager.currentLanguage)")
                
                // Subtitle - exact text from image
                Text(localizationManager.localizedString(for: AppStrings.Premium.claimFreeTrial))
                    .font(.system(size: isSmallScreen ? 14 : 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .id("claim-free-trial-\(localizationManager.currentLanguage)")
                
                // Buttons - both blue as shown in image
                VStack(spacing: isSmallScreen ? 10 : 12) {
                    // Start Free Trial button - blue
                    Button {
                        // Cancel any existing task first
                        paywallTask?.cancel()
                        // Dismiss the confirmation modal first
                        isPresented = false
                        // Small delay to ensure modal is dismissed before showing paywall
                        paywallTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                            // Check if task wasn't cancelled before showing paywall
                            guard !Task.isCancelled else { return }
                            showPaywall = true
                        }
                    } label: {
                        Text(localizationManager.localizedString(for: AppStrings.Premium.startFreeTrial))
                            .font(.system(size: isSmallScreen ? 15 : 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, isSmallScreen ? 12 : 14)
                            .background(Color.blue)
                            .cornerRadius(12)
                            .id("start-free-trial-\(localizationManager.currentLanguage)")
                    }
                    .accessibilityLabel(localizationManager.localizedString(for: AppStrings.Premium.startFreeTrial))
                    .accessibilityHint("Opens the premium subscription screen to start your free trial")
                    
                    // Not now button - grey
                    Button {
                        isPresented = false
                    } label: {
                        Text(localizationManager.localizedString(for: AppStrings.Premium.notNow))
                            .id("not-now-\(localizationManager.currentLanguage)")
                            .font(.system(size: isSmallScreen ? 15 : 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, isSmallScreen ? 12 : 14)
                            .background(Color(uiColor: .systemGray))
                            .cornerRadius(12)
                    }
                    .accessibilityLabel(localizationManager.localizedString(for: AppStrings.Premium.skipFreeTrial))
                    .accessibilityHint("Dismisses this confirmation without starting free trial")
                }
            }
            .padding(isSmallScreen ? 20 : 24) // Padding only on the modal card content
            .frame(maxWidth: UIScreen.main.bounds.width - 32) // Horizontal padding from screen edges
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
            )
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) // Center both horizontally and vertically
            .scaleEffect(isAnimated ? 1.0 : 0.95) // Scale animation
            .opacity(isAnimated ? 1.0 : 0.0) // Fade animation
        }
        .ignoresSafeArea(.all)
        .onAppear {
            // Cancel any existing animation task
            animationTask?.cancel()
            
            // Start animation with proper cancellation handling using Task
            // This is better than DispatchQueue for Swift concurrency
            animationTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                // Check if view is still presented and task wasn't cancelled
                guard isPresented, !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isAnimated = true
                }
            }
        }
        .onDisappear {
            // Cancel all pending operations
            paywallTask?.cancel()
            paywallTask = nil
            animationTask?.cancel()
            animationTask = nil
            isAnimated = false
        }
    }
}

#Preview {
    @Previewable @State var showModal = true
    @Previewable @State var showPaywall = false
    
    PaywallDeclineConfirmationView(
        isPresented: $showModal,
        showPaywall: $showPaywall
    )
    .environment(TheSDK(config: .init(baseURL: URL(string: "https://example.com")!)))
}

