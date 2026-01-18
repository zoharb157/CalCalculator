//
//  File.swift
//  SDK
//
//  Created by Dubon Ya'ar on 01/08/2025.
//

import Foundation

import Foundation

struct JSActionAnalyticsEvent: JSActionProtocol {
    weak var model: TheSDK?
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        guard let eventName = parameters["name"] as? String else {
            throw SDKError.withReason("missing parameter name of type string")
        }

        let values = parameters["values"]

        // TODO:
        //  model?.sendPixelEvent(name: eventName, payload: values)

        return [:]
    }
}
