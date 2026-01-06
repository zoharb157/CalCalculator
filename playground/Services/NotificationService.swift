//
//  NotificationService.swift
//  playground
//
//  Service for sending device tokens to server for push notifications
//

import Foundation

final class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    /// Send device token to server
    /// - Parameters:
    ///   - token: Device token string
    ///   - userId: User ID
    func sendDeviceToken(token: String, userId: String) async throws {
        guard let url = URL(string: "\(Config.baseURL)/api/notifications/register") else {
            throw NotificationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        // Add authentication if available
        if let jwtToken = AuthenticationManager.shared.jwtToken {
            request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        }
        
        // Get app version
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        
        let body: [String: Any] = [
            "userId": userId,
            "deviceToken": token,
            "platform": "ios",
            "appVersion": "\(appVersion) (\(buildNumber))"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw NotificationError.invalidRequestBody
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NotificationError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ [NotificationService] Server error: \(httpResponse.statusCode) - \(errorMessage)")
                throw NotificationError.serverError(httpResponse.statusCode, errorMessage)
            }
            
            print("✅ [NotificationService] Device token sent successfully to server")
            
            // Optionally parse response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📱 [NotificationService] Server response: \(json)")
            }
        } catch let error as NotificationError {
            throw error
        } catch {
            print("❌ [NotificationService] Network error: \(error.localizedDescription)")
            throw NotificationError.networkError(error)
        }
    }
    
    /// Retry sending device token (useful if initial attempt fails)
    /// - Parameters:
    ///   - token: Device token string
    ///   - userId: User ID
    ///   - maxRetries: Maximum number of retry attempts
    func sendDeviceTokenWithRetry(token: String, userId: String, maxRetries: Int = 3) async {
        for attempt in 1...maxRetries {
            do {
                try await sendDeviceToken(token: token, userId: userId)
                return // Success
            } catch {
                print("⚠️ [NotificationService] Attempt \(attempt)/\(maxRetries) failed: \(error)")
                
                if attempt < maxRetries {
                    // Exponential backoff: wait 2^attempt seconds
                    let delay = pow(2.0, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    print("❌ [NotificationService] All retry attempts failed")
                }
            }
        }
    }
}

enum NotificationError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidRequestBody
    case serverError(Int, String)
    case networkError(Error)
    case missingCredentials
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidRequestBody:
            return "Failed to create request body"
        case .serverError(let code, let message):
            return "Server error \(code): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .missingCredentials:
            return "Missing user credentials"
        }
    }
}

