//
//  SubscriptionManager.swift
//  playground
//
//  Native StoreKit 2 subscription manager for handling in-app purchases
//

import Foundation
import StoreKit
import SwiftUI

/// Product IDs for the app's subscriptions
enum SubscriptionProductID: String, CaseIterable {
    case weeklyPremium = "calCalculator.weekly.premium"
    case monthlyPremium = "calCalculator.monthly.premium"
    case yearlyPremium = "calCalculator.yearly.premium"
    
    var displayName: String {
        switch self {
        case .weeklyPremium:
            return "Weekly"
        case .monthlyPremium:
            return "Monthly"
        case .yearlyPremium:
            return "Yearly"
        }
    }
    
    /// Sort order for display (yearly first as best value)
    var sortOrder: Int {
        switch self {
        case .yearlyPremium: return 0
        case .monthlyPremium: return 1
        case .weeklyPremium: return 2
        }
    }
}

/// Subscription Group ID
enum SubscriptionGroupID: String {
    case premium = "21871386"
}

/// Manages StoreKit 2 subscriptions
@MainActor
@Observable
final class SubscriptionManager {
    
    // MARK: - Singleton
    
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    
    /// Available products fetched from App Store
    var products: [Product] = []
    
    /// Currently active subscription
    var purchasedSubscription: Product?
    
    /// Whether the user has an active subscription
    var isSubscribed: Bool = false
    
    /// The current subscription status
    var subscriptionStatus: Product.SubscriptionInfo.Status?
    
    /// Loading state
    var isLoading: Bool = false
    
    /// Whether the initial subscription check has completed
    /// This is true only after the first updateSubscriptionStatus() call completes
    var hasCompletedInitialCheck: Bool = false
    
    /// Error message if any
    var errorMessage: String?
    
    /// Purchase in progress
    var isPurchasing: Bool = false
    
    /// Subscription renewal info
    var renewalInfo: Product.SubscriptionInfo.RenewalInfo?
    
