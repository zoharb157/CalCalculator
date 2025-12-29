//
//  LocalizedText.swift
//  playground
//
//  SwiftUI component for localized text that updates when language changes
//  Uses AppStrings model for centralized string management
//

import SwiftUI
import Combine

/// A Text view that automatically updates when language changes
/// Usage: LocalizedText("Home.title") or LocalizedText(key: "Home.title")
struct LocalizedText: View {
    let key: String
    let comment: String
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    init(_ key: String, comment: String = "") {
        self.key = key
        self.comment = comment
    }
    
    var body: some View {
        Text(localizationManager.localizedString(for: key, comment: comment))
            .id("\(key)-\(localizationManager.currentLanguage)") // Force update on language change
    }
}

/// A Text view that uses LocalizedStringKey (for SwiftUI's built-in localization)
/// This works with Localizable.xcstrings and updates when language changes
struct LocalizedStringKeyText: View {
    let key: LocalizedStringKey
    let comment: String
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    init(_ key: String, comment: String = "") {
        self.key = LocalizedStringKey(key)
        self.comment = comment
    }
    
    var body: some View {
        Text(key)
            .id("\(key)-\(localizationManager.currentLanguage)") // Force update on language change
    }
}

/// View modifier to make any Text view reactive to language changes
struct LocalizedTextModifier: ViewModifier {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    let key: String
    let comment: String
    
    func body(content: Content) -> some View {
        content
            .id("\(key)-\(localizationManager.currentLanguage)")
    }
}

extension View {
    /// Make a Text view reactive to language changes
    func localized(key: String, comment: String = "") -> some View {
        modifier(LocalizedTextModifier(key: key, comment: comment))
    }
}

// MARK: - Helper Extension for Text Localization

extension Text {
    /// Create a Text view with localized string that updates on language change
    init(localized key: String, comment: String = "") {
        let localizationManager = LocalizationManager.shared
        self.init(localizationManager.localizedString(for: key, comment: comment))
    }
}

// MARK: - Helper for Navigation Title

extension View {
    /// Set a localized navigation title that updates on language change
    func localizedNavigationTitle(_ key: String, comment: String = "") -> some View {
        let localizationManager = LocalizationManager.shared
        return self.navigationTitle(localizationManager.localizedString(for: key, comment: comment))
            .id("nav-title-\(key)-\(localizationManager.currentLanguage)")
    }
}

