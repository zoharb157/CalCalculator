//
//  NativePaywallView.swift
//  playground
//
//  Native StoreKit 2 paywall view following Apple Human Interface Guidelines
//

import SwiftUI
import StoreKit
import UIKit

/// Native paywall view built with StoreKit 2 following Apple HIG
struct NativePaywallView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Local state for UI
    @State private var selectedProduct: Product?
    @State private var isEligibleForTrial: Bool = false
    @State private var purchaseCompleted: Bool = false
    @State private var products: [Product] = []
    @State private var isLoading: Bool = true
    @State private var isPurchasing: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    /// Callback when paywall is dismissed
    var onDismiss: ((Bool) -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            VStack(spacing: 0) {
                // Close button
                closeButton
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Header with app icon and title
                        headerSection
                        
                        // Premium features list
                        featuresSection
                        
                        // Subscription plans
                        subscriptionPlansSection
                        
                        // Subscribe button
                        subscribeButton
                        
                        // Restore purchases & legal
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await loadProductData()
        }
        .onChange(of: purchaseCompleted) { _, completed in
            if completed {
                dismiss()
                onDismiss?(true)
            }
        }
        .alert("Purchase Error".localized, isPresented: $showError) {
            Button("OK".localized, role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred. Please try again.".localized)
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.04, green: 0.04, blue: 0.08)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
                onDismiss?(false)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.trailing, 16)
            .padding(.top, 12)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Premium badge icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.85, blue: 0.0),
                                Color(red: 1.0, green: 0.65, blue: 0.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }
            .shadow(color: Color.orange.opacity(0.5), radius: 24, x: 0, y: 12)
            
            // Title
            Text("Unlock Premium".localized)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Subtitle
            Text("Get unlimited access to all features".localized)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(spacing: 0) {
            PaywallFeatureRow(
                icon: "camera.viewfinder",
                iconColor: .blue,
                title: "Unlimited Food Scans".localized
            )
            
            PaywallFeatureRow(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: .green,
                title: "Advanced Progress Tracking".localized
            )
            
            PaywallFeatureRow(
                icon: "fork.knife.circle.fill",
                iconColor: .purple,
                title: "Custom Diet Plans".localized
            )
            
            PaywallFeatureRow(
                icon: "doc.text.fill",
                iconColor: .orange,
                title: "PDF Data Export".localized
            )
            
            PaywallFeatureRow(
                icon: "square.grid.2x2.fill",
                iconColor: .pink,
                title: "Premium Widgets".localized
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
    
    // MARK: - Subscription Plans Section
    
    private var subscriptionPlansSection: some View {
        VStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding(.vertical, 50)
            } else if products.isEmpty {
                VStack(spacing: 12) {
                    Text("Unable to load plans".localized)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Button {
                        Task {
                            await loadProductData()
                        }
                    } label: {
                        Text("Tap to Retry".localized)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 30)
            } else {
                ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                    SubscriptionPlanCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        isEligibleForTrial: isEligibleForTrial,
                        isBestValue: index == 0 // First product (yearly) is best value
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedProduct = product
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Subscribe Button
    
    private var subscribeButton: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await handlePurchase()
                }
            } label: {
                HStack(spacing: 10) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(buttonTitle)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.55, blue: 0.0),
                            Color(red: 1.0, green: 0.35, blue: 0.35)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.orange.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .disabled(selectedProduct == nil || isPurchasing)
            .opacity(selectedProduct == nil ? 0.5 : 1.0)
            .scaleEffect(isPurchasing ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPurchasing)
            
            // Cancel anytime notice for free trial
            if isEligibleForTrial, let product = selectedProduct, product.trialPeriodText != nil {
                Text("Cancel anytime during free trial".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.green.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            
            // Price description
            if let product = selectedProduct {
                Text(priceDescription(for: product))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 14) {
            // Restore purchases
            Button {
                Task {
                    await handleRestore()
                }
            } label: {
                Text("Restore Purchases".localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Legal links
            HStack(spacing: 24) {
                Button {
                    openURL("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                } label: {
                    Text("Terms of Use".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.35))
                }
                
                Button {
                    openURL("https://www.apple.com/legal/privacy/")
                } label: {
                    Text("Privacy Policy".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            
            // Subscription info
            Text("Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Payment will be charged to your Apple ID account.".localized)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.25))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.top, 4)
    }
    
    // MARK: - Helper Methods
    
    private var buttonTitle: String {
        if isEligibleForTrial, let product = selectedProduct, product.trialPeriodText != nil {
            return "Start Free Trial".localized
        }
        return "Continue".localized
    }
    
    private func priceDescription(for product: Product) -> String {
        if isEligibleForTrial, let trialText = product.trialPeriodText {
            return "\(trialText), then \(product.displayPrice) \(product.subscriptionPeriodText)"
        }
        return "\(product.displayPrice) \(product.subscriptionPeriodText)"
    }
    
    @MainActor
    private func loadProductData() async {
        isLoading = true
        
        let manager = SubscriptionManager.shared
        
        // Load products if needed
        if manager.products.isEmpty {
            await manager.loadProducts()
        }
        
        // Copy products to local state
        products = manager.products
        
        // Select first product (best value - yearly) by default
        if selectedProduct == nil, let firstProduct = products.first {
            selectedProduct = firstProduct
            isEligibleForTrial = await manager.isEligibleForIntroOffer(for: firstProduct)
        }
        
        isLoading = false
    }
    
    @MainActor
    private func handlePurchase() async {
        guard let product = selectedProduct else {
            errorMessage = "Please select a subscription plan.".localized
            showError = true
            return
        }
        
        isPurchasing = true
        errorMessage = nil
        
        let manager = SubscriptionManager.shared
        
        do {
            // Attempt purchase
            let transaction = try await manager.purchase(product)
            
            isPurchasing = false
            
            // Check if purchase was successful
            if transaction != nil {
                // Purchase completed successfully
                purchaseCompleted = true
            } else if manager.isSubscribed {
                // User already subscribed (restored)
                purchaseCompleted = true
            }
            // If transaction is nil and not subscribed, user likely cancelled - no error needed
        } catch {
            isPurchasing = false
            
            // Show error to user (unless it's a cancellation)
            let nsError = error as NSError
            // StoreKit error domain for user cancelled is SKErrorDomain with code 2
            if nsError.domain == "SKErrorDomain" && nsError.code == 2 {
                // User cancelled - don't show error
                return
            }
            
            // Check if it's a StoreKit.StoreKitError
            if let storeKitError = error as? StoreKitError {
                switch storeKitError {
                case .userCancelled:
                    // User cancelled - don't show error
                    return
                case .notAvailableInStorefront:
                    errorMessage = "This subscription is not available in your region.".localized
                case .networkError:
                    errorMessage = "Network error. Please check your connection and try again.".localized
                default:
                    errorMessage = "Purchase failed. Please try again.".localized
                }
            } else {
                errorMessage = "Purchase failed: \(error.localizedDescription)"
            }
            
            showError = true
        }
    }
    
    @MainActor
    private func handleRestore() async {
        isPurchasing = true
        
        let manager = SubscriptionManager.shared
        await manager.restorePurchases()
        
        isPurchasing = false
        
        if manager.isSubscribed {
            purchaseCompleted = true
        }
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Paywall Feature Row Component

private struct PaywallFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 28)
            
            // Title
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Subscription Plan Card

struct SubscriptionPlanCard: View {
    let product: Product
    let isSelected: Bool
    let isEligibleForTrial: Bool
    let isBestValue: Bool
    let onSelect: () -> Void
    
    private var isYearly: Bool {
        product.id.contains("yearly")
    }
    
    private var isMonthly: Bool {
        product.id.contains("monthly")
    }
    
    private var periodLabel: String {
        if isYearly {
            return "year".localized
        } else if isMonthly {
            return "month".localized
        } else {
            return "week".localized
        }
    }
    
    private var savingsText: String? {
        // Show savings percentage for yearly plan
        if isBestValue {
            return "BEST VALUE".localized
        }
        return nil
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color.orange : Color.white.opacity(0.25),
                            lineWidth: isSelected ? 2 : 1.5
                        )
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                    }
                }
                
                // Plan details
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(planTitle)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        // Best value badge
                        if let savings = savingsText {
                            Text(savings)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 1.0, green: 0.85, blue: 0.0),
                                                    Color(red: 1.0, green: 0.7, blue: 0.0)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                        
                        // Trial badge
                        if isEligibleForTrial, let trialText = product.trialPeriodText {
                            Text(shortTrialText(trialText))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.green)
                                )
                        }
                    }
                    
                    if isYearly {
                        Text(weeklyEquivalentPrice)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Price
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("/\(periodLabel)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.12 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isSelected ? Color.orange : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(ScalePressStyle())
    }
    
    private var planTitle: String {
        if isYearly {
            return "Yearly".localized
        } else if isMonthly {
            return "Monthly".localized
        } else {
            return "Weekly".localized
        }
    }
    
    private var weeklyEquivalentPrice: String {
        // Calculate weekly equivalent for yearly plan
        let yearlyPrice = product.price
        let weeklyEquivalent = yearlyPrice / 52
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        if let formatted = formatter.string(from: weeklyEquivalent as NSNumber) {
            return "\(formatted)/" + "week".localized
        }
        return ""
    }
    
    private func shortTrialText(_ text: String) -> String {
        // Convert "3-day free trial" to "3 DAYS FREE"
        let components = text.lowercased().components(separatedBy: " ")
        if let duration = components.first {
            return duration.uppercased() + " " + "FREE".localized
        }
        return "FREE TRIAL".localized
    }
}

// MARK: - Button Style

private struct ScalePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    NativePaywallView()
}
