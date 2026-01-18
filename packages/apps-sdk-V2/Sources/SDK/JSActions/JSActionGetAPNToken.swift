//
//  JSActionGetAPNToken.swift
//  SDK
//
//  Created by AI Assistant on 17/11/2024.
//

import Foundation

class JSActionGetAPNToken: NSObject, JSActionProtocol {
    weak var model: TheSDK?
    
    init(model: TheSDK) {
        self.model = model
    }
    
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        let token = APNSManager.shared.token ?? ""
        
        // Send pixel event to track token extraction
        Logger.log(level: .native, "📊 DEBUG: sendPixelEvent - name: APNToken, token: \(token)")
        model?.sendPixelEvent(name: "APNToken", payload: ["token": token])
        
        return ["token": token]
    }
}

