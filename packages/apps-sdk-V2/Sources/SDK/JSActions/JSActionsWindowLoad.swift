//
//  File.swift
//
//
//  Created by Dubon Ya'ar on 16/09/2024.
//

import Foundation

@MainActor
struct JSActionsWindowLoad: JSActionProtocol {
    weak var model: TheSDK?

    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        guard let model else { return nil }
        var buildString = ""
        if let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            buildString = "(\(buildVersion))"
        }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        var params: [String: Any] = ["appVersion": "\(appVersion)\(buildString)", "isFirstRun": model.isFirstRun]

        if let installTime = SDKStore.lastInstallTime {
            params["installTime"] = installTime
        }
        params["isTestingEnv"] = model.isSimulatorOrTestFlight()

        return nil
    }
}
