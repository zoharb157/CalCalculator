//
//  HomeViewModelTests.swift
//  CalCalculatorTests
//
//  Unit tests for HomeViewModel
//

import XCTest
@testable import playground
import SwiftData

@MainActor
final class HomeViewModelTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    var repository: MealRepository!
    var viewModel: HomeViewModel!
    
    override func setUpWithError() throws {
        let schema = Schema([Meal.self, MealItem.self, DaySummary.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        repository = MealRepository(context: context)
        viewModel = HomeViewModel(repository: repository, imageStorage: .shared)
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
        repository = nil
        viewModel = nil
    }
    
    func testInitialState() {
        // Then
        XCTAssertTrue(viewModel.recentMeals.isEmpty)
        XCTAssertNil(viewModel.todaysSummary)
        XCTAssertTrue(viewModel.weekDays.isEmpty)
        XCTAssertEqual(viewModel.todaysBurnedCalories, 0)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testSelectDay() {
        // Given
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        
        // When
        viewModel.selectDay(tomorrow)
        
        // Then
        XCTAssertEqual(viewModel.selectedDate, tomorrow)
    }
    
    func testCalorieProgress() {
        // Given
        let summary = DaySummary(
            date: Date(),
            totalCalories: 1500,
            totalProteinG: 100,
            totalCarbsG: 150,
            totalFatG: 50,
            mealCount: 2
        )
        viewModel.todaysSummary = summary
        
        // When
        let progress = viewModel.calorieProgress
        
        // Then
        // Assuming default goal is 2000, progress should be 0.75
        XCTAssertGreaterThan(progress, 0)
        XCTAssertLessThanOrEqual(progress, 1.0)
    }
    
    func testRemainingCalories() {
        // Given
        let summary = DaySummary(
            date: Date(),
            totalCalories: 1500,
            totalProteinG: 100,
            totalCarbsG: 150,
            totalFatG: 50,
            mealCount: 2
        )
        viewModel.todaysSummary = summary
        
        // When
        let remaining = viewModel.remainingCalories
        
        // Then
        // Assuming default goal is 2000, remaining should be 500
        XCTAssertGreaterThanOrEqual(remaining, 0)
    }
    
    func testEffectiveCalorieGoal() {
        // Given
        let baseGoal = 2000
        UserSettings.shared.calorieGoal = baseGoal
        
        // When
        let effectiveGoal = viewModel.effectiveCalorieGoal
        
        // Then
        XCTAssertGreaterThanOrEqual(effectiveGoal, baseGoal)
    }
}

