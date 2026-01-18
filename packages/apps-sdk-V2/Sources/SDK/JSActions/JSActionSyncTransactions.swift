//
//  JSActionSyncTransactions.swift
//  SDK
//
//  Created to help resolve issues with expired transactions blocking resubscription
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
struct JSActionSyncTransactions: JSActionProtocol {
    weak var model: TheSDK?

    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        Logger.log(level: .native, "🔄 Manual transaction sync requested")
        
        // Sync all transactions with Apple
        await API.IAP.syncTransactions()
        
        // Get current subscription status
        let isSubscribed = await API.IAP.updateSubscriptionState()
        
        // Update model
        if let model {
            await MainActor.run {
                model.isSubscribed = isSubscribed
            }
        }
        
        return [
            "success": true,
            "isSubscribed": isSubscribed,
            "message": "Transaction sync completed"
        ]
    }
}

