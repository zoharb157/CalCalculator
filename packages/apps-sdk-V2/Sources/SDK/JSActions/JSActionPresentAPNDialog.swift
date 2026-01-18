
//
//  File.swift
//
//
//  Created by Dubon Ya'ar on 01/11/2024.
//

import Combine
import Foundation
import UIKit
import UserNotifications

class JSActionPresentAPNDialog: NSObject, JSActionProtocol {
    weak var model: TheSDK?

    private var anyCancellable: AnyCancellable?
    init(model: TheSDK) {
        self.model = model
    }

    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        let delay = parameters["delay"] as? TimeInterval ?? 0.1

        try await Task.sleep(nanoseconds: UInt64(TimeInterval(1000000000) * delay))

        let result = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        if result {
            // FIX: Set up sink BEFORE calling registerForRemoteNotifications
            // This prevents the race condition where iOS responds before we're listening
            return try await withCheckedThrowingContinuation { cont in
                anyCancellable = APNSManager.shared.apnsAction
                .sink { action in
                    switch action {
                    case let .didRegisterForNotifications(token):
                        cont.resume(returning: ["token": token])
                        Logger.log(level: .native, "📊 DEBUG: sendPixelEvent - name: apn, env: \(self.env), token: \(token), state: accepted")
                        self.model?.sendPixelEvent(name: "apn", payload: ["env": self.env, "token": token, "state": "accepted"])

                    case let .didFailToRegisterForNotifications(error):
                        cont.resume(throwing: error)
                        Logger.log(level: .native, "📊 DEBUG: sendPixelEvent - name: apn, env: \(self.env), state: error, error: \(error.localizedDescription)")
                        self.model?.sendPixelEvent(name: "apn", payload: ["env": self.env, "state": "error", "error": error.localizedDescription])

                    case .didReceive:
                        break
                    }

                    self.anyCancellable?.cancel()
                }

                // NOW register - sink is ready to receive the callback
                DispatchQueue.main.async {
                    APNSManager.shared.forceInjsectMethods()
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } else {
            Logger.log(level: .native, "📊 DEBUG: sendPixelEvent - name: apn, env: sandbox, state: denied")
            model?.sendPixelEvent(name: "apn", payload: ["env": "sandbox", "state": "denied"])
            return ["token": ""]
        }
    }

    let env: String = {
        #if DEBUG
            return "sandbox" // Sandbox environment for Debug builds
        #else
            return "production" // Production environment for Release builds
        #endif
    }()
}
