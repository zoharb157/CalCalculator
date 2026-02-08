//
//  AuthenticationManager.swift
//  playground
//
//  Created by Bassam-Hillo on 18/12/2025.
//

import Foundation
import CommonCrypto

final class AuthenticationManager {
    static let shared = AuthenticationManager()
    
    private let defaults = UserDefaults.standard
    private let apiToken = "OdIlX0QEIodS2ixLg2v0WFI5Hb7EH9cFDGEaNa94Xts="
    
    private enum Keys {
        static let userId = "auth_user_id"
    }
    
    var userId: String? {
        get { defaults.string(forKey: Keys.userId) }
        set { defaults.set(newValue, forKey: Keys.userId) }
    }
    
    /// Returns a properly formatted JWT token wrapping the API token
    var jwtToken: String? {
        guard let userId = userId else { return nil }
        return createJWT(userId: userId, token: apiToken)
    }
    
    var isAuthenticated: Bool {
        userId != nil
    }
    
    private init() {
        if userId == nil {
            userId = generateUserId()
        }
    }
    
    func setUserId(_ id: String) {
        userId = id
    }
    
    func clearCredentials() {
        userId = nil
    }
    
    func regenerateUserId() {
        userId = generateUserId()
    }
    
    private func generateUserId() -> String {
        let uuid = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        return "demo_user_\(uuid.prefix(8).uppercased())"
    }
    
    /// Creates a JWT token with the user_id in the payload
    /// This mimics the --wrap-token-as-jwt behavior from the CLI tool
    private func createJWT(userId: String, token: String) -> String {
        // JWT Header: {"alg": "HS256", "typ": "JWT"}
        let header = ["alg": "HS256", "typ": "JWT"]
        
        // JWT Payload: {"user_id": "<userId>", "iat": <timestamp>, "exp": <timestamp+1hour>}
        let now = Int(Date().timeIntervalSince1970)
        let exp = now + 3600 // 1 hour expiration
        let payload: [String: Any] = [
            "user_id": userId,
            "iat": now,
            "exp": exp
        ]
        
        // Base64URL encode header and payload
        guard let headerData = try? JSONSerialization.data(withJSONObject: header),
              let payloadData = try? JSONSerialization.data(withJSONObject: payload) else {
            return token // Fallback to raw token
        }
        
        let headerBase64 = base64URLEncode(headerData)
        let payloadBase64 = base64URLEncode(payloadData)
        
        // Create signature using HMAC-SHA256 with the API token as the secret
        let signatureInput = "\(headerBase64).\(payloadBase64)"
        guard let signatureInputData = signatureInput.data(using: .utf8) else {
            return token
        }
        
        // Use the API token as the signing key
        let signature = hmacSHA256(data: signatureInputData, key: token)
        let signatureBase64 = base64URLEncode(signature)
        
        return "\(headerBase64).\(payloadBase64).\(signatureBase64)"
    }
    
    private func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func hmacSHA256(data: Data, key: String) -> Data {
        guard let keyData = key.data(using: .utf8) else {
            return Data()
        }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        keyData.withUnsafeBytes { keyBytes in
            data.withUnsafeBytes { dataBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                       keyBytes.baseAddress, keyData.count,
                       dataBytes.baseAddress, data.count,
                       &digest)
            }
        }
        
        return Data(digest)
    }
}
