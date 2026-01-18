//
//  File.swift
//  SDK
//
//  Created by Dubon Ya'ar on 12/02/2025.
//

import Foundation
@MainActor

struct JSActionGetSubscriptionStatus: JSActionProtocol {
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        guard let id = parameters["id"] as? String else {
            throw SDKError.withReason("missing id of type String")
        }

        let subsiprionStatus = try await API.IAP.checkSubscriptionStatus(forProductionId: id)
        return ["result": subsiprionStatus ?? []]
    }
}
