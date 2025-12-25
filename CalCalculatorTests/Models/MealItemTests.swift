//
//  MealItemTests.swift
//  CalCalculatorTests
//
//  Unit tests for MealItem model
//

import XCTest
@testable import playground

final class MealItemTests: XCTestCase {
    
    func testMealItemInitialization() {
        // Given
        let name = "Chicken Breast"
        let portion = 100.0
        let unit = "g"
        let calories = 165
        let protein = 31.0
        let carbs = 0.0
        let fat = 3.6
        
        // When
        let item = MealItem(
            name: name,
            portion: portion,
            unit: unit,
            calories: calories,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat
        )
        
        // Then
        XCTAssertEqual(item.name, name)
        XCTAssertEqual(item.portion, portion, accuracy: 0.01)
        XCTAssertEqual(item.unit, unit)
        XCTAssertEqual(item.calories, calories)
        XCTAssertEqual(item.proteinG, protein, accuracy: 0.01)
        XCTAssertEqual(item.carbsG, carbs, accuracy: 0.01)
        XCTAssertEqual(item.fatG, fat, accuracy: 0.01)
    }
    
    func testMealItemMacros() {
        // Given
        let item = MealItem(
            name: "Chicken",
            portion: 100,
            unit: "g",
            calories: 165,
            proteinG: 31.0,
            carbsG: 0.0,
            fatG: 3.6
        )
        
        // When
        let macros = item.macros
        
        // Then
        XCTAssertEqual(macros.calories, 165)
        XCTAssertEqual(macros.proteinG, 31.0, accuracy: 0.01)
        XCTAssertEqual(macros.carbsG, 0.0, accuracy: 0.01)
        XCTAssertEqual(macros.fatG, 3.6, accuracy: 0.01)
    }
    
    func testMealItemUpdatePortion() {
        // Given
        let item = MealItem(
            name: "Rice",
            portion: 100,
            unit: "g",
            calories: 130,
            proteinG: 2.7,
            carbsG: 28.0,
            fatG: 0.3
        )
        let originalCalories = item.calories
        let originalProtein = item.proteinG
        
        // When
        item.updatePortion(to: 200) // Double the portion
        
        // Then
        // Values should be approximately doubled (allowing for calculation precision)
        XCTAssertGreaterThan(item.calories, originalCalories)
        XCTAssertGreaterThan(item.proteinG, originalProtein)
        XCTAssertEqual(item.portion, 200, accuracy: 0.01)
    }
}

