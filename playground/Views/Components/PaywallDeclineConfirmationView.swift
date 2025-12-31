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
    
    private var isSmallScreen: Bool {
        UIScreen.main.bounds.width < 375 // iPhone SE and similar small devices
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return ZStack {
            // Dark overlay - no padding
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Modal card - matching image design exactly
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
                        // Dismiss the confirmation modal immediately
                        isPresented = false
                        // Show paywall immediately
                        paywallTask = Task { @MainActor in
                            // Show paywall if task wasn't cancelled
                            if !Task.isCancelled {
                                showPaywall = true
                            }
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
                    
                    // Not now button - also blue as shown in image
                    Button {
                        isPresented = false
                    } label: {
                        Text(localizationManager.localizedString(for: AppStrings.Premium.notNow))
                            .id("not-now-\(localizationManager.currentLanguage)")
                            .font(.system(size: isSmallScreen ? 15 : 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, isSmallScreen ? 12 : 14)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel(localizationManager.localizedString(for: AppStrings.Premium.skipFreeTrial))
                    .accessibilityHint("Dismisses this confirmation without starting free trial")
                }
            }
            .padding(isSmallScreen ? 20 : 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, isSmallScreen ? 16 : 20) // Reduced padding for small screens
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .onDisappear {
            // Cancel task if view is dismissed
            paywallTask?.cancel()
            paywallTask = nil
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

