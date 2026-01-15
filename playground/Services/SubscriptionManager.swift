//
//  SubscriptionManager.swift
//  CalCalculator
//
//  Native StoreKit 2 subscription management
//

import Foundation
import StoreKit

/// Manages in-app subscriptions using StoreKit 2
@MainActor
final class SubscriptionManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .unknown
    
    // MARK: - Product IDs
    static let productIDs: Set<String> = [
        "calCalculator.weekly.premium",
        "calCalculator.monthly.premium",
        "calCalculator.yearly.premium"
    ]
    
    // MARK: - Subscription Status
    enum SubscriptionStatus: Equatable {
        case unknown
        case notSubscribed
        case subscribed(productID: String, expirationDate: Date?)
        
        var isSubscribed: Bool {
            if case .subscribed = self { return true }
            return false
        }
    }
    
    // MARK: - Private Properties
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Initialization
    private init() {
        // Start listening for transactions
        updateListenerTask = listenForTransactions()
        
        // Load products and check subscription status
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        loadError = nil
        
        do {
            print("📦 [SubscriptionManager] Loading products...")
            let storeProducts = try await Product.products(for: Self.productIDs)
            
            // Sort products by price (weekly < monthly < yearly)
            products = storeProducts.sorted { $0.price < $1.price }
            
            print("✅ [SubscriptionManager] Loaded \(products.count) products:")
            for product in products {
                print("   - \(product.id): \(product.displayPrice)")
            }
            
            isLoading = false
        } catch {
            print("❌ [SubscriptionManager] Failed to load products: \(error.localizedDescription)")
            loadError = "Unable to load subscription plans. Please check your internet connection."
            isLoading = false
        }
    }
    
    // MARK: - Purchase
    func purchase(_ product: Product) async throws -> Bool {
        print("🛒 [SubscriptionManager] Purchasing \(product.id)...")
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Update the subscription status
            await updateSubscriptionStatus()
            
            // Finish the transaction
            await transaction.finish()
            
            print("✅ [SubscriptionManager] Purchase successful: \(product.id)")
            
            // Post notification for other parts of the app
            NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
            
            return true
            
        case .userCancelled:
            print("⚠️ [SubscriptionManager] User cancelled purchase")
            return false
            
        case .pending:
            print("⏳ [SubscriptionManager] Purchase pending")
            return false
            
        @unknown default:
            print("❓ [SubscriptionManager] Unknown purchase result")
            return false
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async throws {
        print("🔄 [SubscriptionManager] Restoring purchases...")
        try await AppStore.sync()
        await updateSubscriptionStatus()
        NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
        print("✅ [SubscriptionManager] Restore completed")
    }
    
    // MARK: - Check Subscription Status
    func updateSubscriptionStatus() async {
        print("🔍 [SubscriptionManager] Checking subscription status...")
        
        var foundSubscription = false
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if Self.productIDs.contains(transaction.productID) {
                    purchasedProductIDs.insert(transaction.productID)
                    
                    // Get expiration date for subscription
                    let expirationDate = transaction.expirationDate
                    subscriptionStatus = .subscribed(productID: transaction.productID, expirationDate: expirationDate)
                    foundSubscription = true
                    
                    print("✅ [SubscriptionManager] Active subscription: \(transaction.productID)")
                    if let expDate = expirationDate {
                        print("   Expires: \(expDate)")
                    }
                }
            } catch {
                print("❌ [SubscriptionManager] Transaction verification failed: \(error)")
            }
        }
        
        if !foundSubscription {
            subscriptionStatus = .notSubscribed
            purchasedProductIDs.removeAll()
            print("ℹ️ [SubscriptionManager] No active subscription found")
        }
    }
    
    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                    
                    // Notify the app about the update
                    await MainActor.run {
                        NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
                    }
                } catch {
                    print("❌ [SubscriptionManager] Transaction update error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Helper Properties
    var isSubscribed: Bool {
        subscriptionStatus.isSubscribed
    }
    
    var weeklyProduct: Product? {
        products.first { $0.id == "calCalculator.weekly.premium" }
    }
    
    var monthlyProduct: Product? {
        products.first { $0.id == "calCalculator.monthly.premium" }
    }
    
    var yearlyProduct: Product? {
        products.first { $0.id == "calCalculator.yearly.premium" }
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let subscriptionStatusUpdated = Notification.Name("subscriptionStatusUpdated")
}
