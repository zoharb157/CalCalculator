//  Firebase init, created for Translate App
//
import AdSupport
import Firebase
import FirebaseAnalytics
import Foundation

class JSActionInitFirebase: NSObject, JSActionProtocol {
    let sdk: TheSDK

    init(sdk: TheSDK) {
        self.sdk = sdk
        super.init()
    }

    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        // Get ATT status from parameters
        let attStatusString = parameters["attStatus"] as? String ?? "unknown"

        // Get IDFA natively - only if authorized, otherwise use status string
        let idfa: String
        if attStatusString == "authorized" {
            idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        } else {
            idfa = attStatusString
        }

        // Configure Firebase (safe to call multiple times - Firebase handles this internally)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        FirebaseAnalytics.Analytics.setAnalyticsCollectionEnabled(true)
        FirebaseAnalytics.Analytics.setUserID(sdk.userId)

        let appInstanceId = FirebaseAnalytics.Analytics.appInstanceID() ?? "unknown"

        // Log initialization event
        Logger.log(level: .native, "📊 DEBUG: Firebase SDK initialized - appInstanceId: \(appInstanceId)")

        // Send pixel event with IDFA to backend
        Logger.log(level: .native, "📊 DEBUG: sendPixelEvent - name: firebase_init, user_id: \(sdk.userId ?? "unknown"), idfa: \(idfa), app_instance_id: \(appInstanceId)")
        sdk.sendPixelEvent(name: "firebase_init",
            payload: [
                "user_id": sdk.userId ?? "unknown",
                "idfa": idfa,
                "app_instance_id": appInstanceId,
                "state": "configured"
            ])

        return [
            "success": true,
            "appInstanceId": appInstanceId,
            "userId": sdk.userId ?? "unknown",
            "idfa": idfa
        ]
    }
}
