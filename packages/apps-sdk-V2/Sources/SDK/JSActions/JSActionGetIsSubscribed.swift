//
//  JSActionGetIsSubscribed.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 21/07/2024.
//

import SwiftUI

@MainActor

struct JSActionGetIsSubscribed: JSActionProtocol {
    weak var model: TheSDK?

    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        let isSubscribed = try await model?.updateIsSubscribed() ?? false
        let originalTransactionId = await API.IAP.fetchOriginalTransactionId()
        
        return [
            "isSubscribed": isSubscribed,
            "originalTransactionId": originalTransactionId as Any
        ]
    }
}
