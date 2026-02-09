//
//  ActivityPixelService.swift
//  playground
//

import Foundation
import SDK

enum PixelType: String, CaseIterable {
    case lifecycle = "lifecycle"
    case navigation = "navigation"
    case interaction = "interaction"
    case engagement = "engagement"
    case transaction = "transaction"
    
    var counterKey: String { "activityPixel_\(rawValue)_count" }
}

final class ActivityPixelService {
    static let shared = ActivityPixelService()
    
    private let actionNumberKey = "activityPixel_actionNumber"
    private var appOpenedSentThisSession = false
    private weak var sdk: TheSDK?
    
    private init() {}
    
    func configure(with sdk: TheSDK) {
        self.sdk = sdk
    }
    
    // MARK: - Persisted Counters
    
    private var actionNumber: Int {
        get { UserDefaults.standard.integer(forKey: actionNumberKey) }
        set { UserDefaults.standard.set(newValue, forKey: actionNumberKey) }
    }
    
    private func getTypeCount(_ type: PixelType) -> Int {
        UserDefaults.standard.integer(forKey: type.counterKey)
    }
    
    private func incrementTypeCount(_ type: PixelType) -> Int {
        let current = getTypeCount(type)
        let newValue = current + 1
        UserDefaults.standard.set(newValue, forKey: type.counterKey)
        return newValue
    }
    
    // MARK: - Main Track Function
    
    func track(_ action: String, type: PixelType? = nil) {
        if action == "app_opened" {
            guard !appOpenedSentThisSession else { return }
            appOpenedSentThisSession = true
        }
        
        actionNumber += 1
        let currentActionNumber = actionNumber
        let pixelType = type ?? getType(for: action)
        let typeCount = incrementTypeCount(pixelType)
        
        let payload: [String: Any] = [
            "a": action,
            "t": pixelType.rawValue,
            "n": currentActionNumber,
            "nt": typeCount
        ]
        
        #if DEBUG
        print("📍 PIXEL #\(currentActionNumber): \(action) [t: \(pixelType.rawValue), nt: \(typeCount)]")
        #endif
        
        sdk?.logGA4Event(name: "activity_pixel", parameters: payload)
    }
    
    // MARK: - Auto Type Detection
    
    private func getType(for action: String) -> PixelType {
        let lowercased = action.lowercased()
        
        if lowercased.contains("app_opened") ||
           lowercased.contains("_success") ||
           lowercased.contains("_failed") ||
           lowercased.contains("permission_") {
            return .lifecycle
        }
        
        if lowercased.hasPrefix("tab_") ||
           lowercased.hasPrefix("screen_") ||
           lowercased.hasPrefix("mode_") ||
           lowercased.hasPrefix("editor_") ||
           lowercased.contains("closed_") {
            return .navigation
        }
        
        if lowercased.contains("rate_us") ||
           lowercased.contains("feedback") ||
           lowercased.contains("survey") {
            return .engagement
        }
        
        if lowercased.contains("purchase") ||
           lowercased.contains("restore") ||
           lowercased.contains("subscription") ||
           lowercased.hasPrefix("paywall_shown") ||
           lowercased == "premium_button_tapped" {
            return .transaction
        }
        
        return .interaction
    }
}

// MARK: - Convenience Wrapper

enum Pixel {
    static func track(_ action: String, type: PixelType? = nil) {
        ActivityPixelService.shared.track(action, type: type)
    }
}
