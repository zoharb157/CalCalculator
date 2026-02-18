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
            if !newValue {
                isPresented = false
                NotificationCenter.default.post(name: .paywallDismissed, object: nil)
            }
        }
    }
}

#Preview {
    Text("Tap to show paywall")
}