    // MARK: - Private Properties
    
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Initialization
    
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products and check subscription status
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load available products from the App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIDs = SubscriptionProductID.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: productIDs)
            
            // Sort by best value (yearly first, then monthly, then weekly)
            products = storeProducts.sorted { first, second in
                let firstOrder = SubscriptionProductID(rawValue: first.id)?.sortOrder ?? 99
                let secondOrder = SubscriptionProductID(rawValue: second.id)?.sortOrder ?? 99
                return firstOrder < secondOrder
            }
            
            AppLogger.forClass("SubscriptionManager").success("Loaded \(products.count) products")
            for product in products {
                AppLogger.forClass("SubscriptionManager").info("Product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
            }
        } catch {
            AppLogger.forClass("SubscriptionManager").warning("Failed to load products", error: error)
            errorMessage = "Failed to load subscription options. Please try again."
        }
        
        isLoading = false
    }
    
    /// Purchase a product
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isPurchasing = true
        errorMessage = nil
        
        defer {
            isPurchasing = false
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Check if the transaction is verified
                let transaction = try checkVerified(verification)
                
                // Update subscription status
                await updateSubscriptionStatus()
                
                // Finish the transaction
                await transaction.finish()
                
                AppLogger.forClass("SubscriptionManager").success("Purchase successful for \(product.id)")
                
                Pixel.track("purchase_success", type: .transaction)
                
                // Notify the app about subscription status change
                NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
                
                return transaction
                
            case .userCancelled:
                AppLogger.forClass("SubscriptionManager").info("User cancelled purchase")
                Pixel.track("purchase_cancelled", type: .transaction)
                return nil
                
            case .pending:
                AppLogger.forClass("SubscriptionManager").info("Purchase pending - awaiting approval")
                errorMessage = "Purchase is pending approval."
                return nil
                
            @unknown default:
                AppLogger.forClass("SubscriptionManager").warning("Unknown purchase result")
                return nil
            }
        } catch {
            AppLogger.forClass("SubscriptionManager").warning("Purchase failed", error: error)
            Pixel.track("purchase_failed", type: .transaction)
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Restore purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            
            if isSubscribed {
                AppLogger.forClass("SubscriptionManager").success("Purchases restored successfully")
                Pixel.track("restore_success", type: .transaction)
                NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
            } else {
                AppLogger.forClass("SubscriptionManager").info("No active subscriptions found to restore")
                Pixel.track("restore_no_subscription", type: .transaction)
                errorMessage = "No active subscriptions found."
            }
        } catch {
            AppLogger.forClass("SubscriptionManager").warning("Failed to restore purchases", error: error)
            Pixel.track("restore_failed", type: .transaction)
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Update subscription status
    func updateSubscriptionStatus() async {
        var foundSubscription: Product?
        var hasActiveSubscription = false
        
        // Check for active subscriptions
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Check if this is a subscription transaction
                if transaction.productType == .autoRenewable {
                    // Find the matching product
                    if let product = products.first(where: { $0.id == transaction.productID }) {
                        foundSubscription = product
                        hasActiveSubscription = true
                        
                        // Get subscription status
                        if let subscription = product.subscription {
                            let statuses = try await subscription.status
                            if let status = statuses.first {
                                subscriptionStatus = status
                                
                                // Get renewal info
                                if case .verified(let renewal) = status.renewalInfo {
                                    renewalInfo = renewal
                                }
                            }
                        }
                    } else {
                        // Product not loaded yet, but we have a valid transaction
                        hasActiveSubscription = true
                    }
                }
            } catch {
                AppLogger.forClass("SubscriptionManager").warning("Failed to verify transaction", error: error)
            }
        }
        
        purchasedSubscription = foundSubscription
        isSubscribed = hasActiveSubscription
        
        // Mark that we've completed the initial check
        hasCompletedInitialCheck = true
        
        // Store in UserDefaults for persistence
        UserDefaults.standard.set(isSubscribed, forKey: "subscriptionStatus")
        
        // Sync to widgets
        syncSubscriptionStatusToWidget(isSubscribed)
        
        // Notify observers that subscription status has been determined
        NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
        
        AppLogger.forClass("SubscriptionManager").info("Subscription status updated: \(isSubscribed)")
    }
    
    /// Get the subscription expiration date
    var expirationDate: Date? {
        guard let status = subscriptionStatus,
              case .verified(let transaction) = status.transaction else {
            return nil
        }
        return transaction.expirationDate
    }
    
    /// Get whether the subscription will renew
    var willRenew: Bool {
        guard let info = renewalInfo else { return false }
        return info.willAutoRenew
    }
    
    /// Check if the user is eligible for an introductory offer
    func isEligibleForIntroOffer(for product: Product) async -> Bool {
        guard let subscription = product.subscription else { return false }
        return await subscription.isEligibleForIntroOffer
    }
    
    /// Get the introductory offer for a product
    func introductoryOffer(for product: Product) -> Product.SubscriptionOffer? {
        return product.subscription?.introductoryOffer
    }
    
    // MARK: - Private Methods
    
    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try await self?.checkVerified(result)
                    await self?.updateSubscriptionStatus()
                    await transaction?.finish()
                } catch {
                    await AppLogger.forClass("SubscriptionManager").warning("Transaction verification failed", error: error)
                }
            }
        }
    }
    
    /// Verify a transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    /// Sync subscription status to widget
    private func syncSubscriptionStatusToWidget(_ isSubscribed: Bool) {
        let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
        let isSubscribedKey = "widget.isSubscribed"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            AppLogger.forClass("SubscriptionManager").warning("Failed to access shared UserDefaults for widget subscription sync")
            return
        }
        
        sharedDefaults.set(isSubscribed, forKey: isSubscribedKey)
        AppLogger.forClass("SubscriptionManager").info("Widget subscription status synced: \(isSubscribed)")
    }
}

// MARK: - Product Extensions

extension Product {
    /// Formatted subscription period (e.g., "per week", "per month")
    var subscriptionPeriodText: String {
        guard let subscription = self.subscription else { return "" }
        let period = subscription.subscriptionPeriod
        
        switch period.unit {
        case .day:
            return period.value == 1 ? "per day" : "per \(period.value) days"
        case .week:
            return period.value == 1 ? "per week" : "per \(period.value) weeks"
        case .month:
            return period.value == 1 ? "per month" : "per \(period.value) months"
        case .year:
            return period.value == 1 ? "per year" : "per \(period.value) years"
        @unknown default:
            return ""
        }
    }
    
    /// Trial period text if available
    var trialPeriodText: String? {
        guard let intro = subscription?.introductoryOffer,
              intro.paymentMode == .freeTrial else {
            return nil
        }
        
        let period = intro.period
        switch period.unit {
        case .day:
            return period.value == 1 ? "1-day free trial" : "\(period.value)-day free trial"
        case .week:
            return period.value == 1 ? "1-week free trial" : "\(period.value)-week free trial"
        case .month:
            return period.value == 1 ? "1-month free trial" : "\(period.value)-month free trial"
        case .year:
            return period.value == 1 ? "1-year free trial" : "\(period.value)-year free trial"
        @unknown default:
            return nil
        }
    }
}
