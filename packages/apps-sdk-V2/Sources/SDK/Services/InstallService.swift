//
//  File.swift
//  SDK
//
//  Created by Dubon Ya'ar on 05/06/2025.
//

import Foundation
import SwiftUI

enum InstallService {
    @AppStorage("installed") static var installed: Bool = false

    static func run(config: SDKConfig, userId: String) {
        if !installed {
            installed = true

            let dateFormatter = DateFormatter()
            dateFormatter.calendar = Calendar(identifier: .iso8601)
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.000XXXXX"
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")

            let nowString = dateFormatter.string(from: .now)

            SDKStore.firstInstallTime = SDKStore.firstInstallTime ?? nowString
            SDKStore.lastInstallTime = nowString
            SDKStore.numberOfInstalls += 1

            var payload: [String: Any] = [:]

            payload["firstInstall"] = SDKStore.firstInstallTime ?? nowString
            payload["lastInstall"] = nowString
            payload["numberOfInstalls"] = SDKStore.numberOfInstalls

            Task {
                try? await API.Events.send(userId: userId,
                                           sessionId: SDKStore.sessionId,
                                           baseURL: config.domainURL,
                                           name: "First Run",
                                           installTime: nowString, info: payload)
            }
        }
    }
}
