//
//  JSActionInitFacebook.swift
//  SDK
//
//  Created for Facebook SDK integration
//

import AdSupport
import FacebookCore
import Foundation

class JSActionInitFacebook: NSObject, JSActionProtocol {
    let sdk: TheSDK

    init(sdk: TheSDK) {
        self.sdk = sdk
        super.init()
    }

    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        // Check if Facebook is configured in SDK
        guard let facebookAppId = sdk.config.facebook else {
            throw SDKError.withReason("Facebook not configured in SDK config")
        }

        // Get ATT status from parameters
        let attStatusString = parameters["attStatus"] as? String ?? "unknown"

        // Get IDFA natively - only if authorized, otherwise use status string
        let idfa: String
        if attStatusString == "authorized" {
            idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        } else {
            idfa = attStatusString
        }

        // Initialize Facebook SDK (always - safe to call multiple times)
        Settings.shared.appID = facebookAppId
        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isAdvertiserIDCollectionEnabled = true
        
        // Set advertiser tracking based on ATT status
        let isAuthorized = attStatusString == "authorized"
        Settings.shared.isAdvertiserTrackingEnabled = isAuthorized
        
        // Initialize AppEvents
        AppEvents.shared.activateApp()
        
        // Set user ID (like Firebase's setUserID)
        if let userId = sdk.userId {
            AppEvents.shared.userID = userId
            Logger.log(level: .native, "📊 DEBUG: Facebook userID set to: \(userId)")
        }

        let anonymousID = AppEvents.shared.anonymousID

        // Log initialization event
        Logger.log(level: .native, "📊 DEBUG: Facebook SDK initialized - anonymousID: \(anonymousID)")

        // Send pixel event with IDFA and anonymousID
        Logger.log(level: .native, "📊 DEBUG: sendPixelEvent - name: facebook_init, user_id: \(sdk.userId ?? "unknown"), idfa: \(idfa), anonymous_id: \(anonymousID)")
        sdk.sendPixelEvent(name: "facebook_init",
            payload: [
                "user_id": sdk.userId ?? "unknown",
                "idfa": idfa,
                "anonymous_id": anonymousID,
                "state": "configured"
            ])

        return [
            "success": true,
            "anonymousID": anonymousID,
            "userId": sdk.userId ?? "unknown",
            "idfa": idfa
        ]
    }
}
