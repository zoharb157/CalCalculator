//
//  MealRepositoryEdgeCasesTests.swift
//  CalCalculatorTests
//
//  Edge case tests for MealRepository
//

import XCTest
@testable import playground
import SwiftData

final class MealRepositoryEdgeCasesTests: XCTestCase {
    
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
    
    func testSaveMealWithEmptyItems() throws {
        // Given
        let meal = Meal(name: "Empty Meal", timestamp: Date())
        
        // When
        try repository.saveMeal(meal)
        
        // Then
        let fetchedMeals = try repository.fetchMeals()
        XCTAssertEqual(fetchedMeals.count, 1)
        XCTAssertTrue(fetchedMeals.first?.items.isEmpty ?? false)
    }
    
    func testSaveMealWithManyItems() throws {
        // Given
        let meal = Meal(name: "Large Meal", timestamp: Date())
        for i in 1...100 {
            let item = MealItem(
                name: "Item \(i)",
                portion: 100,
                unit: "g",
                calories: 100,
                proteinG: 10,
                carbsG: 20,
                fatG: 5
            )
            meal.items.append(item)
        }
        
        // When
        try repository.saveMeal(meal)
        
        // Then
        let fetchedMeal = try repository.fetchMeal(by: meal.id)
        XCTAssertNotNil(fetchedMeal)
        XCTAssertEqual(fetchedMeal?.items.count, 100)
    }
    
    func testFetchMealsForFutureDate() throws {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        
        // When
        let meals = try repository.fetchMeals(for: futureDate)
        
        // Then
        XCTAssertTrue(meals.isEmpty)
    }
    
    func testFetchMealsForPastDate() throws {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let meal = Meal(name: "Past Meal", timestamp: pastDate)
        try repository.saveMeal(meal)
        
        // When
        let meals = try repository.fetchMeals(for: pastDate)
        
        // Then
        XCTAssertEqual(meals.count, 1)
        XCTAssertEqual(meals.first?.name, "Past Meal")
    }
    
    func testDeleteNonExistentMeal() throws {
        // Given
        let meal = Meal(name: "Non-existent", timestamp: Date())
        
        // When & Then - Should not throw
        try? repository.deleteMeal(meal)
    }
    
    func testFetchMealByNonExistentId() throws {
        // Given
        let nonExistentId = UUID()
        
        // When
        let meal = try repository.fetchMeal(by: nonExistentId)
        
        // Then
        XCTAssertNil(meal)
    }
    
    func testSaveMealWithZeroCalories() throws {
        // Given
        let meal = Meal(name: "Zero Calorie Meal", timestamp: Date())
        let item = MealItem(
            name: "Water",
            portion: 100,
            unit: "ml",
            calories: 0,
            proteinG: 0,
            carbsG: 0,
            fatG: 0
        )
        meal.items.append(item)
        
        // When
        try repository.saveMeal(meal)
        
        // Then
        let fetchedMeal = try repository.fetchMeal(by: meal.id)
        XCTAssertNotNil(fetchedMeal)
        XCTAssertEqual(fetchedMeal?.totalCalories, 0)
    }
    
    func testSaveMealWithVeryHighCalories() throws {
        // Given
        let meal = Meal(name: "High Calorie Meal", timestamp: Date())
        let item = MealItem(
            name: "High Cal Item",
            portion: 1000,
            unit: "g",
            calories: 5000,
            proteinG: 200,
            carbsG: 400,
            fatG: 150
        )
        meal.items.append(item)
        
        // When
        try repository.saveMeal(meal)
        
        // Then
        let fetchedMeal = try repository.fetchMeal(by: meal.id)
        XCTAssertNotNil(fetchedMeal)
        XCTAssertEqual(fetchedMeal?.totalCalories, 5000)
    }
}

