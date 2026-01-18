//
//  JSActionSetIsSubscribed.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 16/07/2024.
//

import SwiftUI

struct JSActionSetIsSubscribed: JSActionProtocol {
    var model: TheSDK?
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        guard let isSubscribed = parameters["status"] as? Bool else {
            throw SDKError.withReason("Missing parameter status")
        }

        Task {
            await MainActor.run {
                self.model?.isSubscribed = isSubscribed
            }
        }

        return ["status": isSubscribed]
    }
}
