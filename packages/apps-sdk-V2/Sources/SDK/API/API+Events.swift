//
//  SDKAPI+Events.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 21/07/2024.
//

// import CommonSwiftUI
import Foundation
import KeychainAccess
import UIKit

public extension API {
    enum Maven {
        public static func getProductQuantities(userId: String?, sessionId: String?, baseURL: URL, installTime: String?) async throws -> [String: Int] {
            var request = URLRequest(url: baseURL)
                .appendPathComponent("getProductsQuantities")
                .method(HTTPMethod.get)
                .appendJsonAcceptHeader()
                .encodeQueryParamaters(data: ["senderVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""])
                .encodeQueryParamaters(data: ["appsFlyerUserId": userId ?? "unknown"])
                .encodeQueryParamaters(data: ["deviceModel": Utils.deviceModel])
                .encodeQueryParamaters(data: ["osVersion": Utils.osVersion])

            if let marketingDeviceName = Utils.marketingDeviceName {
                request = request.encodeQueryParamaters(data: ["marketingDeviceName": marketingDeviceName])
            }

            if let installTime {
                request = request.encodeQueryParamaters(data: ["installTime": installTime])
            }
            if let bundleId = Bundle.main.bundleIdentifier {
                request = request.encodeQueryParamaters(data: ["appName": bundleId])
            }

            if let userId {
                request = request.encodeQueryParamaters(data: ["userId": userId])
            }
            if let sessionId {
                request = request.encodeQueryParamaters(data: ["session_id": sessionId])
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    Logger.log(level: .native, "⚠️ API.Maven.getProductQuantities failed with HTTP \(httpResponse.statusCode)")
                    // Log response body for debugging
                    if let responseString = String(data: data, encoding: .utf8) {
                        Logger.log(level: .native, "⚠️ Response body: \(responseString.prefix(200))")
                    }
                    throw SDKError.withReason("HTTP error \(httpResponse.statusCode)")
                }
            }

            if let result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Int] {
                return result
            } else {
                // Log the actual response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    Logger.log(level: .native, "⚠️ API.Maven.getProductQuantities received non-JSON response: \(responseString.prefix(200))")
                }
                throw SDKError.generic
            }
        }

        public static func isUserSubscrbied(userId: String?, sessionId: String?, baseURL: URL, installTime: String?) async throws -> Bool {
            var request = URLRequest(url: baseURL)
                .appendPathComponent("isSubscribed")
                .method(HTTPMethod.get)
                .appendJsonAcceptHeader()
                .encodeQueryParamaters(data: ["senderVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""])
                .encodeQueryParamaters(data: ["appsFlyerUserId": userId ?? "unknown"])
                .encodeQueryParamaters(data: ["deviceModel": Utils.deviceModel])
                .encodeQueryParamaters(data: ["osVersion": Utils.osVersion])

            if let marketingDeviceName = Utils.marketingDeviceName {
                request = request.encodeQueryParamaters(data: ["marketingDeviceName": marketingDeviceName])
            }

            if let installTime {
                request = request.encodeQueryParamaters(data: ["installTime": installTime])
            }
            if let bundleId = Bundle.main.bundleIdentifier {
                request = request.encodeQueryParamaters(data: ["appName": bundleId])
            }

            if let userId {
                request = request.encodeQueryParamaters(data: ["userId": userId])
            }
            if let sessionId {
                request = request.encodeQueryParamaters(data: ["session_id": sessionId])
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode >= 400 {
                        Logger.log(level: .native, "⚠️ API.Maven.isUserSubscrbied failed with HTTP \(httpResponse.statusCode)")
                        // Log response body for debugging
                        if let responseString = String(data: data, encoding: .utf8) {
                            Logger.log(level: .native, "⚠️ Response body: \(responseString.prefix(200))")
                        }
                        return false // Fail gracefully
                    }
                }

                if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let subscribed = result["res"] as? Bool {
                    return subscribed
                }
                
                // If we get here, the response wasn't valid JSON
                if let responseString = String(data: data, encoding: .utf8) {
                    Logger.log(level: .native, "⚠️ API.Maven.isUserSubscrbied received non-JSON response: \(responseString.prefix(200))")
                }

                return false

            } catch {
                Logger.log(level: .native, "⚠️ API.Maven.isUserSubscrbied error: \(error)")
                throw error
            }
        }
    }

    enum Events {
        public static func send(userId: String?,
                                sessionId: String?,
                                baseURL: URL,
                                name: String,
                                installTime: String?,
                                info: Any? = nil,
                                queryItems: [URLQueryItem]? = nil,
                                jwtToken: String? = nil) async throws
        {
            var url = baseURL
                .appendingPathComponent("collect")
                .appending(queryItems: [
                    .init(name: "source", value: "native"),
                    .init(name: "event", value: name),
                    .init(name: "senderVersion", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""),
                    .init(name: "appsFlyerUserId", value: userId ?? "unknown"),
                    .init(name: "deviceModel", value: Utils.deviceModel),
                    .init(name: "osVersion", value: Utils.osVersion),
                    .init(name: "sdkVersion", value: TheSDK.version)
                ])

            if let queryItems {
                url = url.appending(queryItems: queryItems)
            }

            if let installTime {
                url = url.appending(queryItems: [.init(name: "installTime", value: installTime)])
            }

            if let bundleId = Bundle.main.bundleIdentifier {
                url = url.appending(queryItems: [.init(name: "appName", value: bundleId)])
            }

            if let userId {
                url = url.appending(queryItems: [.init(name: "userId", value: userId)])
            }

            if let sessionId {
                url = url.appending(queryItems: [.init(name: "session_id", value: sessionId)])
            }

            var request = URLRequest(url: url)
                .method(.post)
                .appendJsonAcceptHeader()

            if let info,
               let requestWithBody = try? request.encodeJsonBody(object: info, options: [.fragmentsAllowed])
            {
                request = requestWithBody
            }

            if let jwtToken {
                request = request.appendHeaders(["Authorization": "Bearer \(jwtToken)"])
            }

            Logger.log(level: .native, "📊 DEBUG: API.Events.send - name: \(name), userId: \(userId ?? "nil"), info: \(info ?? "nil")")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let code = (response as? HTTPURLResponse)?.statusCode, code > 399 {
                    // Log response body for debugging
                    if let responseString = String(data: data, encoding: .utf8) {
                        Logger.log(level: .native, "⚠️ API.Events.send failed with HTTP \(code), response: \(responseString.prefix(200))")
                    }
                    throw SDKError.withReason("http error \(code)")
                }
            } catch {
                Logger.log(level: .native, "⚠️ API.Events.send error for event '\(name)': \(error)")
                throw error
            }
        }
    }
}
