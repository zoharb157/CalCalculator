//
//  MealCategoryTests.swift
//  CalCalculatorTests
//
//  Unit tests for MealCategory enum
//

import XCTest
@testable import playground

final class MealCategoryTests: XCTestCase {
    
    func testMealCategoryRawValues() {
        // Then
        XCTAssertEqual(MealCategory.breakfast.rawValue, "breakfast")
        XCTAssertEqual(MealCategory.lunch.rawValue, "lunch")
        XCTAssertEqual(MealCategory.dinner.rawValue, "dinner")
        XCTAssertEqual(MealCategory.snack.rawValue, "snack")
    }
    
    func testMealCategoryFromRawValue() {
        // Then
        XCTAssertEqual(MealCategory(rawValue: "breakfast"), .breakfast)
        XCTAssertEqual(MealCategory(rawValue: "lunch"), .lunch)
        XCTAssertEqual(MealCategory(rawValue: "dinner"), .dinner)
        XCTAssertEqual(MealCategory(rawValue: "snack"), .snack)
        XCTAssertNil(MealCategory(rawValue: "invalid"))
    }
    
    func testMealCategoryAllCases() {
        // Then
        let allCases = MealCategory.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.breakfast))
        XCTAssertTrue(allCases.contains(.lunch))
        XCTAssertTrue(allCases.contains(.dinner))
        XCTAssertTrue(allCases.contains(.snack))
    }
    
    func testMealCategoryInferenceFromHour() {
        // Given
        let breakfastHour = 8
        let lunchHour = 13
        let dinnerHour = 19
        let snackHour = 22
        
        // When
        let breakfastDate = createDate(hour: breakfastHour)
        let lunchDate = createDate(hour: lunchHour)
        let dinnerDate = createDate(hour: dinnerHour)
        let snackDate = createDate(hour: snackHour)
        
        let breakfastMeal = Meal(name: "Breakfast", timestamp: breakfastDate)
        let lunchMeal = Meal(name: "Lunch", timestamp: lunchDate)
        let dinnerMeal = Meal(name: "Dinner", timestamp: dinnerDate)
        let snackMeal = Meal(name: "Snack", timestamp: snackDate)
        
        // Then
        XCTAssertEqual(breakfastMeal.category, .breakfast)
        XCTAssertEqual(lunchMeal.category, .lunch)
        XCTAssertEqual(dinnerMeal.category, .dinner)
        XCTAssertEqual(snackMeal.category, .snack)
    }
    
    // MARK: - Helper Methods
    
    private func createDate(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}

