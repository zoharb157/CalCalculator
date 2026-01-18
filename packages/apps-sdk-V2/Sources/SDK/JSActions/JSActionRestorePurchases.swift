//
//  File.swift
//
//
//  Created by Dubon Ya'ar on 08/08/2024.
//

import Foundation

struct JSActionRestorePurchases: JSActionProtocol {
    weak var model: TheSDK?
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        guard let model else { return nil }

        let result = try? await model.restorePurchasesAsync()

        return ["result": result ?? false]
    }
}
