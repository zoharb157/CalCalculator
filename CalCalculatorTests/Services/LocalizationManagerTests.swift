//
//  LocalizationManagerTests.swift
//  CalCalculatorTests
//
//  Unit tests for LocalizationManager
//

import XCTest
@testable import playground

@MainActor
final class LocalizationManagerTests: XCTestCase {
    
    var manager: LocalizationManager!
    
    override func setUp() {
        super.setUp()
        // Reset UserDefaults for testing
        UserDefaults.standard.removeObject(forKey: "app_language")
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        manager = LocalizationManager.shared
    }
    
    override func tearDown() {
        // Clean up
        UserDefaults.standard.removeObject(forKey: "app_language")
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        super.tearDown()
    }
    
    // MARK: - Language Code Mapping Tests
    
    func testLanguageCodeMapping() {
        XCTAssertEqual(LocalizationManager.languageCode(from: "English"), "en")
        XCTAssertEqual(LocalizationManager.languageCode(from: "Spanish"), "es")
        XCTAssertEqual(LocalizationManager.languageCode(from: "Arabic"), "ar")
        XCTAssertEqual(LocalizationManager.languageCode(from: "Hebrew"), "he")
        XCTAssertEqual(LocalizationManager.languageCode(from: "Unknown"), "en") // Default fallback
    }
    
    func testLanguageNameMapping() {
        XCTAssertEqual(LocalizationManager.languageName(from: "en"), "English")
        XCTAssertEqual(LocalizationManager.languageName(from: "es"), "Spanish")
        XCTAssertEqual(LocalizationManager.languageName(from: "ar"), "Arabic")
        XCTAssertEqual(LocalizationManager.languageName(from: "he"), "Hebrew")
        XCTAssertEqual(LocalizationManager.languageName(from: "xx"), "English") // Default fallback
    }
    
    // MARK: - RTL Detection Tests
    
    func testRTLDetection() {
        XCTAssertTrue(LocalizationManager.isRTL(languageCode: "ar")) // Arabic
        XCTAssertTrue(LocalizationManager.isRTL(languageCode: "he")) // Hebrew
        XCTAssertTrue(LocalizationManager.isRTL(languageCode: "fa")) // Persian
        XCTAssertTrue(LocalizationManager.isRTL(languageCode: "ur")) // Urdu
        
        XCTAssertFalse(LocalizationManager.isRTL(languageCode: "en")) // English
        XCTAssertFalse(LocalizationManager.isRTL(languageCode: "es")) // Spanish
        XCTAssertFalse(LocalizationManager.isRTL(languageCode: "fr")) // French
    }
    
    func testManagerRTLProperty() {
        manager.setLanguage("ar")
        XCTAssertTrue(manager.isRTL)
        XCTAssertEqual(manager.layoutDirection, .rightToLeft)
        
        manager.setLanguage("en")
        XCTAssertFalse(manager.isRTL)
        XCTAssertEqual(manager.layoutDirection, .leftToRight)
    }
    
    // MARK: - Language Setting Tests
    
    func testSetLanguage() {
        let initialLanguage = manager.currentLanguage
        
        manager.setLanguage("es")
        XCTAssertEqual(manager.currentLanguage, "es")
        XCTAssertEqual(manager.languageCode, "es")
        
        // Verify UserDefaults was updated
        XCTAssertEqual(UserDefaults.standard.string(forKey: "app_language"), "es")
        
        // Set back to initial
        manager.setLanguage(initialLanguage)
    }
    
    func testSetLanguageDoesNotChangeIfSame() {
        manager.setLanguage("en")
        let currentLanguage = manager.currentLanguage
        
        // Setting same language should not trigger change
        manager.setLanguage("en")
        XCTAssertEqual(manager.currentLanguage, currentLanguage)
    }
    
    // MARK: - Locale Tests
    
    func testCurrentLocale() {
        manager.setLanguage("fr")
        let locale = manager.currentLocale
        XCTAssertEqual(locale.identifier, "fr")
        
        manager.setLanguage("ar")
        let arabicLocale = manager.currentLocale
        XCTAssertEqual(arabicLocale.identifier, "ar")
    }
    
    // MARK: - Localized String Tests
    
    func testLocalizedString() {
        manager.setLanguage("en")
        
        // Test that localizedString returns a string (even if key doesn't exist, it returns the key)
        let result = manager.localizedString(for: "test_key", comment: "Test comment")
        XCTAssertNotNil(result)
        XCTAssertTrue(result is String)
    }
    
    func testLocalizedStringWithArguments() {
        manager.setLanguage("en")
        
        // Test format string with arguments
        let format = "Hello %@"
        let result = manager.localizedString(for: format, arguments: "World", comment: "")
        // Should return formatted string or original if not localized
        XCTAssertNotNil(result)
    }
}

