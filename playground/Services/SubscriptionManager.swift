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
    @Published var hasAttemptedLoad: Bool = false
    
    // Product IDs - must match App Store Connect exactly
    private let productIDs: Set<String> = [
        "calCalculator.weekly.premium",
        "calCalculator.monthly.premium",
        "calCalculator.yearly.premium"
    ]
    
    // Retry configuration
    private let maxRetries = 3
    private var currentRetryCount = 0
    
    private var updateListenerTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        print("🚀 [SubscriptionManager] Initializing...")
        
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products and check subscription status
        Task {
            await loadProductsWithRetry()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading with Retry
    
    func loadProductsWithRetry() async {
        currentRetryCount = 0
        await loadProducts()
        
        // Retry if failed and haven't exceeded max retries
        while products.isEmpty && currentRetryCount < maxRetries {
            currentRetryCount += 1
            print("🔄 [SubscriptionManager] Retry attempt \(currentRetryCount)/\(maxRetries)...")
            
            // Wait before retrying (exponential backoff)
            let delay = UInt64(pow(2.0, Double(currentRetryCount))) * 1_000_000_000 // 2, 4, 8 seconds
            try? await Task.sleep(nanoseconds: delay)
            
            await loadProducts()
        }
        
        hasAttemptedLoad = true
    }
    
    func loadProducts() async {
        isLoading = true
        loadError = nil
        
        do {
            print("📦 [SubscriptionManager] Loading products for IDs: \(productIDs)")
            print("📦 [SubscriptionManager] Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
            
            // Sync with App Store first (important for TestFlight/Production)
            print("📦 [SubscriptionManager] Syncing with App Store...")
            do {
                try await AppStore.sync()
                print("📦 [SubscriptionManager] App Store sync completed")
            } catch {
                print("⚠️ [SubscriptionManager] App Store sync failed (continuing anyway): \(error)")
            }
            
            print("📦 [SubscriptionManager] Requesting products from StoreKit...")
            
            // Try loading all products at once
            var storeProducts = try await Product.products(for: productIDs)
            
            // If no products, try loading each individually to debug
            if storeProducts.isEmpty {
                print("⚠️ [SubscriptionManager] Batch request returned 0 products, trying individually...")
                var individualProducts: [Product] = []
                for productID in productIDs {
                    do {
                        let products = try await Product.products(for: [productID])
                        print("   📦 Product '\(productID)': \(products.count > 0 ? "FOUND" : "NOT FOUND")")
                        individualProducts.append(contentsOf: products)
                    } catch {
                        print("   ❌ Product '\(productID)': ERROR - \(error.localizedDescription)")
                    }
                }
                storeProducts = individualProducts
            }
            
            print("📦 [SubscriptionManager] StoreKit returned \(storeProducts.count) products")
            
            // Check if no products returned (configuration issue)
            if storeProducts.isEmpty {
                print("⚠️ [SubscriptionManager] No products returned!")
                print("   ℹ️ This usually means:")
                print("   - Product IDs don't match App Store Connect")
                print("   - Products not in 'Ready to Submit' status")
                print("   - Paid Apps Agreement not signed")
                print("   - App not properly signed with App Store certificate")
                print("   - Running in simulator without StoreKit config")
                
                loadError = "Subscription plans are currently unavailable. Please try again later."
                isLoading = false
                return
            }
            
            // Sort products by duration (weekly, monthly, yearly)
            let sortOrder = ["weekly": 0, "monthly": 1, "yearly": 2]
            products = storeProducts.sorted { p1, p2 in
                let order1 = sortOrder.first { p1.id.contains($0.key) }?.value ?? 99
                let order2 = sortOrder.first { p2.id.contains($0.key) }?.value ?? 99
                return order1 < order2
            }
            
            loadError = nil
            isLoading = false
            
            print("✅ [SubscriptionManager] Loaded \(storeProducts.count) products successfully")
            
            // Log each product for debugging
            for product in products {
                print("   📱 Product: \(product.id)")
                print("      - Name: \(product.displayName)")
                print("      - Price: \(product.displayPrice)")
                if let subscription = product.subscription {
                    print("      - Period: \(subscription.subscriptionPeriod.unit) x \(subscription.subscriptionPeriod.value)")
                }
            }
        } catch {
            print("❌ [SubscriptionManager] Failed to load products!")
            print("   Error type: \(type(of: error))")
            print("   Error: \(error)")
            print("   Localized: \(error.localizedDescription)")
            
            // Provide more specific error message
            let errorMessage: String
            if let storeKitError = error as? StoreKitError {
                print("   StoreKit Error: \(storeKitError)")
                switch storeKitError {
                case .networkError(let underlyingError):
                    print("   Network underlying error: \(underlyingError)")
                    errorMessage = "Network error. Please check your internet connection."
                case .systemError(let underlyingError):
                    print("   System underlying error: \(underlyingError)")
                    errorMessage = "System error. Please restart the app."
                case .userCancelled:
                    errorMessage = "Request cancelled."
                case .notAvailableInStorefront:
                    errorMessage = "Subscriptions not available in your region."
                @unknown default:
                    errorMessage = "Unable to load subscription plans. Please try again."
                }
            } else {
                errorMessage = "Unable to load subscription plans. Please check your internet connection."
            }
            
            loadError = errorMessage
            isLoading = false
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
