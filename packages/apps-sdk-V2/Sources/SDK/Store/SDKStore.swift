//
//  File.swift
//  SDK
//
//  Created by Dubon Ya'ar on 05/06/2025.
//

import Foundation
import KeychainAccess
import SwiftUI

public enum SDKStore {
    private static let keychain: Keychain = .init()

    @SDKKeychainStorage(StoreKeys.userId.rawValue) static var userId: String?
    @SDKKeychainStorage(StoreKeys.fistInsntallTime.rawValue) static var firstInstallTime: String?
    @SDKKeychainStorage(StoreKeys.installTime.rawValue) static var lastInstallTime: String?

    public static var installTime: String? { lastInstallTime }

    public internal(set) static var sessionId: String?

    public internal(set) static var numberOfInstalls: Int {
        get {
            if let string = try? keychain.get("numberOfInstalls") {
                return Int(string) ?? 0
            }

            return 0

        } set {
            try? keychain.set(String(newValue), key: "numberOfInstalls")
        }
    }

    static func reset() {
        userId = nil
        firstInstallTime = nil
        lastInstallTime = nil
        sessionId = nil
    }
}
