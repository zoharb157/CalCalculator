
//
//  JSActionGetCID.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 21/07/2024.
//

import Foundation

struct JSActionSetPersistantValue: JSActionProtocol {
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        guard let key = parameters["key"] as? String else {
            throw SDKError.withReason("missing paramerers key of type String")
        }

        guard let value = parameters["value"] else {
            throw SDKError.withReason("missing paramerers value")
        }

        if let value = value as? Encodable {
            guard let data = try? JSONEncoder().encode(value) else {
                throw SDKError.withReason("error serilizing value")
            }
            UserDefaults.standard.set(data, forKey: "sdk.js:\(key)")
        } else {
            UserDefaults.standard.set(value, forKey: "sdk.js:\(key)")
        }

        return nil
    }
}
