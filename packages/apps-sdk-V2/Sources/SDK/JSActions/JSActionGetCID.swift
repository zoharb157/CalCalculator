//
//  JSActionGetCID.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 21/07/2024.
//

import SwiftUI

struct JSActionGetCID: JSActionProtocol {
    @AppStorage(StoreKeys.cid.rawValue) private var cid: String?

    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        if let cid {
            return ["cid": cid]
        } else {
            return nil
        }
    }
}
