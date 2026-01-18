//
//  SDKAPI.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 17/07/2024.
//

import Foundation

public enum API {}

private struct IsSubscribeResult: Codable {
    let res: Bool
}

extension API {
    enum Subscritpion {
        static func restore(baseURL: URL, userId: String) async throws -> Bool {
            let request = URLRequest(url: baseURL)
                .appendPathComponent("isSubscribed")
                .appendJsonAcceptHeader()
                .encodeQueryParamaters(data: ["uid": userId])

            let (data, _) = try await URLSession.shared.data(for: request)
            let result = try JSONDecoder().decode(IsSubscribeResult.self, from: data)
            return result.res
        }
    }
}
