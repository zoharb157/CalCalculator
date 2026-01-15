//
//  SubscriptionPaywallView.swift
//  playground
//
//  Unified native StoreKit subscription paywall following SwiftUI guidelines
//

import SwiftUI
import StoreKit

/// Unified subscription paywall view following Apple's SwiftUI design guidelines
/// Combines subscription info and purchase flow in a single, polished view
struct SubscriptionPaywallView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showError = false
    @State private var showRestoreAlert = false
    @State private var hasLoadedProducts = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Section
                    heroSection
                    
                    // Features List
                    featuresSection
                    
                    // Subscription Options
                    subscriptionOptionsSection
                    
                    // Purchase Button
                    purchaseButtonSection
                    
                    // Legal Links
                    legalLinksSection
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(purchaseError ?? "An unknown error occurred")
            }
            .alert("Restore Purchases", isPresented: $showRestoreAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Restore") {
                    Task {
                        await restorePurchases()
                    }
                }
            } message: {
                Text("This will restore any previous purchases associated with your Apple ID.")
            }
        }
        .task {
            // Only load once per view appearance
            guard !hasLoadedProducts else { return }
            hasLoadedProducts = true
            
            // Load products
            await subscriptionManager.loadProducts()
            
            // Auto-select monthly subscription if available
            if selectedProduct == nil {
                if let monthly = subscriptionManager.products.first(where: { $0.id.contains("monthly") }) {
                    selectedProduct = monthly
                } else if let first = subscriptionManager.products.first {
                    selectedProduct = first
                }
            }
        }
        .onAppear {
            // If products were already loaded but we're reappearing, update selection
            if !subscriptionManager.products.isEmpty && selectedProduct == nil {
                if let monthly = subscriptionManager.products.first(where: { $0.id.contains("monthly") }) {
                    selectedProduct = monthly
                } else if let first = subscriptionManager.products.first {
                    selectedProduct = first
                }
            }
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 20)
            
            Text("CalorieVisionAI Premium")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            Text("Unlock advanced features and unlimited tracking")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium Features")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                SubscriptionFeatureRow(icon: "infinity", title: "Unlimited Food Scans", description: "No daily limits")
                SubscriptionFeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Advanced Progress Tracking", description: "Detailed analytics and insights")
                SubscriptionFeatureRow(icon: "calendar", title: "Custom Diet Plans", description: "Create and manage multiple plans")
                SubscriptionFeatureRow(icon: "flame.fill", title: "Exercise Tracking", description: "Log and track workouts")
                SubscriptionFeatureRow(icon: "chart.bar.fill", title: "Weight History", description: "Track your progress over time")
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Subscription Options Section
    
    private var subscriptionOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Your Plan")
                .font(.headline)
                .padding(.horizontal)
            
            if subscriptionManager.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading subscription plans...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if subscriptionManager.products.isEmpty || subscriptionManager.loadError != nil {
                errorStateView
            } else {
                // Adapt layout for iPad
                let columns = horizontalSizeClass == .regular ? 
                    [GridItem(.flexible()), GridItem(.flexible())] : 
                    [GridItem(.flexible())]
                
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(subscriptionManager.products, id: \.id) { product in
                        SubscriptionPlanCard(
                            product: product,
                            isSelected: selectedProduct?.id == product.id,
                            onSelect: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedProduct = product
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 24)
    }
    
    private var errorStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            Text("Unable to Load Plans")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(subscriptionManager.loadError ?? "Please check your internet connection and try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                Task {
                    hasLoadedProducts = false
                    await subscriptionManager.loadProducts()
                    // Auto-select after retry
                    if selectedProduct == nil {
                        if let monthly = subscriptionManager.products.first(where: { $0.id.contains("monthly") }) {
                            selectedProduct = monthly
                        } else if let first = subscriptionManager.products.first {
                            selectedProduct = first
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
    }
    
    // MARK: - Purchase Button Section
    
    private var purchaseButtonSection: some View {
        VStack(spacing: 12) {
            if let selectedProduct = selectedProduct {
                Button {
                    Task {
                        await purchaseProduct(selectedProduct)
                    }
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Subscribe")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isPurchasing || subscriptionManager.isLoading)
                .padding(.horizontal)
                
                // Restore Purchases Button
                Button {
                    showRestoreAlert = true
                } label: {
                    Text("Restore Purchases")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Legal Links Section
    
    private var legalLinksSection: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Link(destination: Config.termsURL) {
                    HStack {
                        Text("Terms of Use")
                            .font(.caption)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption2)
                    }
                    .foregroundStyle(.blue)
                }
                
                Link(destination: Config.privacyURL) {
                    HStack {
                        Text("Privacy Policy")
                            .font(.caption)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption2)
                    }
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            
            // Subscription Info (App Store Requirement)
            VStack(alignment: .leading, spacing: 8) {
                Text("Subscription Information")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    subscriptionInfoRow("Title", "CalorieVisionAI Premium")
                    subscriptionInfoRow("Type", "Auto-renewable subscription")
                    subscriptionInfoRow("Price", "Shown above for each plan")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
    
    private func subscriptionInfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text("\(label):")
                .fontWeight(.medium)
            Text(value)
        }
    }
    
    // MARK: - Actions
    
    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        
        do {
            let transaction = try await subscriptionManager.purchase(product)
            if transaction != nil {
                // Purchase successful - dismiss after a brief delay to show success
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                dismiss()
            }
        } catch {
            purchaseError = error.localizedDescription
            showError = true
        }
        
        isPurchasing = false
    }
    
    private func restorePurchases() async {
        await subscriptionManager.restorePurchases()
        // Check if restoration was successful
        if subscriptionManager.subscriptionStatus {
            dismiss()
        }
    }
}

// MARK: - Feature Row

private struct SubscriptionFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Subscription Plan Card

struct SubscriptionPlanCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                // Plan Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        // Best Value Badge for Yearly
                        if product.id.contains("yearly") {
                            Text("BEST VALUE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    
                    if let subscription = product.subscription {
                        HStack(spacing: 4) {
                            Text(subscription.subscriptionPeriod.unit.localizedDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            if let introDescription = subscription.introductoryOfferDescription {
                                Text("•")
                                    .foregroundStyle(.secondary)
                                Text(introDescription)
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Price
                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    if let subscription = product.subscription {
                        Text(pricePerMonth(for: product, subscription: subscription))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func pricePerMonth(for product: Product, subscription: Product.SubscriptionInfo) -> String {
        let period = subscription.subscriptionPeriod
        
        // Get locale from product's display price (parse currency symbol)
        let locale = Locale.current // Use current locale as fallback
        
        switch period.unit {
        case .week:
            // Approximate monthly price (4.33 weeks per month)
            let weeklyPrice = product.price
            let monthlyPrice = weeklyPrice * Decimal(433) / Decimal(100) // 4.33
            return formatPrice(monthlyPrice, locale: locale) + "/month"
        case .month:
            return "/month"
        case .year:
            // Calculate monthly equivalent
            let yearlyPrice = product.price
            let monthlyPrice = yearlyPrice / Decimal(12)
            return formatPrice(monthlyPrice, locale: locale) + "/month"
        @unknown default:
            return ""
        }
    }
    
    private func formatPrice(_ price: Decimal, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.maximumFractionDigits = 2
        return formatter.string(from: price as NSDecimalNumber) ?? ""
    }
}

// MARK: - Extensions

extension Product.SubscriptionPeriod.Unit {
    var localizedDescription: String {
        switch self {
        case .day:
            return "Daily"
        case .week:
            return "Weekly"
        case .month:
            return "Monthly"
        case .year:
            return "Yearly"
        @unknown default:
            return ""
        }
    }
}

extension Product.SubscriptionInfo {
    var introductoryOfferDescription: String? {
        guard let introOffer = introductoryOffer else { return nil }
        
        var parts: [String] = []
        
        // Handle payment mode - use if-else to avoid switch exhaustiveness issues
        if introOffer.paymentMode == .freeTrial {
            parts.append("Free trial")
        } else {
            parts.append("Introductory offer")
        }
        
        // Add period information
        let period = introOffer.period
        let unit = period.unit.localizedDescription.lowercased()
        parts.append("\(period.value) \(unit)")
        
        return parts.joined(separator: " ")
    }
}
