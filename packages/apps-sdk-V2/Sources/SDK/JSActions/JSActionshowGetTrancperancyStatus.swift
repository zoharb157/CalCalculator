//
//  File.swift
//
//
//  Created by Dubon Ya'ar on 11/08/2024.
//

import AppTrackingTransparency
import Foundation
import SwiftUI

struct JSActionshowGetTrancperancyStatus: JSActionProtocol {
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        return ["result": ATTrackingManager.trackingAuthorizationStatus.toString]
    }
}
