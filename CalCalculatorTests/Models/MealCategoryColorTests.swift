//
//  MealCategoryColorTests.swift
//  CalCalculatorTests
//
//  Unit tests for MealCategory color property
//

import XCTest
@testable import playground
import SwiftUI

final class MealCategoryColorTests: XCTestCase {
    
    func testMealCategoryBreakfastColor() {
        // Then
        XCTAssertEqual(MealCategory.breakfast.color, .orange)
    }
    
    func testMealCategoryLunchColor() {
        // Then
        XCTAssertEqual(MealCategory.lunch.color, .blue)
    }
    
    func testMealCategoryDinnerColor() {
        // Then
        XCTAssertEqual(MealCategory.dinner.color, .purple)
    }
    
    func testMealCategorySnackColor() {
        // Then
        XCTAssertEqual(MealCategory.snack.color, .green)
    }
    
    func testMealCategoryAllColorsAreDifferent() {
        // Then
        let colors = Set([
            MealCategory.breakfast.color,
            MealCategory.lunch.color,
            MealCategory.dinner.color,
            MealCategory.snack.color
        ])
        
        // All categories should have different colors
        XCTAssertEqual(colors.count, 4)
    }
}

