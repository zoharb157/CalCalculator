//
//  JSActionFirebaseEvent.swift
//  SDK
//
//  Created for Firebase Analytics integration
//

import AdSupport
import AppTrackingTransparency
import FirebaseAnalytics
import Foundation

struct JSActionFirebaseEvent: JSActionProtocol {
    weak var model: TheSDK?
    
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        print("🟠 [FIREBASE-EVENT] JSActionFirebaseEvent.perform() CALLED")
        print("🟠 [FIREBASE-EVENT] Parameters received: \(parameters)")
        
        guard let eventName = parameters["name"] as? String else {
            print("🔴 [FIREBASE-EVENT] ERROR: Missing event name!")
            throw SDKError.withReason("missing parameter name of type string")
        }
        
        print("🟠 [FIREBASE-EVENT] Event Name: \(eventName)")

        guard let model else {
            print("🔴 [FIREBASE-EVENT] ERROR: Model is nil")
            return nil
        }

        // Get event values/parameters from JavaScript
        var values = parameters["values"] as? [String: Any] ?? [:]
        print("🟠 [FIREBASE-EVENT] Original values: \(values)")
        
        // Add standard tracking parameters
        values["installTime"] = SDKStore.lastInstallTime
        values["sessionId"] = SDKStore.sessionId
        
        if let userId = model.userId {
            values["userId"] = userId
        }
        
        // Get IDFA if authorized
        let attStatus = ATTrackingManager.trackingAuthorizationStatus
        print("🟠 [FIREBASE-EVENT] ATT Status: \(attStatus.rawValue)")
        
        if attStatus == .authorized {
            let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
            values["idfa"] = idfa
            values["att_status"] = "authorized"
            print("🟠 [FIREBASE-EVENT] IDFA included: \(idfa)")
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
            print("🟠 [FIREBASE-EVENT] ATT not authorized: \(statusString)")
        }
        
        // Add IDFV (always available, doesn't require ATT)
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            values["idfv"] = idfv
            print("🟠 [FIREBASE-EVENT] IDFV included: \(idfv)")
        }
        
        // Add app version
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            values["app_version"] = appVersion
        }
        
        // Add device info
        values["device_model"] = UIDevice.current.model
        values["os_version"] = UIDevice.current.systemVersion
        
        print("🟠 [FIREBASE-EVENT] Enhanced values (with tracking data): \(values)")

        // Convert to Firebase Analytics parameters
        var firebaseParameters: [String: Any] = [:]
        
        print("🟠 [FIREBASE-EVENT] Converting parameters for Firebase Analytics...")
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
        print("🟠 [FIREBASE-EVENT] Firebase parameters ready: \(firebaseParameters.count) params")

        print("🟠 [FIREBASE-EVENT] Final event to log: \(eventName)")
        print("🟠 [FIREBASE-EVENT] Parameters count: \(firebaseParameters.count)")
        
        // Log event to Firebase
        print("🟠 [FIREBASE-EVENT] Logging to Firebase Analytics...")
        Logger.log(level: .native, "📊 Firebase Event: \(eventName) with params: \(firebaseParameters)")
        FirebaseAnalytics.Analytics.logEvent(eventName, parameters: firebaseParameters)
        
        print("🟢 [FIREBASE-EVENT] ========================================")
        print("🟢 [FIREBASE-EVENT] ✅✅✅ EVENT LOGGED TO FIREBASE!")
        print("🟢 [FIREBASE-EVENT] Event: \(eventName)")
        print("🟢 [FIREBASE-EVENT] Parameters: \(firebaseParameters)")
        print("🟢 [FIREBASE-EVENT] ========================================")

        return ["success": true]
    }
}

