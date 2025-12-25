//
//  MealRepositoryTests.swift
//  CalCalculatorTests
//
//  Unit tests for MealRepository
//

import XCTest
@testable import playground
import SwiftData

final class MealRepositoryTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    var repository: MealRepository!
    
    override func setUpWithError() throws {
        let schema = Schema([Meal.self, MealItem.self, DaySummary.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        repository = MealRepository(context: context)
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
        repository = nil
    }
    
    func testSaveMeal() throws {
        // Given
        let meal = Meal(
            name: "Test Meal",
            timestamp: Date(),
            confidence: 0.95,
            category: .breakfast
        )
        
        // When
        try repository.saveMeal(meal)
        
        // Then
        let fetchedMeals = try repository.fetchMeals()
        XCTAssertEqual(fetchedMeals.count, 1)
        XCTAssertEqual(fetchedMeals.first?.name, "Test Meal")
    }
    
    func testDeleteMeal() throws {
        // Given
        let meal = Meal(name: "Test Meal", timestamp: Date())
        try repository.saveMeal(meal)
        
        // When
        try repository.deleteMeal(meal)
        
        // Then
        let fetchedMeals = try repository.fetchMeals()
        XCTAssertTrue(fetchedMeals.isEmpty)
    }
    
    func testFetchMealsForDate() throws {
        // Given
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let meal1 = Meal(name: "Today Meal", timestamp: today)
        let meal2 = Meal(name: "Yesterday Meal", timestamp: yesterday)
        
        try repository.saveMeal(meal1)
        try repository.saveMeal(meal2)
        
        // When
        let todayMeals = try repository.fetchMeals(for: today)
        
        // Then
        XCTAssertEqual(todayMeals.count, 1)
        XCTAssertEqual(todayMeals.first?.name, "Today Meal")
    }
    
    func testFetchTodaysMeals() throws {
        // Given
        let meal = Meal(name: "Today Meal", timestamp: Date())
        try repository.saveMeal(meal)
        
        // When
        let todaysMeals = try repository.fetchTodaysMeals()
        
        // Then
        XCTAssertEqual(todaysMeals.count, 1)
        XCTAssertEqual(todaysMeals.first?.name, "Today Meal")
    }
    
    func testUpdateDaySummaryOnSave() throws {
        // Given
        let meal = Meal(name: "Test Meal", timestamp: Date())
        let item = MealItem(
            name: "Item",
            portion: 100,
            unit: "g",
            calories: 100,
            proteinG: 10,
            carbsG: 20,
            fatG: 5
        )
        meal.items.append(item)
        
        // When
        try repository.saveMeal(meal)
        
        // Then
        let summaries = try repository.fetchDaySummaries()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.totalCalories, 100)
    }
    
    func testUpdateDaySummaryOnDelete() throws {
        // Given
        let meal = Meal(name: "Test Meal", timestamp: Date())
        let item = MealItem(
            name: "Item",
            portion: 100,
            unit: "g",
            calories: 100,
            proteinG: 10,
            carbsG: 20,
            fatG: 5
        )
        meal.items.append(item)
        try repository.saveMeal(meal)
        
        // When
        try repository.deleteMeal(meal)
        
        // Then
        let summaries = try repository.fetchDaySummaries()
        // Summary might still exist but with zero calories, or be deleted
        if let summary = summaries.first {
            XCTAssertEqual(summary.totalCalories, 0)
        }
    }
    
    func testFetchMealById() throws {
        // Given
        let meal = Meal(name: "Test Meal", timestamp: Date())
        try repository.saveMeal(meal)
        let mealId = meal.id
        
        // When
        let fetchedMeal = try repository.fetchMeal(by: mealId)
        
        // Then
        XCTAssertNotNil(fetchedMeal)
        XCTAssertEqual(fetchedMeal?.name, "Test Meal")
    }
}

