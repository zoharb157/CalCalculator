//
//  API+IAP.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 06/07/2024.
//

import Combine
import Foundation
import StoreKit
import SwiftUI

public extension API {
    enum IAP {
        // Struct to hold subscription update information
        public struct SubscriptionUpdate {
            let transactionId: UInt64
            let productId: String
            let isRenewal: Bool
            let isRestoration: Bool
        }

        private static var observerTask: Task<Void, Never>?

        static let isSibscribed: CurrentValueSubject<Bool, Never> = .init(false)
        public static let subscriptionUpdates = PassthroughSubject<SubscriptionUpdate, Never>()

        public static func fetchProducs(productIdList: [String]) async throws -> [Product] {
            return try await Product.products(for: Set(productIdList))
        }

        /// Syncs with Apple's servers to ensure all transactions are up to date
        /// Simplified version that just checks current entitlements
        public static func syncTransactions() async {
            Logger.log(level: .native, "🔄 Syncing transactions with Apple...")
            _ = await fetchPurchasedProducts()
            Logger.log(level: .native, "✅ Transaction sync complete")
        }

        static func observeTransactions() {
            guard observerTask == nil else { return } // Prevent multiple observers

            observerTask = Task(priority: .background) {
                for await verificationResult in Transaction.updates {
                    switch verificationResult {
                    case .verified(let transaction):
                        let isExpired = Date.now.timeIntervalSince(transaction.expirationDate ?? .now) > 0
                        let isRevoked = transaction.revocationDate != nil
                        let isActive = !isExpired && !isRevoked

                        Logger.log(level: .native, "📱 Transaction Update: id=\(transaction.id), productId=\(transaction.productID), expired=\(isExpired), revoked=\(isRevoked)")

                        if isActive {
                            // Update purchased products
                            _ = await self.fetchPurchasedProducts()

                            // Check if this is a renewal or restoration
                            if transaction.productType == .autoRenewable {
                                let isRenewal = transaction.reason == .renewal
                                let isRestoration = transaction.reason == .purchase &&
                                    transaction.originalPurchaseDate != transaction.purchaseDate

                                if isRenewal || isRestoration {
                                    let update = SubscriptionUpdate(
                                        transactionId: transaction.id,
                                        productId: transaction.productID,
                                        isRenewal: isRenewal,
                                        isRestoration: isRestoration
                                    )

                                    await MainActor.run {
                                        subscriptionUpdates.send(update)
                                    }
                                }
                            }

                            await transaction.finish()
                        } else {
                            Logger.log(level: .native, "⚠️ Finishing expired/revoked transaction: id=\(transaction.id)")
                            await transaction.finish()
                            _ = await self.fetchPurchasedProducts()
                        }

                    case .unverified:
                        Logger.log(level: .native, "⚠️ Unverified transaction")
                        break
                    }
                }
            }
        }

        public static func updateSubscriptionState() async -> Bool {
            let products = await fetchPurchasedProducts()

            let isSubscribed = products.count > 0
            IAP.isSibscribed.value = isSubscribed
            return isSubscribed
        }

        static func checkSubscriptionStatus(forProductionId id: String) async throws -> String? {
            let dict: [Product.SubscriptionInfo.RenewalState: String] = [.subscribed: "subscribed",
                                                                         .expired: "expired",
                                                                         .inBillingRetryPeriod: "inBillingRetryPeriod",
                                                                         .inGracePeriod: "inGracePeriod",
                                                                         .revoked: "revoked"]

            // Get all subscription products from the App Store
            guard let product = try await Product.products(for: [id]).first else {
                return nil
            }

            guard let subscription = product.subscription else {
                return nil
            }

            let statuses = try await subscription.status

            let status = statuses
                .sorted(by: { $0.renewalInfo.signedDate > $1.renewalInfo.signedDate })
                .compactMap { $0.state }
                .first

            if let status {
                return dict[status]
            } else {
                return "notSubscribed"
            }
        }

        static func fetchPurchasedProducts() async -> Set<String> {
            var purchasedProducts: Set<String> = .init()
            for await result in Transaction.currentEntitlements {
                switch result {
                case .unverified:
                    break

                case let .verified(transaction):
                    let isExpired = Date.now.timeIntervalSince(transaction.expirationDate ?? .now) > 0
                    let isRevoked = transaction.revocationDate != nil
                    let isActive = !isExpired && !isRevoked

                    if isActive {
                        purchasedProducts.insert(transaction.productID)
                        // CRITICAL FIX: Always finish active transactions
                        await transaction.finish()
                    }
                }
            }

            isSibscribed.send(purchasedProducts.count > 0)

            return purchasedProducts
        }
        
        /// Fetches the original transaction ID for the active subscription
        static func fetchOriginalTransactionId() async -> String? {
            for await result in Transaction.currentEntitlements {
                switch result {
                case .unverified:
                    break

                case let .verified(transaction):
                    let isExpired = Date.now.timeIntervalSince(transaction.expirationDate ?? .now) > 0
                    let isRevoked = transaction.revocationDate != nil
                    let isActive = !isExpired && !isRevoked

                    if isActive {
                        return String(transaction.originalID)
                    }
                }
            }
            return nil
        }

        public static func purchase(product: Product) async throws -> Product.PurchaseResult {
            do {
                let result = try await product.purchase()

                switch result {
                case let .success(.verified(transaction)):
                    let isExpired = Date.now.timeIntervalSince(transaction.expirationDate ?? .now) > 0
                    let isRevoked = transaction.revocationDate != nil
                    let isActive = !isExpired && !isRevoked

                    if isActive {
                        isSibscribed.send(true)
                        // CRITICAL FIX: Always finish transactions immediately
                        await transaction.finish()
                    }

                    _ = await fetchPurchasedProducts()

                case .success(.unverified(_, _)):
                    // Successful purchase but transaction/receipt can't be verified
                    // Could be a jailbroken phone
                    break
                case .pending:
                    // Transaction waiting on SCA (Strong Customer Authentication) or
                    // approval from Ask to Buy
                    break
                case .userCancelled:
                    break
                @unknown default:
                    break
                }

                return result
            } catch let error as DecodingError {
                throw SDKError.withReason(error.localizedDescription)
            } catch let error as Product.PurchaseError {
                throw SDKError.withReason(error.localizedDescription)
            } catch {
                throw SDKError.withReason(error.localizedDescription)
            }
        }
    }
}
