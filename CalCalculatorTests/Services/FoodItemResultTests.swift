//
//  FoodItemResultTests.swift
//  CalCalculatorTests
//
//  Unit tests for FoodItemResult
//

import XCTest
@testable import playground

final class FoodItemResultTests: XCTestCase {
    
    func testFoodItemResultToMealItem() {
        // Given
        let foodItem = FoodItemResult(
            name: "Chicken Breast",
            calories: 165,
            portion: "100 g",
            proteinG: 31.0,
            carbsG: 0.0,
            fatG: 3.6
        )
        
        // When
        let mealItem = foodItem.toMealItem()
        
        // Then
        XCTAssertEqual(mealItem.name, "Chicken Breast")
        XCTAssertEqual(mealItem.calories, 165)
        XCTAssertEqual(mealItem.proteinG, 31.0, accuracy: 0.01)
        XCTAssertEqual(mealItem.carbsG, 0.0, accuracy: 0.01)
        XCTAssertEqual(mealItem.fatG, 3.6, accuracy: 0.01)
    }
    
    func testFoodItemResultPortionParsing() {
        // Given
        let foodItem1 = FoodItemResult(
            name: "Rice",
            calories: 130,
            portion: "100 g",
            proteinG: 2.7,
            carbsG: 28.0,
            fatG: 0.3
        )
        
        let foodItem2 = FoodItemResult(
            name: "Milk",
            calories: 150,
            portion: "1 cup",
            proteinG: 8.0,
            carbsG: 12.0,
            fatG: 8.0
        )
        
        let foodItem3 = FoodItemResult(
            name: "Butter",
            calories: 100,
            portion: "1/2 tbsp",
            proteinG: 0.1,
            carbsG: 0.0,
            fatG: 11.0
        )
        
        // When
        let mealItem1 = foodItem1.toMealItem()
        let mealItem2 = foodItem2.toMealItem()
        let mealItem3 = foodItem3.toMealItem()
        
        // Then
        XCTAssertEqual(mealItem1.portion, 100.0, accuracy: 0.01)
        XCTAssertEqual(mealItem1.unit, "g")
        
        XCTAssertEqual(mealItem2.portion, 1.0, accuracy: 0.01)
        XCTAssertEqual(mealItem2.unit, "cup")
        
        XCTAssertEqual(mealItem3.portion, 0.5, accuracy: 0.01)
        XCTAssertEqual(mealItem3.unit, "tbsp")
    }
    
    func testFoodItemResultPortionParsingEdgeCases() {
        // Given
        let foodItem1 = FoodItemResult(
            name: "Item 1",
            calories: 100,
            portion: "no number",
            proteinG: 10,
            carbsG: 20,
            fatG: 5
        )
        
        let foodItem2 = FoodItemResult(
            name: "Item 2",
            calories: 100,
            portion: "2/3 serving",
            proteinG: 10,
            carbsG: 20,
            fatG: 5
        )
        
        // When
        let mealItem1 = foodItem1.toMealItem()
        let mealItem2 = foodItem2.toMealItem()
        
        // Then
        // Should default to 1.0 serving if parsing fails
        XCTAssertEqual(mealItem1.portion, 1.0, accuracy: 0.01)
        XCTAssertEqual(mealItem1.unit, "no number")
        
        // Should parse fraction correctly
        XCTAssertEqual(mealItem2.portion, 2.0/3.0, accuracy: 0.01)
        XCTAssertEqual(mealItem2.unit, "serving")
    }
}


