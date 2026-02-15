//
//  PaywallContainerView.swift
//  playground
//

import SwiftUI
import SDK

struct PaywallContainerView: View {
    @Binding var isPresented: Bool
    let sdk: TheSDK
    var source: String = "unknown"
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var showingConfirmation = false
    @State private var internalPresented = true
    
    var body: some View {
        SDKView(
            model: sdk,
            page: .splash,
            show: paywallBinding(showPaywall: $internalPresented, sdk: sdk),
            backgroundColor: Color(UIColor.systemBackground),
            ignoreSafeArea: true
        )
        .onAppear {
            Pixel.track("paywall_shown_\(source)", type: .transaction)
        }
        .onChange(of: internalPresented) { _, newValue in
            if !newValue && !sdk.isSubscribed {
                showingConfirmation = true
            } else if !newValue {
                isPresented = false
                NotificationCenter.default.post(name: .paywallDismissed, object: nil)
            }
        }
        .alert(
            localizationManager.localizedString(for: "Are you sure you want to skip the free trial?"),
            isPresented: $showingConfirmation
        ) {
            Button(localizationManager.localizedString(for: "Start Free Trial")) {
                showingConfirmation = false
                internalPresented = true
            }
            Button(localizationManager.localizedString(for: "Not now")) {
                showingConfirmation = false
                isPresented = false
                NotificationCenter.default.post(name: .paywallDismissed, object: nil)
            }
        } message: {
            Text(localizationManager.localizedString(for: "Claim your free trial now without paying"))
        }
    }
}

#Preview {
    Text("Tap to show paywall")
}
