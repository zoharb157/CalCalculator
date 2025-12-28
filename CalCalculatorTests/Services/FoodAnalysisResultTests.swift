//
//  FoodAnalysisResultTests.swift
//  CalCalculatorTests
//
//  Unit tests for FoodAnalysisResult
//

import XCTest
@testable import playground

final class FoodAnalysisResultTests: XCTestCase {
    
    func testFoodAnalysisResultToMealWithFoodDetected() {
        // Given
        let item = FoodItemResult(
            name: "Chicken",
            calories: 165,
            portion: "100 g",
            proteinG: 31.0,
            carbsG: 0.0,
            fatG: 3.6
        )
        
        let result = FoodAnalysisResult(
            foodDetected: true,
            mealName: "Chicken Breast",
            brand: nil,
            totalCalories: 165,
            confidence: .high,
            breakdown: nil,
            servingSize: "100 g",
            items: [item],
            source: nil,
            barcode: nil,
            ingredients: nil,
            labelType: nil,
            notes: "Grilled chicken breast"
        )
        
        // When
        let meal = result.toMeal()
        
        // Then
        XCTAssertNotNil(meal)
        XCTAssertEqual(meal?.name, "Chicken Breast")
        XCTAssertEqual(meal?.confidence, 0.9, accuracy: 0.01)
        XCTAssertEqual(meal?.notes, "Grilled chicken breast")
        XCTAssertEqual(meal?.items.count, 1)
        XCTAssertEqual(meal?.items.first?.name, "Chicken")
    }
    
    func testFoodAnalysisResultToMealNoFoodDetected() {
        // Given
        let result = FoodAnalysisResult(
            foodDetected: false,
            mealName: nil,
            brand: nil,
            totalCalories: nil,
            confidence: nil,
            breakdown: nil,
            servingSize: nil,
            items: nil,
            source: nil,
            barcode: nil,
            ingredients: nil,
            labelType: nil,
            notes: "No food detected"
        )
        
        // When
        let meal = result.toMeal()
        
        // Then
        XCTAssertNil(meal)
    }
    
    func testFoodAnalysisResultToMealNoMealName() {
        // Given
        let result = FoodAnalysisResult(
            foodDetected: true,
            mealName: nil,
            brand: nil,
            totalCalories: 500,
            confidence: .medium,
            breakdown: nil,
            servingSize: nil,
            items: nil,
            source: nil,
            barcode: nil,
            ingredients: nil,
            labelType: nil,
            notes: nil
        )
        
        // When
        let meal = result.toMeal()
        
        // Then
        XCTAssertNil(meal) // Requires mealName
    }
    
    func testFoodAnalysisResultToMealWithConfidenceLevels() {
        // Given
        let highConfidenceResult = FoodAnalysisResult(
            foodDetected: true,
            mealName: "Meal",
            brand: nil,
            totalCalories: 500,
            confidence: .high,
            breakdown: nil,
            servingSize: nil,
            items: nil,
            source: nil,
            barcode: nil,
            ingredients: nil,
            labelType: nil,
            notes: nil
        )
        
        let mediumConfidenceResult = FoodAnalysisResult(
            foodDetected: true,
            mealName: "Meal",
            brand: nil,
            totalCalories: 500,
            confidence: .medium,
            breakdown: nil,
            servingSize: nil,
            items: nil,
            source: nil,
            barcode: nil,
            ingredients: nil,
            labelType: nil,
            notes: nil
        )
        
        let lowConfidenceResult = FoodAnalysisResult(
            foodDetected: true,
            mealName: "Meal",
            brand: nil,
            totalCalories: 500,
            confidence: .low,
            breakdown: nil,
            servingSize: nil,
            items: nil,
            source: nil,
            barcode: nil,
            ingredients: nil,
            labelType: nil,
            notes: nil
        )
        
        // When
        let highMeal = highConfidenceResult.toMeal()
        let mediumMeal = mediumConfidenceResult.toMeal()
        let lowMeal = lowConfidenceResult.toMeal()
        
        // Then
        XCTAssertEqual(highMeal?.confidence, 0.9, accuracy: 0.01)
        XCTAssertEqual(mediumMeal?.confidence, 0.7, accuracy: 0.01)
        XCTAssertEqual(lowMeal?.confidence, 0.5, accuracy: 0.01)
    }
    
    func testFoodAnalysisResultToMealWithNoConfidence() {
        // Given
        let result = FoodAnalysisResult(
            foodDetected: true,
            mealName: "Meal",
            brand: nil,
            totalCalories: 500,
            confidence: nil,
            breakdown: nil,
            servingSize: nil,
            items: nil,
            source: nil,
            barcode: nil,
            ingredients: nil,
            labelType: nil,
            notes: nil
        )
        
        // When
        let meal = result.toMeal()
        
        // Then
        XCTAssertNotNil(meal)
        XCTAssertEqual(meal?.confidence, 0.0) // Defaults to 0 when confidence is nil
    }
}


