//
//  JSActionLog.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 16/07/2024.
//

import Foundation

struct JSActionLog: JSActionProtocol {
    let logEnabled: Bool

    init(config: SDKConfig) {
        logEnabled = config.logOptions?.contains(.js) ?? false
    }

    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        guard logEnabled else { return nil }

        guard let message = parameters["message"] else {
            throw SDKError.withReason("Missing parameter message")
        }

        let level = parameters["level"] as? String
        var prefix: String = ""
        switch level {
        case "warning":
            prefix = "🟡"
        case "error":
            prefix = "🔴"
        default:
            prefix = "🔵"
        }

        Logger.log(level: .js, prefix, message)

        return nil
    }
}
