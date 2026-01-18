//
//  URLRequest+Builder.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 16/07/2024.
//

import Foundation
extension URLRequest {
    // MARK: Initailizers

    init(url: String) {
        self.init(url: URL(string: url)!)
    }

    func method(_ method: HTTPMethod) -> URLRequest {
        var copy = self
        copy.httpMethod = method.rawValue
        return copy
    }

    func appendPathComponent(_ path: String) -> URLRequest {
        var copy = self
        copy.url?.appendPathComponent(path)
        return copy
    }

    func encodeQueryParamaters(data: [String: AnyHashable]) -> URLRequest {
        var copy = self
        var components = URLComponents(string: (copy.url?.absoluteString)!)!
        var queryItems: [URLQueryItem] = components.queryItems ?? []
        data.forEach { key, value in
            queryItems.append(URLQueryItem(name: key as String, value: String(describing: value)))
        }
        components.queryItems = queryItems
        copy.url = components.url
        return copy
    }

    func encodeJsonBody(object: Any, options: JSONSerialization.WritingOptions? = nil) throws -> URLRequest {
        var request = appendJsonContentTypeHeader()

        if JSONSerialization.isValidJSONObject(object) {
            request.httpBody = try JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed])
            return request
        } else {
            throw SDKError.withReason("can't serilizse object to json")
        }
    }

    func appendHeaders(_ data: [String: String]) -> URLRequest {
        var copy = self
        data.forEach { key, value in
            copy.setValue(value, forHTTPHeaderField: key)
        }
        return copy
    }

    func appendJsonAcceptHeader() -> URLRequest {
        appendHeaders(["accept": "application/json"])
    }

    func appendJsonContentTypeHeader() -> URLRequest {
        appendHeaders(["Content-Type": "application/json"])
    }

    func encodeEncodableAsJsonBody<T: Encodable>(encodable: T) throws -> URLRequest {
        var copy = self
        copy = copy.appendJsonContentTypeHeader()
        let encoder = JSONEncoder()
        let data = try encoder.encode(encodable)
        copy.httpBody = data
        return copy
    }
}
