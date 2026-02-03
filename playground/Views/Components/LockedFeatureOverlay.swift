//
//  LockedFeatureOverlay.swift
//  playground
//
//  Reusable lock overlay for premium features
//

import SwiftUI
import SDK

struct LockedFeatureOverlay: View {
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var showPaywall = false
    
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return Group {
            if !isSubscribed {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        
                        if let message = message {
                            Text(message)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        } else {
                            Text(localizationManager.localizedString(for: AppStrings.Premium.premiumFeature))
                                .font(.headline)
                                .foregroundColor(.white)
                                .id("premium-feature-\(localizationManager.currentLanguage)")
                        }
                        
                        Button(localizationManager.localizedString(for: AppStrings.Common.unlock)) {
                            showPaywall = true
                        }
                        .id("unlock-btn-\(localizationManager.currentLanguage)")
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(40)
                }
            } else {
                EmptyView()
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            SDKView(
                model: sdk,
                page: .splash,
                show: $showPaywall,
                backgroundColor: .white,
                ignoreSafeArea: true
            )
        }
    }
}

/// Shows content with empty data for non-subscribers, or full content for subscribers
/// For Progress page: uses reduced blur to show data behind
struct PremiumLockedContent<Content: View>: View {
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @State private var showPaywall = false
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    let content: Content
    let isProgressPage: Bool // Special handling for Progress page with reduced blur
    
    init(isProgressPage: Bool = false, @ViewBuilder content: () -> Content) {
        self.isProgressPage = isProgressPage
        self.content = content()
    }
    
    var body: some View {
        ZStack(alignment: .center) {
            if isSubscribed {
                content
            } else {
                if isProgressPage {
                    // Progress page: show content with moderate blur (teaser-style)
                    content
                        .blur(radius: 3) // Moderate blur - visible but clearly locked
                        .opacity(0.6) // Reduced opacity to indicate premium lock
                } else {
                    // Other pages: show content with blur and reduced opacity
                    content
                        .blur(radius: 4) // Standard blur for premium content
                        .opacity(0.5) // Reduced opacity to indicate premium lock
                }
            }
            
            if !isSubscribed {
                VStack {
                    Spacer()
                    
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text(localizationManager.localizedString(for: AppStrings.Premium.premium))
                                .font(.system(size: 15, weight: .bold))
                                .id("premium-text-\(localizationManager.currentLanguage)")
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            // Gold/yellow gradient matching reference app
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.85, blue: 0.0),  // Gold
                                    Color(red: 1.0, green: 0.92, blue: 0.3)   // Lighter gold
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
                    }
                    .accessibilityLabel(localizationManager.localizedString(for: AppStrings.Premium.upgradeToPremium))
                    .accessibilityHint("Opens the premium subscription screen")
                    .padding(.bottom, 16)
                    
                    Spacer()
                }
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            SDKView(
                model: sdk,
                page: .splash,
                show: paywallBinding(showPaywall: $showPaywall, sdk: sdk),
                backgroundColor: .white,
                ignoreSafeArea: true
            )
        }
    }
}

struct LockedButton: View {
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @State private var showPaywall = false
    
    let action: () -> Void
    let label: () -> AnyView
    
    init<Content: View>(@ViewBuilder label: @escaping () -> Content, action: @escaping () -> Void) {
        self.label = { AnyView(label()) }
        self.action = action
    }
    
    var body: some View {
        Button {
            if isSubscribed {
                action()
            } else {
                showPaywall = true
            }
        } label: {
            label()
        }
        .overlay(alignment: .topTrailing) {
            if !isSubscribed {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.orange)
                    .clipShape(Circle())
                    .offset(x: 4, y: -4)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            SDKView(
                model: sdk,
                page: .splash,
                show: $showPaywall,
                backgroundColor: .white,
                ignoreSafeArea: true
            )
        }
    }
}
