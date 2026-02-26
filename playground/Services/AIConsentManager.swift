//
//  AIConsentManager.swift
//  playground
//
//  Manages user consent for sharing personal data with AI services
//

import Foundation
import UIKit

/// Manages user consent state for AI data processing
/// Required by Apple Guidelines 5.1.1(i) and 5.1.2(i)
@Observable
final class AIConsentManager {
    static let shared = AIConsentManager()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let hasConsentedToAIDataSharing = "hasConsentedToAIDataSharing"
        static let aiConsentDate = "aiConsentDate"
        static let aiConsentVersion = "aiConsentVersion"
    }
    
    /// Current consent policy version. Increment when data practices change
    /// to require re-consent from users.
    static let currentConsentVersion = 1
    
    // MARK: - Properties
    
    /// Whether the user has granted consent to share data with AI services
    var hasConsented: Bool {
        didSet { defaults.set(hasConsented, forKey: Keys.hasConsentedToAIDataSharing) }
    }
    
    /// Date when consent was granted
    var consentDate: Date? {
        didSet { defaults.set(consentDate, forKey: Keys.aiConsentDate) }
    }
    
    /// The consent version the user agreed to
    var consentVersion: Int {
        didSet { defaults.set(consentVersion, forKey: Keys.aiConsentVersion) }
    }
    
    // MARK: - Initialization
    
    private init() {
        self.hasConsented = defaults.bool(forKey: Keys.hasConsentedToAIDataSharing)
        self.consentDate = defaults.object(forKey: Keys.aiConsentDate) as? Date
        self.consentVersion = defaults.integer(forKey: Keys.aiConsentVersion)
        
        // If consent version is outdated, require re-consent
        if hasConsented && consentVersion < Self.currentConsentVersion {
            hasConsented = false
            consentDate = nil
            consentVersion = 0
        }
    }
    
    // MARK: - Actions
    
    /// Grant consent for AI data sharing
    func grantConsent() {
        hasConsented = true
        consentDate = Date()
        consentVersion = Self.currentConsentVersion
        defaults.synchronize()
        Pixel.track("ai_consent_granted", type: .lifecycle)
        HapticManager.shared.notification(.success)
    }
    
    /// Revoke consent for AI data sharing
    func revokeConsent() {
        hasConsented = false
        consentDate = nil
        consentVersion = 0
        defaults.synchronize()
        Pixel.track("ai_consent_revoked", type: .lifecycle)
        HapticManager.shared.notification(.warning)
    }
    
    /// Check if consent is granted, suitable for guard statements in services
    /// - Throws: If consent has not been granted
    func requireConsent() throws {
        guard hasConsented else {
            throw AIConsentError.consentNotGranted
        }
    }
}

// MARK: - AI Consent Error

enum AIConsentError: LocalizedError {
    case consentNotGranted
    
    var errorDescription: String? {
        switch self {
        case .consentNotGranted:
            return "AI data sharing consent is required to use this feature. Please review and accept the data sharing policy."
        }
    }
}
