//
//  JSActionFacebookEvent.swift
//  SDK
//
//  Created for Facebook SDK integration
//

import FacebookCore
import Foundation

struct JSActionFacebookEvent: JSActionProtocol {
    weak var model: TheSDK?
    
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        print("🟠 [FB-EVENT] JSActionFacebookEvent.perform() CALLED")
        print("🟠 [FB-EVENT] Parameters received: \(parameters)")
        
        guard let eventName = parameters["name"] as? String else {
            print("🔴 [FB-EVENT] ERROR: Missing event name!")
            throw SDKError.withReason("missing parameter name of type string")
        }
        
        print("🟠 [FB-EVENT] Event Name: \(eventName)")

        guard let model else {
            print("🔴 [FB-EVENT] ERROR: Model is nil")
            return nil
        }

        // Get event values/parameters
        var values = parameters["values"] as? [String: Any] ?? [:]
        print("🟠 [FB-EVENT] Original values: \(values)")
        
        // Add standard tracking parameters
        values["installTime"] = SDKStore.lastInstallTime
        values["sessionId"] = SDKStore.sessionId
        
        if let userId = model.userId {
            values["userId"] = userId
        }
        
        print("🟠 [FB-EVENT] Enhanced values (with tracking data): \(values)")

        // Convert to AppEvent.ParameterName dictionary for Facebook
        var fbParameters: [AppEvents.ParameterName: Any] = [:]
        
        print("🟠 [FB-EVENT] Converting parameters for Facebook SDK...")
        // Map standard Facebook parameter names
        for (key, value) in values {
            // Facebook expects specific parameter names with fb_ prefix for standard params
            let paramName = AppEvents.ParameterName(rawValue: key)
            fbParameters[paramName] = value
        }
        print("🟠 [FB-EVENT] Facebook parameters ready: \(fbParameters.count) params")

        // Check if this is a standard Facebook event
        let eventToLog: AppEvents.Name
        
        print("🟠 [FB-EVENT] Mapping event name: \(eventName)")
        // Map standard event names
        switch eventName {
        case "Purchase", "fb_mobile_purchase":
            eventToLog = .purchased
        case "ViewContent", "fb_mobile_content_view":
            eventToLog = .viewedContent
        case "AddToCart", "fb_mobile_add_to_cart":
            eventToLog = .addedToCart
        case "InitiateCheckout", "fb_mobile_initiated_checkout":
            eventToLog = .initiatedCheckout
        case "CompleteRegistration", "fb_mobile_complete_registration":
            eventToLog = .completedRegistration
        case "Subscribe", "fb_mobile_subscribe":
            eventToLog = .subscribe
        case "StartTrial", "fb_mobile_start_trial":
            eventToLog = .startTrial
        case "AddPaymentInfo", "fb_mobile_add_payment_info":
            eventToLog = .addedPaymentInfo
        case "AddToWishlist", "fb_mobile_add_to_wishlist":
            eventToLog = .addedToWishlist
        case "Search", "fb_mobile_search":
            eventToLog = .searched
        case "Rate", "fb_mobile_rate":
            eventToLog = .rated
        case "SpentCredits", "fb_mobile_spent_credits":
            eventToLog = .spentCredits
        case "AchievedLevel", "fb_mobile_level_achieved":
            eventToLog = .achievedLevel
        case "UnlockedAchievement", "fb_mobile_achievement_unlocked":
            eventToLog = .unlockedAchievement
        case "CompleteTutorial", "fb_mobile_tutorial_completion":
            eventToLog = .completedTutorial
        default:
            // Custom event name
            print("🟠 [FB-EVENT] Using custom event name: \(eventName)")
            eventToLog = AppEvents.Name(rawValue: eventName)
        }

        print("🟠 [FB-EVENT] Final event to log: \(eventToLog.rawValue)")
        print("🟠 [FB-EVENT] Parameters count: \(fbParameters.count)")
        
        // Log event to Facebook
        print("🟠 [FB-EVENT] Logging to Facebook SDK...")
        Logger.log(level: .native, "📊 Facebook Event: \(eventToLog.rawValue) with params: \(fbParameters)")
        AppEvents.shared.logEvent(eventToLog, parameters: fbParameters)
        
        print("🟢 [FB-EVENT] ========================================")
        print("🟢 [FB-EVENT] ✅✅✅ EVENT LOGGED TO FACEBOOK!")
        print("🟢 [FB-EVENT] Event: \(eventToLog.rawValue)")
        print("🟢 [FB-EVENT] Parameters: \(fbParameters)")
        print("🟢 [FB-EVENT] ========================================")

        return ["success": true]
    }
}

