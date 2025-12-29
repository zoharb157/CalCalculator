//
//  ProfileViewModelLanguageTests.swift
//  CalCalculatorTests
//
//  Unit tests for ProfileViewModel language functionality
//

import XCTest
@testable import playground

@MainActor
final class ProfileViewModelLanguageTests: XCTestCase {
    
    var viewModel: ProfileViewModel!
    var repository: UserProfileRepositoryProtocol!
    
    override func setUp() {
        super.setUp()
        repository = UserProfileRepository.shared
        viewModel = ProfileViewModel(repository: repository)
    }
    
    override func tearDown() {
        viewModel = nil
        repository = nil
        super.tearDown()
    }
    
    // MARK: - Supported Languages Tests
    
    func testSupportedLanguagesNotEmpty() {
        XCTAssertFalse(ProfileViewModel.supportedLanguages.isEmpty)
        XCTAssertGreaterThan(ProfileViewModel.supportedLanguages.count, 0)
    }
    
    func testSupportedLanguagesContainsEnglish() {
        let hasEnglish = ProfileViewModel.supportedLanguages.contains { $0.name == "English" }
        XCTAssertTrue(hasEnglish)
    }
    
    func testSupportedLanguagesContainsArabic() {
        let hasArabic = ProfileViewModel.supportedLanguages.contains { $0.name == "Arabic" }
        XCTAssertTrue(hasArabic)
    }
    
    func testSupportedLanguagesContainsHebrew() {
        let hasHebrew = ProfileViewModel.supportedLanguages.contains { $0.name == "Hebrew" }
        XCTAssertTrue(hasHebrew)
    }
    
    func testSupportedLanguagesHaveValidCodes() {
        for language in ProfileViewModel.supportedLanguages {
            XCTAssertFalse(language.code.isEmpty, "Language \(language.name) should have a code")
            XCTAssertFalse(language.flag.isEmpty, "Language \(language.name) should have a flag")
        }
    }
    
    // MARK: - Language Selection Tests
    
    func testSelectedLanguageChange() {
        let initialLanguage = viewModel.selectedLanguage
        
        // Change language
        viewModel.selectedLanguage = "Spanish"
        XCTAssertEqual(viewModel.selectedLanguage, "Spanish")
        
        // Verify repository was updated
        XCTAssertEqual(repository.getSelectedLanguage(), "Spanish")
        
        // Restore initial language
        viewModel.selectedLanguage = initialLanguage
    }
    
    func testLanguageChangeTriggersLocalizationManager() {
        let initialLanguage = viewModel.selectedLanguage
        
        // Change to Arabic (RTL language)
        viewModel.selectedLanguage = "Arabic"
        
        // Verify LocalizationManager was updated
        let languageCode = LocalizationManager.languageCode(from: "Arabic")
        XCTAssertEqual(LocalizationManager.shared.currentLanguage, languageCode)
        
        // Restore initial language
        viewModel.selectedLanguage = initialLanguage
    }
    
    func testLanguageChangeDoesNotTriggerIfSame() {
        let currentLanguage = viewModel.selectedLanguage
        
        // Setting same language should not cause issues
        viewModel.selectedLanguage = currentLanguage
        XCTAssertEqual(viewModel.selectedLanguage, currentLanguage)
    }
}

