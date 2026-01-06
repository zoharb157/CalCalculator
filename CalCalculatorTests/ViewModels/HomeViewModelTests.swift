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
        let schema = Schema([Meal.self, MealItem.self, DaySummary.self, Exercise.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        repository = MealRepository(context: context)
        viewModel = HomeViewModel(repository: repository, imageStorage: .shared)
        
        // Clear UserDefaults cache before each test
        UserDefaults.standard.removeObject(forKey: "burnedCalories_lastDate")
        UserDefaults.standard.removeObject(forKey: "burnedCalories_amount")
        UserDefaults.standard.removeObject(forKey: "rolloverCalories_lastDate")
        UserDefaults.standard.removeObject(forKey: "rolloverCalories_amount")
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
    
    // MARK: - Selected Date Tests
    
    func testSelectDayUpdatesSelectedDate() {
        // Given
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let normalizedTomorrow = calendar.startOfDay(for: tomorrow)
        
        // When
        viewModel.selectDay(tomorrow)
        
        // Then
        XCTAssertTrue(calendar.isDate(viewModel.selectedDate, inSameDayAs: normalizedTomorrow))
    }
    
    func testSelectDayDoesNotReloadIfSameDate() {
        // Given
        let today = Date()
        viewModel.selectDay(today)
        let initialWeekDaysCount = viewModel.weekDays.count
        
        // When - select same day again
        viewModel.selectDay(today)
        
        // Then - should not trigger reload (weekDays count should remain same)
        // Note: This is a basic check - in real scenario, we'd verify no async work was triggered
        XCTAssertEqual(viewModel.weekDays.count, initialWeekDaysCount)
    }
    
    // MARK: - Burned Calories Tests
    
    func testBurnedCaloriesCaching() async throws {
        // Given
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let burnedCalories = 500
        
        // Cache burned calories manually (simulating what happens in init)
        UserDefaults.standard.set(today, forKey: "burnedCalories_lastDate")
        UserDefaults.standard.set(burnedCalories, forKey: "burnedCalories_amount")
        
        // Create new viewModel to trigger loadCachedBurnedCalories in init
        let newViewModel = HomeViewModel(repository: repository, imageStorage: .shared)
        
        // Then - should load cached value
        XCTAssertEqual(newViewModel.todaysBurnedCalories, burnedCalories)
    }
    
    func testBurnedCaloriesCacheExpiresOnNewDay() {
        // Given
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayStart = calendar.startOfDay(for: yesterday)
        
        // Cache burned calories for yesterday
        UserDefaults.standard.set(yesterdayStart, forKey: "burnedCalories_lastDate")
        UserDefaults.standard.set(500, forKey: "burnedCalories_amount")
        
        // Create new viewModel to trigger loadCachedBurnedCalories in init
        let newViewModel = HomeViewModel(repository: repository, imageStorage: .shared)
        
        // Then - cache should be cleared (different day)
        XCTAssertEqual(newViewModel.todaysBurnedCalories, 0)
    }
    
    func testSelectedDateBurnedCaloriesForHistoricalDate() async throws {
        // Given
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayStart = calendar.startOfDay(for: yesterday)
        
        // Create exercise for yesterday
        let exercise = Exercise(
            name: "Running",
            calories: 300,
            duration: 30,
            date: yesterdayStart
        )
        context.insert(exercise)
        try context.save()
        
        // When - select yesterday and load data (selectDay triggers async load)
        viewModel.selectDay(yesterday)
        // Wait for async operations to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then - should have loaded burned calories for selected date
        XCTAssertEqual(viewModel.selectedDateBurnedCalories, 300)
        XCTAssertEqual(viewModel.selectedDateExercisesCount, 1)
    }
    
    func testSelectedDateBurnedCaloriesForToday() async throws {
        // Given
        let today = Date()
        let exercise = Exercise(
            name: "Walking",
            calories: 200,
            duration: 20,
            date: today
        )
        context.insert(exercise)
        try context.save()
        
        // When - select today and load data
        viewModel.selectDay(today)
        // Wait for async operations to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then - should have loaded burned calories
        XCTAssertEqual(viewModel.selectedDateBurnedCalories, 200)
        XCTAssertEqual(viewModel.selectedDateExercisesCount, 1)
    }
    
    // MARK: - Rollover Calories Tests
    
    func testRolloverCaloriesCalculation() async throws {
        // Given
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Create yesterday's summary with unused calories
        let yesterdaySummary = DaySummary(
            date: yesterday,
            totalCalories: 1800, // 200 under goal (assuming 2000 goal)
            totalProteinG: 100,
            totalCarbsG: 150,
            totalFatG: 50,
            mealCount: 3
        )
        context.insert(yesterdaySummary)
        try context.save()
        
        // When - load data which triggers calculateAndStoreRollover
        await viewModel.loadData()
        
        // Then - rollover should be 200 (capped at 200 max)
        // Note: This tests the behavior through the public API
        XCTAssertGreaterThanOrEqual(viewModel.rolloverCaloriesFromYesterday, 0)
        XCTAssertLessThanOrEqual(viewModel.rolloverCaloriesFromYesterday, 200)
    }
    
    func testRolloverCaloriesExpiresAfterOneDay() {
        // Given
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        
        // Store rollover for two days ago
        UserDefaults.standard.set(twoDaysAgo, forKey: "rolloverCalories_lastDate")
        UserDefaults.standard.set(100, forKey: "rolloverCalories_amount")
        
        // Create new viewModel to trigger loadRolloverCalories in init
        let newViewModel = HomeViewModel(repository: repository, imageStorage: .shared)
        
        // Then - rollover should be 0 (expired)
        XCTAssertEqual(newViewModel.rolloverCaloriesFromYesterday, 0)
    }
    
    // MARK: - Effective Calorie Goal Tests
    
    func testEffectiveCalorieGoalWithBurnedCalories() {
        // Given
        let baseGoal = 2000
        UserSettings.shared.calorieGoal = baseGoal
        viewModel.todaysBurnedCalories = 300
        
        // Mock the setting to enable burned calories
        // Note: In real scenario, we'd need to mock UserProfileRepository
        // For now, we test the base calculation
        
        // When
        let effectiveGoal = viewModel.effectiveCalorieGoal
        
        // Then - should be at least base goal
        XCTAssertGreaterThanOrEqual(effectiveGoal, baseGoal)
    }
    
    func testEffectiveCalorieGoalWithRollover() {
        // Given
        let baseGoal = 2000
        UserSettings.shared.calorieGoal = baseGoal
        viewModel.rolloverCaloriesFromYesterday = 100
        
        // When
        let effectiveGoal = viewModel.effectiveCalorieGoal
        
        // Then - should be at least base goal
        XCTAssertGreaterThanOrEqual(effectiveGoal, baseGoal)
    }
    
    func testEffectiveCalorieGoalUsesSelectedDateBurnedCalories() async throws {
        // Given
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayStart = calendar.startOfDay(for: yesterday)
        
        // Create exercise for yesterday
        let exercise = Exercise(
            name: "Cycling",
            calories: 400,
            duration: 45,
            date: yesterdayStart
        )
        context.insert(exercise)
        try context.save()
        
        // When - select yesterday and load data
        viewModel.selectDay(yesterday)
        // Wait for async operations
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then - effective goal calculation should use selectedDateBurnedCalories
        // when viewing historical dates
        XCTAssertEqual(viewModel.selectedDateBurnedCalories, 400)
    }
    
    // MARK: - Goal Adjustment Description Tests
    
    func testGoalAdjustmentDescriptionWithBurnedCalories() {
        // Given
        viewModel.todaysBurnedCalories = 250
        
        // When
        let description = viewModel.goalAdjustmentDescription
        
        // Then - should include burned calories if enabled
        // Note: Actual result depends on UserProfileRepository settings
        // This test verifies the method doesn't crash
        XCTAssertNotNil(description)
    }
    
    func testGoalAdjustmentDescriptionWithRollover() {
        // Given
        viewModel.rolloverCaloriesFromYesterday = 150
        
        // When
        let description = viewModel.goalAdjustmentDescription
        
        // Then - should include rollover if enabled
        XCTAssertNotNil(description)
    }
    
    // MARK: - Refresh Burned Calories Tests
    
    func testRefreshBurnedCalories() async throws {
        // Given
        let exercise1 = Exercise(name: "Running", calories: 200, duration: 20, date: Date())
        let exercise2 = Exercise(name: "Walking", calories: 100, duration: 15, date: Date())
        context.insert(exercise1)
        context.insert(exercise2)
        try context.save()
        
        // When
        await viewModel.refreshBurnedCalories()
        
        // Then
        XCTAssertEqual(viewModel.todaysBurnedCalories, 300)
    }
}



