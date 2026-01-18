//
//  File.swift
//  SDK
//
//  Created by Dubon Ya'ar on 27/10/2025.
//

import Foundation
import Photos

public struct JSActionAuthGallery: JSActionProtocol {
    public func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        let result = await PhotoGalleryAuthManager.shared.authorize(accessLevel: .readWrite)

        return ["result": authStatusToString(result)]
    }
}

public struct JSActionGetGalleryAuthStatus: JSActionProtocol {
    public func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        return await ["result": authStatusToString(PhotoGalleryAuthManager.shared.authStatus)]
    }
}

private func authStatusToString(_ status: PHAuthorizationStatus) -> String {
    switch status {
    case .authorized: "authorized"
    case .notDetermined: "notDetermined"
    case .denied: "denied"
    case .restricted: "restricted"
    case .limited: "limited"
    @unknown default:
        "unknown"
    }
}
