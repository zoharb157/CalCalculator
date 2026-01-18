//
//  JSActionSetCID.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 15/07/2024.
//

import Foundation
import SwiftUI

struct JSActionSetCID: JSActionProtocol {
    @AppStorage(StoreKeys.cid.rawValue) private var cid: String?

    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        guard let cid = parameters["cid"] as? String else {
            throw SDKError.withReason("Missing parameter cid")
        }

        self.cid = cid

        return nil
    }
}
