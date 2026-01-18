//
//  File.swift
//
//
//  Created by Dubon Ya'ar on 01/11/2024.
//

import Foundation
import UIKit
struct JSActionPresentDialog: JSActionProtocol {
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        try await Task.detached { @MainActor in

            guard let keyWindow = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else { throw SDKError.generic }

            var topController = keyWindow.rootViewController
            while let presentedController = topController?.presentedViewController {
                topController = presentedController
            }

            let alert = UIAlertController(title: parameters["title"] as? String,
                                          message: parameters["message"] as? String,
                                          preferredStyle: .alert)

            let result: String = try await withCheckedThrowingContinuation { continutation in
                (parameters["actions"] as? [String])?.forEach { action in
                    alert.addAction(.init(title: action, style: .default, handler: { _ in
                        continutation.resume(returning: action)
                    }))
                }

                if let topController {
                    topController.present(alert, animated: true)
                } else {
                    continutation.resume(throwing: SDKError.generic)
                }
            }

            return ["action": result]
        }
        .result
        .get()
    }
}
