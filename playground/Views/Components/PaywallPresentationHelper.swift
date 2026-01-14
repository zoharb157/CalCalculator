//
//  PaywallPresentationHelper.swift
//  playground
//
//  Helper for presenting native StoreKit paywall with App Store compliance
//

import SwiftUI
import StoreKit

/// Helper extension to present native StoreKit paywall
extension View {
    /// Presents native StoreKit paywall with App Store compliance
    /// - Parameters:
    ///   - isPresented: Binding to control paywall presentation
    func compliantPaywall(
        isPresented: Binding<Bool>
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            SubscriptionPaywallView()
        }
    }
}
