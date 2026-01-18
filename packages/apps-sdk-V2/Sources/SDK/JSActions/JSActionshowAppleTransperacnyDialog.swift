//
//  File.swift
//
//
//  Created by Dubon Ya'ar on 11/08/2024.
//

import AdSupport
import AppTrackingTransparency
import Foundation
import SwiftUI

struct JSActionshowAppleTransperacnyDialog: JSActionProtocol {
    weak var model: TheSDK?
    
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        return await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization {
                var adIdetiifer: String?

                if $0 == .authorized {
                    let sharedASIdentifierManager = ASIdentifierManager.shared()
                    adIdetiifer = sharedASIdentifierManager.advertisingIdentifier.uuidString
                }

                var result: [String: Any] = ["result": $0.toString]

                if let adIdetiifer {
                    result["adIdentifier"] = adIdetiifer
                }

                continuation.resume(returning: result)
            }
        }
    }
}
