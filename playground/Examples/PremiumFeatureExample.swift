//
//  PremiumFeatureExample.swift
//  playground
//
//  Example implementations for locking/unlocking features based on subscription
//

import SwiftUI
import SDK

// MARK: - Example 1: Lock a Button
struct PremiumButtonExample: View {
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @State private var showPaywall = false
    
    var body: some View {
        Button("Premium Feature") {
            if isSubscribed {
                performPremiumAction()
            } else {
                showPaywall = true
            }
        }
        .disabled(!isSubscribed)
        .opacity(isSubscribed ? 1.0 : 0.5)
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
    
    private func performPremiumAction() {
        print("✅ Premium action performed")
    }
}

// MARK: - Example 2: Lock a View/Screen
struct PremiumScreenExample: View {
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @State private var showPaywall = false
    
    var body: some View {
        if isSubscribed {
            premiumContentView
        } else {
            lockedContentView
        }
    }
    
    private var premiumContentView: some View {
        VStack {
            Text("Premium Content")
                .font(.title)
            Text("This is only available to premium users")
        }
    }
    
    private var lockedContentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Premium Feature")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Subscribe to unlock this feature")
                .foregroundColor(.secondary)
            
            Button("Subscribe") {
                showPaywall = true
            }
            .buttonStyle(.borderedProminent)
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

// MARK: - Example 3: Limit Free Usage
struct LimitedUsageExample: View {
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @State private var usageCount = 0
    @State private var showPaywall = false
    
    private let freeLimit = 5 // Free users get 5 uses
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Usage: \(usageCount)")
                .font(.title2)
            
            if !isSubscribed {
                Text("Free limit: \(freeLimit)")
                    .foregroundColor(.secondary)
            }
            
            Button("Use Feature") {
                if isSubscribed || usageCount < freeLimit {
                    useFeature()
                    usageCount += 1
                } else {
                    showPaywall = true
                }
            }
            .disabled(!isSubscribed && usageCount >= freeLimit)
            .opacity((isSubscribed || usageCount < freeLimit) ? 1.0 : 0.5)
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
    
    private func useFeature() {
        print("✅ Feature used")
    }
}

// MARK: - Example 4: Conditional UI Elements
struct ConditionalUIExample: View {
    @Environment(\.isSubscribed) private var isSubscribed
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome")
                .font(.title)
            
            // Premium badge
            if isSubscribed {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Premium")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(8)
            }
            
            // Premium features section
            if isSubscribed {
                premiumFeaturesSection
            }
        }
    }
    
    private var premiumFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Premium Features")
                .font(.headline)
            
            Text("• Advanced analytics")
            Text("• Export data")
            Text("• Custom goals")
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Example 5: Check Before Action
struct CheckBeforeActionExample: View {
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @State private var showPaywall = false
    
    var body: some View {
        Button("Scan Food") {
            scanFood()
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
    
    private func scanFood() {
        guard isSubscribed else {
            showPaywall = true
            return
        }
        
        // Perform scan
        performScan()
    }
    
    private func performScan() {
        print("✅ Scanning food...")
    }
}

// MARK: - Example 6: Refresh Subscription Status
struct RefreshStatusExample: View {
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    
    var body: some View {
        List {
            Section("Subscription") {
                HStack {
                    Text("Status")
                    Spacer()
                    if isSubscribed {
                        Text("Premium")
                            .foregroundColor(.green)
                    } else {
                        Text("Free")
                            .foregroundColor(.gray)
                    }
                }
                
                Button("Refresh Status") {
                    Task {
                        do {
                            try await sdk.updateIsSubscribed()
                            print("✅ Subscription status refreshed")
                        } catch {
                            print("❌ Failed to refresh: \(error)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("Premium Button") {
    PremiumButtonExample()
        .environment(TheSDK(config: .init(baseURL: URL(string: "https://example.com")!)))
        .environment(\.isSubscribed, false)
}

#Preview("Premium Screen") {
    PremiumScreenExample()
        .environment(TheSDK(config: .init(baseURL: URL(string: "https://example.com")!)))
        .environment(\.isSubscribed, false)
}

