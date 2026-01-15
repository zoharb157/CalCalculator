//
//  SubscriptionManager.swift
//  playground
//
//  Native StoreKit subscription manager to replace SDK webview
//

import Foundation
import StoreKit
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var subscriptionStatus: Bool = false
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var loadError: String? = nil
    
    // Product IDs from StoreKitConfig.storekit
    private let productIDs = [
        "calCalculator.weekly.premium",
        "calCalculator.monthly.premium",
        "calCalculator.yearly.premium"
    ]
    
    private var updateListenerTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products and check subscription status
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        loadError = nil
        
        do {
            print("📦 [SubscriptionManager] Loading products for IDs: \(productIDs)")
            let storeProducts = try await Product.products(for: productIDs)
            
            await MainActor.run {
                self.products = storeProducts.sorted { product1, product2 in
                    // Sort by price: weekly, monthly, yearly
                    let order1 = productIDs.firstIndex(of: product1.id) ?? Int.max
                    let order2 = productIDs.firstIndex(of: product2.id) ?? Int.max
                    return order1 < order2
                }
                self.loadError = nil
                self.isLoading = false
            }
            print("✅ [SubscriptionManager] Loaded \(storeProducts.count) products")
            
            // Log each product for debugging
            for product in storeProducts {
                print("   📱 Product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
            }
        } catch {
            print("❌ [SubscriptionManager] Failed to load products: \(error.localizedDescription)")
            await MainActor.run {
                self.loadError = "Unable to load subscription plans. Please check your internet connection and try again."
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Subscription Status
    
    func checkSubscriptionStatus() async {
        var isSubscribed = false
        
        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if productIDs.contains(transaction.productID) {
                    isSubscribed = true
                    break
                }
            } catch {
                print("⚠️ [SubscriptionManager] Failed to verify transaction: \(error)")
            }
        }
        
        await MainActor.run {
            self.subscriptionStatus = isSubscribed
            // Update UserDefaults for persistence
            UserDefaults.standard.set(isSubscribed, forKey: "subscriptionStatus")
            // Sync to widget
            syncSubscriptionStatusToWidget(isSubscribed)
            // Post notification for app updates
            NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
        }
        
        print("📱 [SubscriptionManager] Subscription status: \(isSubscribed ? "Subscribed" : "Not Subscribed")")
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            // Transaction is verified, update subscription status
            await checkSubscriptionStatus()
            // Finish the transaction
            await transaction.finish()
            return transaction
        case .userCancelled:
            print("⚠️ [SubscriptionManager] User cancelled purchase")
            return nil
        case .pending:
            print("⚠️ [SubscriptionManager] Purchase is pending")
            return nil
        @unknown default:
            print("⚠️ [SubscriptionManager] Unknown purchase result")
            return nil
        }
    }
    
    // MARK: - Transaction Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.checkSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("⚠️ [SubscriptionManager] Failed to process transaction update: \(error)")
                }
            }
        }
    }
    
    // MARK: - Widget Sync
    
    private func syncSubscriptionStatusToWidget(_ isSubscribed: Bool) {
        let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
        let isSubscribedKey = "widget.isSubscribed"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ Failed to access shared UserDefaults for widget subscription sync")
            return
        }
        
        sharedDefaults.set(isSubscribed, forKey: isSubscribedKey)
        print("📱 Widget subscription status synced: \(isSubscribed)")
        
        // Reload widget timelines
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        try? await AppStore.sync()
        await checkSubscriptionStatus()
    }
}
