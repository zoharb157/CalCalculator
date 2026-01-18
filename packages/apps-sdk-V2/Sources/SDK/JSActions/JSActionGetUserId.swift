//
//  JSActionGetUserId.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 21/07/2024.
//

import SwiftUI

struct JSActionGetUserId: JSActionProtocol {
    weak var model: TheSDK?
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        guard let model, let userId = model.userId else { return nil }

        return ["userId": userId]
    }
}
