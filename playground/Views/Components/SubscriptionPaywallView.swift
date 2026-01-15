//
//  SubscriptionPaywallView.swift
//  CalCalculator
//
//  Native StoreKit 2 paywall view
//

import SwiftUI
import StoreKit

/// Native paywall view using StoreKit 2
struct SubscriptionPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Features
                    featuresSection
                    
                    // Plans
                    plansSection
                    
                    // Purchase button
                    purchaseButton
                    
                    // Legal links
                    legalSection
                    
                    // Subscription info (App Store requirement)
                    subscriptionInfoSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseError ?? "An unknown error occurred")
            }
        }
        .task {
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
            // Auto-select yearly as default (best value)
            if selectedProduct == nil {
                selectedProduct = subscriptionManager.yearlyProduct ?? subscriptionManager.products.first
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 50))
                .foregroundStyle(.yellow.gradient)
            
            Text("Premium")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Unlock all features and reach your goals faster")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(spacing: 16) {
            FeatureRowView(
                icon: "doc.text.fill",
                iconColor: .blue,
                title: "Custom Diet Plans",
                subtitle: "Create and manage multiple plans"
            )
            
            FeatureRowView(
                icon: "flame.fill",
                iconColor: .orange,
                title: "Exercise Tracking",
                subtitle: "Log and track workouts"
            )
            
            FeatureRowView(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: .green,
                title: "Weight History",
                subtitle: "Track your progress over time"
            )
            
            FeatureRowView(
                icon: "sparkles",
                iconColor: .purple,
                title: "AI Analysis",
                subtitle: "Unlimited food analysis"
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Plans Section
    private var plansSection: some View {
        VStack(spacing: 12) {
            Text("Choose Your Plan")
                .font(.headline)
            
            if subscriptionManager.isLoading {
                ProgressView()
                    .padding()
            } else if let error = subscriptionManager.loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    
                    Text("Unable to Load Plans")
                        .font(.headline)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        Task {
                            await subscriptionManager.loadProducts()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                ForEach(subscriptionManager.products, id: \.id) { product in
                    PlanCardView(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        isBestValue: product.id == "calCalculator.yearly.premium"
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedProduct = product
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Purchase Button
    private var purchaseButton: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await purchase()
                }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "crown.fill")
                        Text("Subscribe Now")
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .disabled(selectedProduct == nil || isPurchasing || subscriptionManager.isLoading)
            .opacity(selectedProduct == nil ? 0.6 : 1)
            
            Button("Restore Purchases") {
                Task {
                    await restore()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Legal Section
    private var legalSection: some View {
        HStack(spacing: 20) {
            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                HStack(spacing: 4) {
                    Text("Terms of Use")
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption2)
                }
                .font(.caption)
            }
            
            Link(destination: URL(string: "https://caloriecount-ai.com/privacy")!) {
                HStack(spacing: 4) {
                    Text("Privacy Policy")
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption2)
                }
                .font(.caption)
            }
        }
        .foregroundStyle(.blue)
    }
    
    // MARK: - Subscription Info (App Store Requirement)
    private var subscriptionInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subscription Information")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Title: CalorieVisionAI Premium")
                Text("Type: Auto-renewable subscription")
                if let product = selectedProduct {
                    Text("Price: \(product.displayPrice) per \(periodName(for: product))")
                } else {
                    Text("Price: Shown above for each plan")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    private func purchase() async {
        guard let product = selectedProduct else { return }
        
        isPurchasing = true
        
        do {
            let success = try await subscriptionManager.purchase(product)
            
            if success {
                dismiss()
            }
        } catch {
            purchaseError = error.localizedDescription
            showError = true
        }
        
        isPurchasing = false
    }
    
    private func restore() async {
        isPurchasing = true
        
        do {
            try await subscriptionManager.restorePurchases()
            
            if subscriptionManager.isSubscribed {
                dismiss()
            }
        } catch {
            purchaseError = error.localizedDescription
            showError = true
        }
        
        isPurchasing = false
    }
    
    // MARK: - Helpers
    private func periodName(for product: Product) -> String {
        guard let subscription = product.subscription else { return "period" }
        
        switch subscription.subscriptionPeriod.unit {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "period"
        }
    }
}

// MARK: - Feature Row View
private struct FeatureRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Plan Card View
private struct PlanCardView: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                        
                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(periodLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
            .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }
    
    private var periodLabel: String {
        guard let subscription = product.subscription else { return "" }
        
        switch subscription.subscriptionPeriod.unit {
        case .day: return "per day"
        case .week: return "per week"
        case .month: return "per month"
        case .year: return "per year"
        @unknown default: return ""
        }
    }
}

#Preview {
    SubscriptionPaywallView()
}
