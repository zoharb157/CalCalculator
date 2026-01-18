//
//  JSActionSendPixelEvent.swift
//  SDK
//
//  Created for unified Firebase and Facebook event tracking
//

import AdSupport
import AppTrackingTransparency
import FacebookCore
import FirebaseAnalytics
import Foundation

struct JSActionSendPixelEvent: JSActionProtocol {
    weak var model: TheSDK?
    
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        print("🟣 [PIXEL-EVENT] JSActionSendPixelEvent.perform() CALLED")
        print("🟣 [PIXEL-EVENT] Parameters received: \(parameters)")
        
        guard let eventName = parameters["name"] as? String else {
            print("🔴 [PIXEL-EVENT] ERROR: Missing event name!")
            throw SDKError.withReason("missing parameter name of type string")
        }
        
        print("🟣 [PIXEL-EVENT] Event Name: \(eventName)")

        guard let model else {
            print("🔴 [PIXEL-EVENT] ERROR: Model is nil")
            return nil
        }

        // Get event values/parameters from JavaScript
        var values = parameters["values"] as? [String: Any] ?? [:]
        print("🟣 [PIXEL-EVENT] Original values: \(values)")
        
        // Add standard tracking parameters
        values["installTime"] = SDKStore.lastInstallTime
        values["sessionId"] = SDKStore.sessionId
        
        if let userId = model.userId {
            values["userId"] = userId
        }
        
        // Get IDFA if authorized
        let attStatus = ATTrackingManager.trackingAuthorizationStatus
        print("🟣 [PIXEL-EVENT] ATT Status: \(attStatus.rawValue)")
        
        if attStatus == .authorized {
            let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
            values["idfa"] = idfa
            values["att_status"] = "authorized"
            print("🟣 [PIXEL-EVENT] IDFA included: \(idfa)")
        } else {
            // Include ATT status even if not authorized
            let statusString: String
            switch attStatus {
            case .notDetermined:
                statusString = "notDetermined"
            case .restricted:
                statusString = "restricted"
            case .denied:
                statusString = "denied"
            case .authorized:
                statusString = "authorized"
            @unknown default:
                statusString = "unknown"
            }
            values["att_status"] = statusString
            print("🟣 [PIXEL-EVENT] ATT not authorized: \(statusString)")
        }
        
        // Add IDFV (always available, doesn't require ATT)
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            values["idfv"] = idfv
            print("🟣 [PIXEL-EVENT] IDFV included: \(idfv)")
        }
        
        // Add app version
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            values["app_version"] = appVersion
        }
        
        // Add device info
        values["device_model"] = UIDevice.current.model
        values["os_version"] = UIDevice.current.systemVersion
        
        print("🟣 [PIXEL-EVENT] Enhanced values (with tracking data): \(values)")

        // Track success for both platforms
        var firebaseSuccess = false
        var facebookSuccess = false
        
        // FIREBASE ANALYTICS
        print("🟣 [PIXEL-EVENT] ==================== FIREBASE ====================")
        do {
            var firebaseParameters: [String: Any] = [:]
            
            print("🟣 [PIXEL-EVENT] Converting parameters for Firebase Analytics...")
            for (key, value) in values {
                // Firebase accepts String or NSNumber values
                if let stringValue = value as? String {
                    firebaseParameters[key] = stringValue
                } else if let numberValue = value as? NSNumber {
                    firebaseParameters[key] = numberValue
                } else if let intValue = value as? Int {
                    firebaseParameters[key] = intValue
                } else if let doubleValue = value as? Double {
                    firebaseParameters[key] = doubleValue
                } else if let boolValue = value as? Bool {
                    firebaseParameters[key] = boolValue
                } else {
                    // Convert other types to string
                    firebaseParameters[key] = "\(value)"
                }
            }
            print("🟣 [PIXEL-EVENT] Firebase parameters ready: \(firebaseParameters.count) params")

            // Log event to Firebase
            print("🟣 [PIXEL-EVENT] Logging to Firebase Analytics...")
            Logger.log(level: .native, "📊 Firebase Event: \(eventName) with params: \(firebaseParameters)")
            FirebaseAnalytics.Analytics.logEvent(eventName, parameters: firebaseParameters)
            
            print("🟢 [PIXEL-EVENT] ✅ Firebase event logged successfully!")
            firebaseSuccess = true
        } catch {
            print("🔴 [PIXEL-EVENT] ❌ Firebase logging failed: \(error)")
        }
        
        // FACEBOOK SDK
        print("🟣 [PIXEL-EVENT] ==================== FACEBOOK ====================")
        do {
            var fbParameters: [AppEvents.ParameterName: Any] = [:]
            
            print("🟣 [PIXEL-EVENT] Converting parameters for Facebook SDK...")
            for (key, value) in values {
                let paramName = AppEvents.ParameterName(rawValue: key)
                fbParameters[paramName] = value
            }
            print("🟣 [PIXEL-EVENT] Facebook parameters ready: \(fbParameters.count) params")

            // Map event name to Facebook standard events
            let eventToLog: AppEvents.Name
            
            print("🟣 [PIXEL-EVENT] Mapping event name: \(eventName)")
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
                print("🟣 [PIXEL-EVENT] Using custom event name: \(eventName)")
                eventToLog = AppEvents.Name(rawValue: eventName)
            }

            // Log event to Facebook
            print("🟣 [PIXEL-EVENT] Logging to Facebook SDK...")
            Logger.log(level: .native, "📊 Facebook Event: \(eventToLog.rawValue) with params: \(fbParameters)")
            AppEvents.shared.logEvent(eventToLog, parameters: fbParameters)
            
            print("🟢 [PIXEL-EVENT] ✅ Facebook event logged successfully!")
            facebookSuccess = true
        } catch {
            print("🔴 [PIXEL-EVENT] ❌ Facebook logging failed: \(error)")
        }

        // Final summary
        print("🟣 [PIXEL-EVENT] ========================================")
        print("🟣 [PIXEL-EVENT] PIXEL EVENT SUMMARY")
        print("🟣 [PIXEL-EVENT] Event: \(eventName)")
        print("🟣 [PIXEL-EVENT] Firebase: \(firebaseSuccess ? "✅ Success" : "❌ Failed")")
        print("🟣 [PIXEL-EVENT] Facebook: \(facebookSuccess ? "✅ Success" : "❌ Failed")")
        print("🟣 [PIXEL-EVENT] ========================================")

        return [
            "success": firebaseSuccess || facebookSuccess,
            "firebase": firebaseSuccess,
            "facebook": facebookSuccess
        ]
    }
}

