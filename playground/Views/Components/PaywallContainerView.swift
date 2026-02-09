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
                        internalPresented = true
                    },
                    onLeave: {
                        showingConfirmation = false
                        isPresented = false
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .zIndex(100)
            }
        }
        .onAppear {

        }
        .onChange(of: internalPresented) { _, newValue in
            if !newValue && !sdk.isSubscribed {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    showingConfirmation = true
                }
            } else if !newValue {
                isPresented = false
            }
        }
    }
}

#Preview {
    Text("Tap to show paywall")
}
