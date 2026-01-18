//
//  Camera.swift
//  SDK
//
//  Created by Dubon Ya'ar on 27/10/2025.
//

import AVFoundation
import Foundation

public struct JSActionAuthCamera: JSActionProtocol {
    public func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        let result = await CameraAuthManager.shared.authorize()

        return ["result": cameraAuthStatusToString(result)]
    }
}

public struct JSActionGetCameraAuthStatus: JSActionProtocol {
    public func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        return ["result": cameraAuthStatusToString(CameraAuthManager.shared.authStatus)]
    }
}

private func cameraAuthStatusToString(_ status: AVAuthorizationStatus) -> String {
    switch status {
    case .authorized: "authorized"
    case .notDetermined: "notDetermined"
    case .denied: "denied"
    case .restricted: "restricted"
    @unknown default:
        "unknown"
    }
}
