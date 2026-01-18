//
//  JSActionIsSubscribed.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 21/07/2024.
//

import SwiftUI

struct JSActionIsSubscribed: JSActionProtocol {
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        return ["isSubscribed": API.IAP.isSibscribed.value]
    }
}
