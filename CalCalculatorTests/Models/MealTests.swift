//
//  MealTests.swift
//  CalCalculatorTests
//
//  Unit tests for Meal model
//

import XCTest
@testable import playground
import Foundation

final class MealTests: XCTestCase {
    
    func testMealInitialization() {
        // Given
        let mealName = "Test Meal"
        let timestamp = Date()
        let confidence = 0.95
        
        // When
        let meal = Meal(
            name: mealName,
            timestamp: timestamp,
            confidence: confidence,
            category: .breakfast
        )
        
        // Then
        XCTAssertEqual(meal.name, mealName)
        XCTAssertEqual(meal.timestamp, timestamp)
        XCTAssertEqual(meal.confidence, confidence, accuracy: 0.01)
        XCTAssertEqual(meal.category, .breakfast)
        XCTAssertTrue(meal.items.isEmpty)
    }
    
    func testMealTotalCalories() {
        // Given
        let meal = Meal(name: "Test Meal", timestamp: Date())
        let item1 = MealItem(
            name: "Item 1",
            portion: 100,
            unit: "g",
            calories: 100,
            proteinG: 0,
            carbsG: 0,
            fatG: 0
        )
        let item2 = MealItem(
            name: "Item 2",
            portion: 100,
            unit: "g",
            calories: 200,
            proteinG: 0,
            carbsG: 0,
            fatG: 0
        )
        
        // When
        meal.items.append(item1)
        meal.items.append(item2)
        
        // Then
        XCTAssertEqual(meal.totalCalories, 300)
    }
    
    func testMealTotalMacros() {
        // Given
        let meal = Meal(name: "Test Meal", timestamp: Date())
        let item1 = MealItem(
            name: "Item 1",
            portion: 100,
            unit: "g",
            calories: 100,
            proteinG: 10,
            carbsG: 20,
            fatG: 5
        )
        let item2 = MealItem(
            name: "Item 2",
            portion: 100,
            unit: "g",
            calories: 200,
            proteinG: 15,
            carbsG: 25,
            fatG: 10
        )
        
        // When
        meal.items.append(item1)
        meal.items.append(item2)
        
        // Then
        let macros = meal.totalMacros
        XCTAssertEqual(macros.proteinG, 25, accuracy: 0.01)
        XCTAssertEqual(macros.carbsG, 45, accuracy: 0.01)
        XCTAssertEqual(macros.fatG, 15, accuracy: 0.01)
        XCTAssertEqual(macros.calories, 300)
    }
    
    func testMealCategoryInference() {
        // Given & When
        let breakfastMeal = Meal(
            name: "Breakfast",
            timestamp: createDate(hour: 8, minute: 0)
        )
        let lunchMeal = Meal(
            name: "Lunch",
            timestamp: createDate(hour: 13, minute: 0)
        )
        let dinnerMeal = Meal(
            name: "Dinner",
            timestamp: createDate(hour: 19, minute: 0)
        )
        let snackMeal = Meal(
            name: "Snack",
            timestamp: createDate(hour: 22, minute: 0)
        )
        
        // Then
        XCTAssertEqual(breakfastMeal.category, .breakfast)
        XCTAssertEqual(lunchMeal.category, .lunch)
        XCTAssertEqual(dinnerMeal.category, .dinner)
        XCTAssertEqual(snackMeal.category, .snack)
    }
    
    func testMealCategoryDisplayName() {
        // Then
        XCTAssertEqual(MealCategory.breakfast.displayName, "Breakfast")
        XCTAssertEqual(MealCategory.lunch.displayName, "Lunch")
        XCTAssertEqual(MealCategory.dinner.displayName, "Dinner")
        XCTAssertEqual(MealCategory.snack.displayName, "Snack")
    }
    
    func testMealCategoryIcon() {
        // Then
        XCTAssertEqual(MealCategory.breakfast.icon, "sunrise.fill")
        XCTAssertEqual(MealCategory.lunch.icon, "sun.max.fill")
        XCTAssertEqual(MealCategory.dinner.icon, "moon.fill")
        XCTAssertEqual(MealCategory.snack.icon, "leaf.fill")
    }
    
    // MARK: - Helper Methods
    
    private func createDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

