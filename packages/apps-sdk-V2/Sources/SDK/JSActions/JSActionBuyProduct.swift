//
//  JSActionBuyProduct.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 15/07/2024.
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
struct JSActionBuyProduct: JSActionProtocol {
    weak var model: TheSDK?

    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        guard let productId = parameters["productId"] as? String else {
            throw SDKError.withReason("missing productId")
        }

        return try await performPurchase(productId: productId, retryAttempt: 0, maxRetries: 2, parameters: parameters)
    }

    private func performPurchase(productId: String, retryAttempt: Int, maxRetries: Int, parameters: [String: Any]) async throws -> [String: Any]? {
        guard let model else { return nil }
        
        // On first attempt, proactively clear ALL expired transactions BEFORE purchase
        if retryAttempt == 0 {
            Logger.log(level: .native, "🔄 Proactively syncing all transactions before purchase attempt")
            await API.IAP.syncTransactions()
            // Give Apple's servers a moment to sync
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }

        guard let product = try await API.IAP.fetchProducs(productIdList: [productId]).first else {
            throw SDKError.withReason("product \(productId) not found")
        }

        let result = try await API.IAP.purchase(product: product)

        switch result {
        case let .success(verificationResult):
            Logger.log(level: .native, "📊 DEBUG: sendPixelEvent - name: transaction, hasSignedVerification: true")
            model.sendPixelEvent(name: "transaction", payload: ["signedVerification": verificationResult.jwsRepresentation])

            if let json = try? JSONSerialization.jsonObject(with: verificationResult.payloadData, options: []) as? [String: Any],
               json["type"] as? String == "Auto-Renewable Subscription"
            {
                // Check if this is a restoration of an expired subscription
                if let purchaseDate = json["purchaseDate"] as? TimeInterval,
                   let originalPurchaseDate = json["originalPurchaseDate"] as? TimeInterval,
                   let expiresDate = json["expiresDate"] as? TimeInterval
                {
                    let currentTime = Date().timeIntervalSince1970
                    let isPurchaseDateOld = currentTime - (purchaseDate / 1000) > 60
                    let isRestoration = originalPurchaseDate < purchaseDate || isPurchaseDateOld
                    let isActive = currentTime < (expiresDate / 1000)

                    // CRITICAL: Check if Apple returned an old expired transaction
                    // This happens when user tries to resubscribe but StoreKit returns old transaction
                    if !isActive, isPurchaseDateOld {
                        let transactionId = json["transactionId"] as? String ?? ""
                        let expirationDateFormatted = Date(timeIntervalSince1970: expiresDate / 1000)

                        Logger.log(level: .native, "⚠️ EXPIRED TRANSACTION RETURNED: id=\(transactionId), expired=\(expirationDateFormatted)")

                        // Log this critical issue
                        Logger.log(level: .native, "📊 DEBUG: sendPixelEvent - name: expired_transaction_returned, productId: \(json["productId"] as? String ?? ""), transactionId: \(transactionId)")
                        model.sendPixelEvent(name: "expired_transaction_returned", payload: [
                            "productId": json["productId"] as? String ?? "",
                            "transactionId": transactionId,
                            "originalTransactionId": json["originalTransactionId"] as? String ?? "",
                            "expiresDate": expiresDate,
                            "purchaseDate": purchaseDate,
                            "currentTime": currentTime * 1000
                        ])

                        // Don't grant access for expired transactions
                        await MainActor.run {
                            model.isSubscribed = false
                        }

                        // Sync transactions to clear expired ones and allow new purchase
                        await API.IAP.syncTransactions()

                        // Check if we should retry
                        if retryAttempt < maxRetries {
                            Logger.log(level: .native, "🔄 Expired transaction detected, retrying purchase (attempt \(retryAttempt + 1)/\(maxRetries))")

                            // Wait a bit before retrying
                            try? await Task.sleep(nanoseconds: 1000000000) // 1 second

                            // Retry the purchase
                            return try await performPurchase(
                                productId: productId,
                                retryAttempt: retryAttempt + 1,
                                maxRetries: maxRetries,
                                parameters: parameters
                            )
                        }

                        // Max retries reached - throw error
                        Logger.log(level: .native, "❌ Max retries reached for expired transaction")
                        throw SDKError.withReason("Unable to complete purchase. Your previous subscription has expired. Please try again later.")
                    }

                    if isRestoration {
                        Logger.log(level: .native, "📊 DEBUG: sendPixelEvent - name: subscription_restored, productId: \(json["productId"] as? String ?? ""), isActive: \(isActive)")
                        model.sendPixelEvent(name: "subscription_restored", payload: [
                            "productId": json["productId"] as? String ?? "",
                            "originalTransactionId": json["originalTransactionId"] as? String ?? "",
                            "wasExpired": !isActive,
                            "isActive": isActive
                        ])

                        if isActive {
                            // Active restoration - grant access
                            await MainActor.run {
                                model.isSubscribed = true
                            }
                        } else {
                            // Expired restoration - don't grant access
                            await MainActor.run {
                                model.isSubscribed = false
                            }

                            // Check the actual subscription status - might be in grace period
                            let productId = json["productId"] as? String ?? ""
                            let subscriptionStatus = try? await API.IAP.checkSubscriptionStatus(forProductionId: productId)

                            if subscriptionStatus == "inGracePeriod" || subscriptionStatus == "inBillingRetryPeriod" {
                                throw SDKError.withReason("Your subscription payment is pending. Please update your payment method in App Store.")
                            } else {
                                throw SDKError.withReason("Your subscription has expired. Please purchase again to continue.")
                            }
                        }
                    } else {
                        // New purchase - grant access
                        await MainActor.run {
                            model.isSubscribed = true
                        }

                        // Track if this was a successful retry after expired transaction
                        if retryAttempt > 0 {
                            Logger.log(level: .native, "📊 DEBUG: sendPixelEvent - name: purchase_retry_success, productId: \(json["productId"] as? String ?? ""), retryAttempt: \(retryAttempt)")
                            model.sendPixelEvent(name: "purchase_retry_success", payload: [
                                "productId": json["productId"] as? String ?? "",
                                "retryAttempt": retryAttempt
                            ])
                            Logger.log(level: .native, "✅ Purchase successful after \(retryAttempt) retry attempt(s)")
                        }
                    }
                } else {
                    // New purchase without proper dates - grant access
                    await MainActor.run {
                        model.isSubscribed = true
                    }
                }
            }

            return ["state": "success", "signedVerification": verificationResult.jwsRepresentation]

        default:
            return ["state": String(describing: result)]
        }
    }
}

extension Product.PurchaseResult {
    var toString: String {
        switch self {
        case .pending:
            "pending"
        case .success:
            "success"
        case .userCancelled:
            "userCancelled"
        @unknown default:
            ""
        }
    }
}
