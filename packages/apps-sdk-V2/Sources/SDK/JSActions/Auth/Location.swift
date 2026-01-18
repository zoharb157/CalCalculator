//
//  Location.swift
//  SDK
//
//  Created by Dubon Ya'ar on 27/10/2025.
//

import CoreLocation
import Foundation

public struct JSActionAuthLocation: JSActionProtocol {
    public func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        let result = await LocationAuthManager.shared.authorize()

        return ["result": locationAuthStatusToString(result)]
    }
}

public struct JSActionGetLocationAuthStatus: JSActionProtocol {
    public func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        return ["result": locationAuthStatusToString(LocationAuthManager.shared.authStatus)]
    }
}

private func locationAuthStatusToString(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .authorizedAlways: "authorizedAlways"
    case .authorizedWhenInUse: "authorizedWhenInUse"
    case .notDetermined: "notDetermined"
    case .denied: "denied"
    case .restricted: "restricted"
    @unknown default:
        "unknown"
    }
}

