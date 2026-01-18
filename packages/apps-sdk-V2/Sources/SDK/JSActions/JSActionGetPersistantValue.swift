//
//  File.swift
//  SDK
//
//  Created by Dubon Ya'ar on 20/02/2025.
//

import Foundation

struct JSActionGetPersistantValue: JSActionProtocol {
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        guard let key = parameters["key"] as? String else {
            throw SDKError.withReason("missing paramerers key")
        }

        guard let value = UserDefaults.standard.value(forKey: "sdk.js:\(key)") else {
            return nil
        }

        if let value = value as? Data, let result = try? JSONSerialization.jsonObject(with: value) {
            return ["value": result]
        } else {
            return ["value": value]
        }
    }
}
