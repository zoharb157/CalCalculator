//
//  File.swift
//  SDK
//
//  Created by Dubon Ya'ar on 18/03/2025.
//

import Foundation
import JWTKit

struct JWYHeaderPayload: JWTPayload {
    // var sub: SubjectClaim
    private var exp: ExpirationClaim
    private var iat: ExpirationClaim
    private var user_id: String
    private var secret: [UInt8]
    private var key: UInt8

    func verify(using key: some JWTAlgorithm) throws {
        try exp.verifyNotExpired()
    }

    init(userId: String, secret: [UInt8], key: UInt8, experation: Date) {
        exp = .init(value: experation)
        iat = .init(value: .now)
        user_id = userId
        self.secret = secret
        self.key = key
    }

    func jwtToken() async throws -> String {
        let keys = JWTKeyCollection()
        let string = xorDecrypt(encrypted: secret, key: key)
        await keys.add(hmac: .init(from: string), digestAlgorithm: .sha256)
        return try await keys.sign(self, kid: "my-key")
    }

    private func xorDecrypt(encrypted: [UInt8], key: UInt8) -> String {
        return String(bytes: encrypted.map { $0 ^ key }, encoding: .utf8) ?? ""
    }
}
