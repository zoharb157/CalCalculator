//
//  JSActionSendFacebookPixel.swift
//  SDK
//
//  Created for Facebook Conversions API integration
//

import Foundation
import UIKit

struct JSActionSendFacebookPixel: JSActionProtocol {
    weak var model: TheSDK?
    
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        print("🟣 [FB-PIXEL] JSActionSendFacebookPixel.perform() CALLED")
        print("🟣 [FB-PIXEL] Parameters received: \(parameters)")
        
        guard let model else {
            print("🔴 [FB-PIXEL] ERROR: Model is nil")
            return nil
        }
        
        // Extract required parameters
        guard let pixelId = parameters["pixelId"] as? String else {
            print("🔴 [FB-PIXEL] ERROR: Missing pixelId")
            throw SDKError.withReason("Missing parameter: pixelId")
        }
        
        guard let accessToken = parameters["accessToken"] as? String else {
            print("🔴 [FB-PIXEL] ERROR: Missing accessToken")
            throw SDKError.withReason("Missing parameter: accessToken")
        }
        
        guard let eventName = parameters["eventName"] as? String else {
            print("🔴 [FB-PIXEL] ERROR: Missing eventName")
            throw SDKError.withReason("Missing parameter: eventName")
        }
        
        print("🟣 [FB-PIXEL] Pixel ID: \(pixelId)")
        print("🟣 [FB-PIXEL] Event Name: \(eventName)")
        print("🟣 [FB-PIXEL] Access Token: \(accessToken.prefix(10))...")
        
        // Get event data
        let eventData = parameters["eventData"] as? [String: Any] ?? [:]
        print("🟣 [FB-PIXEL] Event Data: \(eventData)")
        
        // Get custom data
        let customData = parameters["customData"] as? [String: Any] ?? [:]
        print("🟣 [FB-PIXEL] Custom Data: \(customData)")
        
        // Get user data (for matching)
        let userData = parameters["userData"] as? [String: Any] ?? [:]
        print("🟣 [FB-PIXEL] User Data: \(userData)")
        
        // Get test event code if provided
        let testEventCode = parameters["testEventCode"] as? String
        if let code = testEventCode {
            print("🟣 [FB-PIXEL] Test Event Code: \(code)")
        }
        
        // Build the event payload
        let eventTime = Int(Date().timeIntervalSince1970)
        let eventId = parameters["eventId"] as? String ?? UUID().uuidString
        
        var eventPayload: [String: Any] = [
            "event_name": eventName,
            "event_time": eventTime,
            "event_id": eventId,
            "event_source_url": parameters["eventSourceUrl"] as? String ?? "app://phototool",
            "action_source": "app"
        ]
        
        // Add custom data if provided
        if !customData.isEmpty {
            eventPayload["custom_data"] = customData
        }
        
        // Add user data if provided
        if !userData.isEmpty {
            eventPayload["user_data"] = userData
        } else {
            // Use SDK's user data
            var autoUserData: [String: Any] = [:]
            
            // Add external ID (user ID)
            if let userId = model.userId {
                autoUserData["external_id"] = [userId]
                print("🟣 [FB-PIXEL] Added userId: \(userId)")
            }
            
            // Add anonymous ID (Facebook's anonymous ID from SDK)
            if let anonymousId = parameters["anonymousId"] as? String {
                autoUserData["client_user_agent"] = anonymousId
                print("🟣 [FB-PIXEL] Added anonymousId: \(anonymousId)")
            }
            
            eventPayload["user_data"] = autoUserData
        }
        
        // Add app data
        let appData: [String: Any] = [
            "advertiser_tracking_enabled": parameters["attAuthorized"] as? Bool ?? false,
            "application_tracking_enabled": parameters["attAuthorized"] as? Bool ?? false,
            "extinfo": [
                "i2",  // iOS
                model.appVersion,
                Bundle.main.bundleIdentifier ?? "unknown",
                UIDevice.current.systemVersion,
                UIDevice.current.model
            ]
        ]
        eventPayload["app_data"] = appData
        
        print("🟣 [FB-PIXEL] Complete event payload: \(eventPayload)")
        
        // Build the data array (can send multiple events)
        let eventsData = [eventPayload]
        
        // Build request body
        var requestBody: [String: Any] = [
            "data": eventsData
        ]
        
        if let testCode = testEventCode {
            requestBody["test_event_code"] = testCode
        }
        
        print("🟣 [FB-PIXEL] Request body: \(requestBody)")
        
        // Build URL
        let urlString = "https://graph.facebook.com/v18.0/\(pixelId)/events?access_token=\(accessToken)"
        guard let url = URL(string: urlString) else {
            print("🔴 [FB-PIXEL] ERROR: Invalid URL")
            throw SDKError.withReason("Invalid Facebook Graph API URL")
        }
        
        print("🟣 [FB-PIXEL] Sending to URL: https://graph.facebook.com/v18.0/\(pixelId)/events")
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("🔴 [FB-PIXEL] ERROR: Failed to serialize JSON: \(error)")
            throw SDKError.withReason("Failed to serialize request body")
        }
        
        print("🟣 [FB-PIXEL] Sending HTTP POST request...")
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔴 [FB-PIXEL] ERROR: Invalid response type")
            throw SDKError.withReason("Invalid response")
        }
        
        print("🟣 [FB-PIXEL] Response status code: \(httpResponse.statusCode)")
        
        // Parse response
        let responseString = String(data: data, encoding: .utf8) ?? ""
        print("🟣 [FB-PIXEL] Response body: \(responseString)")
        
        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🟢 [FB-PIXEL] ========================================")
                print("🟢 [FB-PIXEL] ✅✅✅ PIXEL SENT SUCCESSFULLY!")
                print("🟢 [FB-PIXEL] Event: \(eventName)")
                print("🟢 [FB-PIXEL] Event ID: \(eventId)")
                print("🟢 [FB-PIXEL] Events Received: \(json["events_received"] ?? 0)")
                print("🟢 [FB-PIXEL] Response: \(json)")
                print("🟢 [FB-PIXEL] ========================================")
                
                return [
                    "success": true,
                    "eventId": eventId,
                    "eventsReceived": json["events_received"] ?? 0,
                    "response": json
                ]
            }
        } else {
            print("🔴 [FB-PIXEL] ========================================")
            print("🔴 [FB-PIXEL] ❌❌❌ PIXEL SEND FAILED!")
            print("🔴 [FB-PIXEL] Status Code: \(httpResponse.statusCode)")
            print("🔴 [FB-PIXEL] Response: \(responseString)")
            print("🔴 [FB-PIXEL] ========================================")
            
            throw SDKError.withReason("Facebook API error: \(httpResponse.statusCode) - \(responseString)")
        }
        
        print("🟣 [FB-PIXEL] Completed")
        return ["success": true]
    }
}

