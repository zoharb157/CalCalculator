//
//  SettingsViewModelTests.swift
//  CalCalculatorTests
//
//  Unit tests for SettingsViewModel
//

import XCTest
@testable import playground
import SwiftData

@MainActor
final class SettingsViewModelTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    var repository: MealRepository!
    var viewModel: SettingsViewModel!
    
    override func setUpWithError() throws {
        let schema = Schema([Meal.self, MealItem.self, DaySummary.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        repository = MealRepository(context: context)
        viewModel = SettingsViewModel(repository: repository, imageStorage: .shared)
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
        repository = nil
        viewModel = nil
    }
    
    func testInitialState() {
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.showError)
    }
    
    func testExportData() async throws {
        // Given
        let meal = Meal(name: "Test Meal", timestamp: Date())
        try repository.saveMeal(meal)
        
        // When
        let data = await viewModel.exportData()
        
        // Then
        XCTAssertNotNil(data)
    }
    
    func testExportDataWithError() async {
        // Given - Create a scenario that might cause export to fail
        // (This is hard to test without mocking, but we can at least verify the error handling path)
        
        // When
        let data = await viewModel.exportData()
        
        // Then - Should handle gracefully
        // Either returns data or nil (both are acceptable)
        XCTAssertTrue(data != nil || viewModel.showError)
    }
    
    func testDeleteAllData() async {
        // Given
        let meal = Meal(name: "Test Meal", timestamp: Date())
        try? repository.saveMeal(meal)
        
        // When
        await viewModel.deleteAllData()
        
        // Then - Should not throw
        // Verify by checking that repository is empty or error is set
        let meals = try? repository.fetchMeals()
        XCTAssertTrue(meals?.isEmpty ?? true || viewModel.showError)
    }
}

