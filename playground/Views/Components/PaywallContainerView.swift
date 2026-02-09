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
    
    @State private var showingConfirmation = false
    @State private var internalPresented = true
    
    var body: some View {
        ZStack {
            SDKView(
                model: sdk,
                page: .splash,
                show: paywallBinding(showPaywall: $internalPresented, sdk: sdk),
                backgroundColor: Color(UIColor.systemBackground),
                ignoreSafeArea: true
            )
            
            if showingConfirmation {
                PaywallDismissConfirmationView(
                    onStay: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingConfirmation = false
                        }
                        Pixel.track("paywall_stay_tapped", type: .interaction)
                        internalPresented = true
                    },
                    onLeave: {
                        showingConfirmation = false
                        Pixel.track("paywall_leave_confirmed", type: .interaction)
                        isPresented = false
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .zIndex(100)
            }
        }
        .onAppear {
            Pixel.track("paywall_shown_\(source)", type: .transaction)
        }
        .onChange(of: internalPresented) { _, newValue in
            if !newValue && !sdk.isSubscribed {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    showingConfirmation = true
                }
                Pixel.track("paywall_dismiss_confirmation_shown", type: .transaction)
            } else if !newValue {
                isPresented = false
            }
        }
    }
}

#Preview {
    Text("Tap to show paywall")
}
