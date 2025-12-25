//
//  DaySummaryTests.swift
//  CalCalculatorTests
//
//  Unit tests for DaySummary model
//

import XCTest
@testable import playground
import Foundation

final class DaySummaryTests: XCTestCase {
    
    func testDaySummaryInitialization() {
        // Given
        let date = Date()
        let totalCalories = 2000
        let totalProtein = 150.0
        let totalCarbs = 200.0
        let totalFat = 65.0
        let mealCount = 3
        
        // When
        let summary = DaySummary(
            date: date,
            totalCalories: totalCalories,
            totalProteinG: totalProtein,
            totalCarbsG: totalCarbs,
            totalFatG: totalFat,
            mealCount: mealCount
        )
        
        // Then
        XCTAssertEqual(summary.date, date)
        XCTAssertEqual(summary.totalCalories, totalCalories)
        XCTAssertEqual(summary.totalProteinG, totalProtein, accuracy: 0.01)
        XCTAssertEqual(summary.totalCarbsG, totalCarbs, accuracy: 0.01)
        XCTAssertEqual(summary.totalFatG, totalFat, accuracy: 0.01)
        XCTAssertEqual(summary.mealCount, mealCount)
    }
    
    func testDaySummaryDefaultValues() {
        // Given
        let date = Date()
        
        // When
        let summary = DaySummary(date: date)
        
        // Then
        XCTAssertEqual(summary.totalCalories, 0)
        XCTAssertEqual(summary.totalProteinG, 0.0, accuracy: 0.01)
        XCTAssertEqual(summary.totalCarbsG, 0.0, accuracy: 0.01)
        XCTAssertEqual(summary.totalFatG, 0.0, accuracy: 0.01)
        XCTAssertEqual(summary.mealCount, 0)
    }
    
    func testDaySummaryAddMeal() {
        // Given
        let summary = DaySummary(date: Date())
        let meal = Meal(name: "Breakfast", timestamp: Date())
        let item = MealItem(
            name: "Oatmeal",
            portion: 100,
            unit: "g",
            calories: 389,
            proteinG: 16.9,
            carbsG: 66.3,
            fatG: 6.9
        )
        meal.items.append(item)
        
        // When
        summary.addMeal(meal)
        
        // Then
        XCTAssertEqual(summary.totalCalories, 389)
        XCTAssertEqual(summary.totalProteinG, 16.9, accuracy: 0.01)
        XCTAssertEqual(summary.totalCarbsG, 66.3, accuracy: 0.01)
        XCTAssertEqual(summary.totalFatG, 6.9, accuracy: 0.01)
        XCTAssertEqual(summary.mealCount, 1)
    }
    
    func testDaySummaryRemoveMeal() {
        // Given
        let summary = DaySummary(date: Date())
        let meal = Meal(name: "Breakfast", timestamp: Date())
        let item = MealItem(
            name: "Oatmeal",
            portion: 100,
            unit: "g",
            calories: 389,
            proteinG: 16.9,
            carbsG: 66.3,
            fatG: 6.9
        )
        meal.items.append(item)
        summary.addMeal(meal)
        
        // When
        summary.removeMeal(meal)
        
        // Then
        XCTAssertEqual(summary.totalCalories, 0)
        XCTAssertEqual(summary.mealCount, 0)
    }
    
    func testDaySummaryIsToday() {
        // Given
        let todaySummary = DaySummary(date: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdaySummary = DaySummary(date: yesterday)
        
        // Then
        XCTAssertTrue(todaySummary.isToday)
        XCTAssertFalse(yesterdaySummary.isToday)
    }
}

