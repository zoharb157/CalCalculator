//
//  File.swift
//
//
//  Created by Dubon Ya'ar on 27/08/2024.
//

import Foundation

import AppTrackingTransparency
import Foundation
import SwiftUI

struct JSActionCanOpenSchema: JSActionProtocol {
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        guard let schema = parameters["schema"] as? String else {
            throw SDKError.withReason("missing schema parameter")
        }

        guard let url = URL(string: schema) else {
            throw SDKError.withReason("incorrect schema format")
        }

        return await ["result": UIApplication.shared.canOpenURL(url)]
    }
}
