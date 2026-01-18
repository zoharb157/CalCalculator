//
//  Types.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 16/07/2024.
//

import AppTrackingTransparency
import Combine
import Foundation
import SwiftUI

public struct JSEventWrapper {
    var id: String
    var name: String
    var parameters: [String: Any]
    var error: String?

    public init(id: String, name: String, parameters: [String: Any], error: String? = nil) {
        self.id = id
        self.name = name
        self.parameters = parameters
        self.error = error
    }
}

public enum HTTPMethod: String { case get, put, post, delete }

public enum SDKError: Error { case generic, withReason(String) }

enum StoreKeys: String { case userId = "__userId__",
                              cid = "__cid__",
                              fistInsntallTime = "__fistIsntallTime__",
                              installTime = "__installTime__",
                              firstRun = "__firstRun__"
}

public enum Page: RawRepresentable, Equatable, Hashable, Codable, Identifiable {
    public typealias RawValue = String

    public var id: String {
        rawValue
    }

    case splash, unlockContent, premium, custom(URL)

    public init?(rawValue: String) {
        switch rawValue {
        case "splash":
            self = .splash
        case "unlockContent":
            self = .unlockContent
        case "premium":
            self = .premium
        default:
            return nil
        }
    }

    public var rawValue: String {
        String(describing: self)
    }
}

public enum SDKEnv { case dev, production }

public struct LogOptions: OptionSet {
    public let rawValue: Int

    public static let native = LogOptions(rawValue: 1 << 0)
    public static let js = LogOptions(rawValue: 1 << 1)
    public static let all: LogOptions = [.native, .js]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public typealias JWTAuthHeader = (secret: [UInt8], key: UInt8, experation: Date)

public typealias SDKNotificationHandler = (APNSAction) -> Void

public extension ATTrackingManager.AuthorizationStatus {
    var toString: String {
        switch self {
        case .authorized:
            return "authorized"
        case .denied:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        @unknown default:
            return "@unknown"
        }
    }
}

enum LifecycleEventName: String { case active, inactive, foreground, background, terminate }
