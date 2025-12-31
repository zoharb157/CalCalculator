//
//  LocalizationManager.swift
//  CalCalculator
//
//  Manages app localization and language switching
//

import Foundation
import SwiftUI
import Combine

/// Manager for handling app localization and language switching
/// Supports runtime language switching without app restart
@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: String {
        willSet {
            // Trigger objectWillChange before the value changes
            // This ensures all @ObservedObject views are notified
            objectWillChange.send()
        }
        didSet {
            // Save to UserDefaults (no need for synchronize - auto-syncs)
            UserDefaults.standard.set(currentLanguage, forKey: "app_language")
            
            // Set AppleLanguages for system localization
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            
            // Update the locale bundle
            updateLocaleBundle()
            
            // Send another notification after the change to ensure all views update
            objectWillChange.send()
        }
    }
    
    /// The bundle to use for localization (changes based on selected language)
    private var localeBundle: Bundle = Bundle.main
    
    private init() {
        // Load saved language or default to system language
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language") {
            self.currentLanguage = savedLanguage
        } else {
            // Get system language code (e.g., "en", "es", "fr")
            let systemLanguage = Locale.preferredLanguages.first ?? "en"
            let languageCode = String(systemLanguage.prefix(2))
            self.currentLanguage = languageCode
        }
        
        // Set AppleLanguages on init
        UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
        
        // Initialize locale bundle
        updateLocaleBundle()
    }
    
    /// Update the locale bundle based on current language
    private func updateLocaleBundle() {
        let languageCode = String(currentLanguage.prefix(2)) // Get base language code (e.g., "en" from "en-US")
        
        // CRITICAL: Set AppleLanguages FIRST before any bundle operations
        // This ensures Bundle.main.localizedString (used by Localizable.xcstrings) uses the correct language
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        // Note: synchronize() is deprecated, but UserDefaults auto-syncs
        // For immediate effect, we rely on the notification and view refresh
        
        // Try to find the language bundle (e.g., "en.lproj")
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            localeBundle = bundle
        } else if let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
                  let bundle = Bundle(path: path) {
            localeBundle = bundle
        } else {
            // Fallback to main bundle (for Localizable.xcstrings)
            localeBundle = Bundle.main
        }
        
        // Force Bundle.main to reload language preferences
        // This is critical for Localizable.xcstrings to work
        NotificationCenter.default.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
    }
    
    /// Get the current language code
    var languageCode: String {
        currentLanguage
    }
    
    /// Get the current locale
    var currentLocale: Locale {
        Locale(identifier: currentLanguage)
    }
    
    /// Check if current language is RTL (Right-to-Left)
    var isRTL: Bool {
        let rtlLanguages = ["ar", "fa", "ur"] // Arabic, Persian, Urdu
        return rtlLanguages.contains(currentLanguage)
    }
    
    /// Get layout direction for current language
    var layoutDirection: LayoutDirection {
        isRTL ? .rightToLeft : .leftToRight
    }
    
    /// Set the app language (runtime switching)
    func setLanguage(_ languageCode: String) {
        guard currentLanguage != languageCode else { return }
        
        print("🌐 [LocalizationManager] Setting language to: \(languageCode) (current: \(currentLanguage))")
        
        // Set AppleLanguages FIRST before changing currentLanguage
        // This ensures Bundle operations use the correct language
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize() // Force immediate sync
        
        // CRITICAL: Send objectWillChange BEFORE changing the value
        // This ensures all @ObservedObject views are notified
        objectWillChange.send()
        
        // Update current language - this will trigger willSet and didSet
        // which will send objectWillChange automatically via @Published
        currentLanguage = languageCode
        
        // CRITICAL: Send objectWillChange AGAIN after the change
        // This ensures all views get notified and re-evaluate
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
        
        // Force bundle update (already called in didSet, but ensure it's done)
        updateLocaleBundle()
        
        print("🌐 [LocalizationManager] Language set to: \(languageCode)")
        
        // Post notification for any views that need to do additional work
        NotificationCenter.default.post(name: .languageChanged, object: languageCode)
        
        // Verify AppleLanguages is set correctly
        if let savedLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           savedLanguages.first == languageCode {
            print("✅ [LocalizationManager] AppleLanguages verified: \(savedLanguages)")
        } else {
            print("⚠️ [LocalizationManager] AppleLanguages not set correctly!")
        }
    }
    
    /// Get localized string from the appropriate language bundle
    /// This works with both .lproj bundles and Localizable.xcstrings
    /// Priority: Language bundle > localeBundle > Bundle.main > key itself
    /// 
    /// IMPORTANT: Bundle.main.localizedString does NOT respect AppleLanguages at runtime.
    /// It only reads AppleLanguages when the app launches. For runtime language switching,
    /// we must use language-specific bundles (.lproj folders).
    /// 
    /// NOTE: This function reads `currentLanguage` which is @Published, so SwiftUI will
    /// automatically re-evaluate any view that calls this when currentLanguage changes.
    /// CRITICAL: To ensure SwiftUI tracks the dependency, we must access currentLanguage
    /// in a way that creates a visible dependency in the view's body.
    func localizedString(for key: String, comment: String = "") -> String {
        // CRITICAL: Access currentLanguage directly to create a dependency SwiftUI can track
        // This ensures views re-evaluate when language changes
        // We access it explicitly to ensure the dependency is tracked
        let _ = currentLanguage // Force dependency tracking by reading the @Published property
        let languageCode = String(currentLanguage.prefix(2))
        
        // CRITICAL: Set AppleLanguages for next app launch (doesn't affect runtime)
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // For runtime switching, we MUST use the language-specific bundle
        // Try to find the language-specific bundle (.lproj folders)
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            // Try with "Localizable" table first (this is the standard table name)
            let localized = languageBundle.localizedString(forKey: key, value: key, table: "Localizable")
            // Check if we got a translation (not the key itself and not empty)
            if localized != key && !localized.isEmpty {
                return localized
            }
            // Try without table name (fallback)
            let localizedNoTable = languageBundle.localizedString(forKey: key, value: key, table: nil)
            if localizedNoTable != key && !localizedNoTable.isEmpty {
                return localizedNoTable
            }
        }
        
        // Try the locale bundle (cached from updateLocaleBundle)
        // This should already be set to the correct language bundle
        let localeBundleLocalized = localeBundle.localizedString(forKey: key, value: key, table: "Localizable")
        if localeBundleLocalized != key && !localeBundleLocalized.isEmpty {
            return localeBundleLocalized
        }
        
        // Try locale bundle without table name
        let localeBundleNoTable = localeBundle.localizedString(forKey: key, value: key, table: nil)
        if localeBundleNoTable != key && !localeBundleNoTable.isEmpty {
            return localeBundleNoTable
        }
        
        // Try Bundle.main as fallback (only works if app was launched with that language)
        // This is for Localizable.xcstrings support, but won't work for runtime switching
        let mainBundleLocalized = Bundle.main.localizedString(forKey: key, value: key, table: nil)
        if mainBundleLocalized != key && mainBundleLocalized != "" {
            return mainBundleLocalized
        }
        
        // Final fallback: return the key itself if no translation found
        // This allows the app to still function even if translations are missing
        return key
    }
    
    /// Get localized string with arguments
    func localizedString(for key: String, arguments: CVarArg..., comment: String = "") -> String {
        let format = localizedString(for: key, comment: comment)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - Language Code Mapping

extension LocalizationManager {
    /// Map language name to language code
    static func languageCode(from name: String) -> String {
        let mapping: [String: String] = [
            "English": "en",
            "Spanish": "es",
            "French": "fr",
            "German": "de",
            "Italian": "it",
            "Portuguese": "pt",
            "Chinese": "zh",
            "Japanese": "ja",
            "Korean": "ko",
            "Russian": "ru",
            "Arabic": "ar",
            "Hindi": "hi"
        ]
        return mapping[name] ?? "en"
    }
    
    /// Map language code to language name
    static func languageName(from code: String) -> String {
        let mapping: [String: String] = [
            "en": "English",
            "es": "Spanish",
            "fr": "French",
            "de": "German",
            "it": "Italian",
            "pt": "Portuguese",
            "zh": "Chinese",
            "ja": "Japanese",
            "ko": "Korean",
            "ru": "Russian",
            "ar": "Arabic",
            "hi": "Hindi"
        ]
        return mapping[code] ?? "English"
    }
    
    /// Check if a language code is RTL
    static func isRTL(languageCode: String) -> Bool {
        let rtlLanguages = ["ar", "fa", "ur"] // Arabic, Persian, Urdu
        return rtlLanguages.contains(languageCode)
    }
}

// MARK: - SwiftUI Environment Support

private struct LocalizationKey: EnvironmentKey {
    static let defaultValue = LocalizationManager.shared
}

extension EnvironmentValues {
    var localization: LocalizationManager {
        get { self[LocalizationKey.self] }
        set { self[LocalizationKey.self] = newValue }
    }
}

// MARK: - String Extension for Easy Localization

extension String {
    /// Get localized string using LocalizationManager
    var localized: String {
        LocalizationManager.shared.localizedString(for: self)
    }
    
    /// Get localized string with comment
    func localized(comment: String = "") -> String {
        LocalizationManager.shared.localizedString(for: self, comment: comment)
    }
    
    /// Get localized string with format arguments
    func localized(_ arguments: CVarArg..., comment: String = "") -> String {
        let format = LocalizationManager.shared.localizedString(for: self, comment: comment)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - SwiftUI LocalizedStringKey Helper

extension LocalizedStringKey {
    /// Create a LocalizedStringKey from a string that will be localized
    init(_ key: String, comment: String = "") {
        self.init(key, comment: comment)
    }
}

// MARK: - Notification Names
// Note: languageChanged notification is defined in playgroundApp.swift
