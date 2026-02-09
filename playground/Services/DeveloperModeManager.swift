//
//  DeveloperModeManager.swift
//  playground
//
//  Manages developer mode settings including premium override and debug options.
//  This manager provides a centralized way to control premium status for testing
//  without relying on SDK imports throughout the app.
//

import Foundation
import Combine

/// Manages developer mode settings for testing and debugging
/// Use this manager app-wide to check premium status instead of directly accessing SDK
final class DeveloperModeManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DeveloperModeManager()
    
    // MARK: - Published Properties
    
    @Published var isDevModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDevModeEnabled, forKey: Keys.devModeEnabled)
            if isDevModeEnabled {

            } else {
                isPremiumOverrideEnabled = false
            }
        }
    }
    
    @Published var isPremiumOverrideEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPremiumOverrideEnabled, forKey: Keys.premiumOverride)
            NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
        }
    }
    
    @Published var overriddenPremiumValue: Bool {
        didSet {
            UserDefaults.standard.set(overriddenPremiumValue, forKey: Keys.premiumValue)
            if isPremiumOverrideEnabled {
                NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
            }
        }
    }
    
    // MARK: - Keys
    
    private enum Keys {
        static let devModeEnabled = "dev.modeEnabled"
        static let premiumOverride = "dev.premiumOverride"
        static let premiumValue = "dev.premiumValue"
    }
    
    // MARK: - Computed Properties
    
    /// Returns the effective premium status considering dev mode override
    /// Use this throughout the app instead of directly checking SDK
    var effectivePremiumStatus: Bool? {
        guard isDevModeEnabled && isPremiumOverrideEnabled else {
            return nil // Let SDK handle it
        }
        return overriddenPremiumValue
    }
    
    /// The current user ID from AuthenticationManager
    var userId: String {
        AuthenticationManager.shared.userId ?? "Unknown"
    }
    
    // MARK: - Initialization
    
    private init() {
        self.isDevModeEnabled = UserDefaults.standard.bool(forKey: Keys.devModeEnabled)
        self.isPremiumOverrideEnabled = UserDefaults.standard.bool(forKey: Keys.premiumOverride)
        self.overriddenPremiumValue = UserDefaults.standard.bool(forKey: Keys.premiumValue)
    }
    
    // MARK: - Actions
    
    /// Deletes all user data and resets the app to initial state
    /// Returns true if successful
    func deleteAllUserData() async -> Bool {
        AppLogger.forClass("DeveloperModeManager").info("Starting complete data deletion...")
        clearUserDefaults()
        AppLogger.forClass("DeveloperModeManager").info("UserDefaults cleared")
        
        AuthenticationManager.shared.clearCredentials()
        AuthenticationManager.shared.regenerateUserId()
        if AuthenticationManager.shared.userId != nil {

        }
        AppLogger.forClass("DeveloperModeManager").info("Credentials cleared and new user ID generated: \(AuthenticationManager.shared.userId ?? "nil")")
        
        UserSettings.shared.resetToDefaults()
        AppLogger.forClass("DeveloperModeManager").info("UserSettings reset to defaults")
        
        UserProfileRepository.shared.resetToDefaults()
        AppLogger.forClass("DeveloperModeManager").info("UserProfileRepository reset")
        
        try? ImageStorage.shared.deleteAllImages()
        AppLogger.forClass("DeveloperModeManager").info("Images deleted")
        
        isDevModeEnabled = false
        isPremiumOverrideEnabled = false
        overriddenPremiumValue = false
        AppLogger.forClass("DeveloperModeManager").info("Dev mode settings reset")
        
        await MainActor.run {
            NotificationCenter.default.post(name: .userDataDeleted, object: nil)
        }
        
        AppLogger.forClass("DeveloperModeManager").success("All user data deleted successfully. New user ID: \(AuthenticationManager.shared.userId ?? "nil")")
        return true
    }
    
    /// Clears relevant UserDefaults keys
    private func clearUserDefaults() {
        let defaults = UserDefaults.standard
        
        // Keys to preserve (system-level settings)
        let keysToPreserve = [
            "AppleLanguages",
            "AppleLocale"
        ]
        
        // Get all keys
        let allKeys = defaults.dictionaryRepresentation().keys
        
        // Remove all except preserved
        for key in allKeys {
            if !keysToPreserve.contains(key) {
                defaults.removeObject(forKey: key)
            }
        }
        
        defaults.synchronize()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when user data is deleted and app should reset to login
    static let userDataDeleted = Notification.Name("userDataDeleted")
}
