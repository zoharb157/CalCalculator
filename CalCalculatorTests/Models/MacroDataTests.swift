//
//  MacroDataTests.swift
//  CalCalculatorTests
//
//  Unit tests for MacroData
//

import XCTest
@testable import playground

final class MacroDataTests: XCTestCase {
    
    func testMacroDataInitialization() {
        // Given
        let calories = 500
        let protein = 30.0
        let carbs = 50.0
        let fat = 20.0
        
        // When
        let macros = MacroData(calories: calories, proteinG: protein, carbsG: carbs, fatG: fat)
        
        // Then
        XCTAssertEqual(macros.calories, calories)
        XCTAssertEqual(macros.proteinG, protein, accuracy: 0.01)
        XCTAssertEqual(macros.carbsG, carbs, accuracy: 0.01)
        XCTAssertEqual(macros.fatG, fat, accuracy: 0.01)
    }
    
    func testMacroDataDefaultValues() {
        // When
        let macros = MacroData()
        
        // Then
        XCTAssertEqual(macros.calories, 0)
        XCTAssertEqual(macros.proteinG, 0.0, accuracy: 0.01)
        XCTAssertEqual(macros.carbsG, 0.0, accuracy: 0.01)
        XCTAssertEqual(macros.fatG, 0.0, accuracy: 0.01)
    }
    
    func testMacroDataZero() {
        // When
        let zero = MacroData.zero
        
        // Then
        XCTAssertEqual(zero.calories, 0)
        XCTAssertEqual(zero.proteinG, 0.0, accuracy: 0.01)
        XCTAssertEqual(zero.carbsG, 0.0, accuracy: 0.01)
        XCTAssertEqual(zero.fatG, 0.0, accuracy: 0.01)
    }
    
    func testMacroDataAddition() {
        // Given
        let macros1 = MacroData(calories: 200, proteinG: 20, carbsG: 30, fatG: 10)
        let macros2 = MacroData(calories: 300, proteinG: 30, carbsG: 40, fatG: 15)
        
        // When
        let sum = macros1 + macros2
        
        // Then
        XCTAssertEqual(sum.calories, 500)
        XCTAssertEqual(sum.proteinG, 50.0, accuracy: 0.01)
        XCTAssertEqual(sum.carbsG, 70.0, accuracy: 0.01)
        XCTAssertEqual(sum.fatG, 25.0, accuracy: 0.01)
    }
    
    func testMacroDataScaled() {
        // Given
        let macros = MacroData(calories: 200, proteinG: 20, carbsG: 30, fatG: 10)
        let ratio = 1.5
        
        // When
        let scaled = macros.scaled(by: ratio)
        
        // Then
        XCTAssertEqual(scaled.calories, 300)
        XCTAssertEqual(scaled.proteinG, 30.0, accuracy: 0.01)
        XCTAssertEqual(scaled.carbsG, 45.0, accuracy: 0.01)
        XCTAssertEqual(scaled.fatG, 15.0, accuracy: 0.01)
    }
    
    func testMacroDataScaledByZero() {
        // Given
        let macros = MacroData(calories: 200, proteinG: 20, carbsG: 30, fatG: 10)
        
        // When
        let scaled = macros.scaled(by: 0)
        
        // Then
        XCTAssertEqual(scaled.calories, 0)
        XCTAssertEqual(scaled.proteinG, 0.0, accuracy: 0.01)
        XCTAssertEqual(scaled.carbsG, 0.0, accuracy: 0.01)
        XCTAssertEqual(scaled.fatG, 0.0, accuracy: 0.01)
    }
    
    func testMacroDataEquality() {
        // Given
        let macros1 = MacroData(calories: 200, proteinG: 20, carbsG: 30, fatG: 10)
        let macros2 = MacroData(calories: 200, proteinG: 20, carbsG: 30, fatG: 10)
        let macros3 = MacroData(calories: 300, proteinG: 20, carbsG: 30, fatG: 10)
        
        // Then
        XCTAssertEqual(macros1, macros2)
        XCTAssertNotEqual(macros1, macros3)
    }
    
    func testMacroDataHashable() {
        // Given
        let macros1 = MacroData(calories: 200, proteinG: 20, carbsG: 30, fatG: 10)
        let macros2 = MacroData(calories: 200, proteinG: 20, carbsG: 30, fatG: 10)
        
        // Then
        XCTAssertEqual(macros1.hashValue, macros2.hashValue)
    }
}


