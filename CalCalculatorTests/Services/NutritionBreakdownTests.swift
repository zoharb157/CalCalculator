//
//  NutritionBreakdownTests.swift
//  CalCalculatorTests
//
//  Unit tests for NutritionBreakdown
//

import XCTest
@testable import playground

final class NutritionBreakdownTests: XCTestCase {
    
    func testNutritionBreakdownDecoding() throws {
        // Given
        let jsonString = """
        {
            "protein_g": 30.0,
            "carbs_g": 50.0,
            "fat_g": 20.0,
            "fiber_g": 5.0,
            "sugar_g": 10.0,
            "sodium_mg": 500.0,
            "saturated_fat_g": 8.0
        }
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // When
        let breakdown = try decoder.decode(NutritionBreakdown.self, from: data)
        
        // Then
        XCTAssertEqual(breakdown.proteinG, 30.0, accuracy: 0.01)
        XCTAssertEqual(breakdown.carbsG, 50.0, accuracy: 0.01)
        XCTAssertEqual(breakdown.fatG, 20.0, accuracy: 0.01)
        XCTAssertEqual(breakdown.fiberG, 5.0, accuracy: 0.01)
        XCTAssertEqual(breakdown.sugarG, 10.0, accuracy: 0.01)
        XCTAssertEqual(breakdown.sodiumMg, 500.0, accuracy: 0.01)
        XCTAssertEqual(breakdown.saturatedFatG, 8.0, accuracy: 0.01)
    }
    
    func testNutritionBreakdownWithMissingFields() throws {
        // Given
        let jsonString = """
        {
            "protein_g": 30.0,
            "carbs_g": 50.0,
            "fat_g": 20.0
        }
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // When
        let breakdown = try decoder.decode(NutritionBreakdown.self, from: data)
        
        // Then
        XCTAssertEqual(breakdown.proteinG, 30.0, accuracy: 0.01)
        XCTAssertEqual(breakdown.carbsG, 50.0, accuracy: 0.01)
        XCTAssertEqual(breakdown.fatG, 20.0, accuracy: 0.01)
        XCTAssertNil(breakdown.fiberG)
        XCTAssertNil(breakdown.sugarG)
        XCTAssertNil(breakdown.sodiumMg)
        XCTAssertNil(breakdown.saturatedFatG)
    }
    
    func testNutritionBreakdownToMacroData() throws {
        // Given
        let jsonString = """
        {
            "protein_g": 30.0,
            "carbs_g": 50.0,
            "fat_g": 20.0
        }
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let breakdown = try decoder.decode(NutritionBreakdown.self, from: data)
        
        // When
        let macroData = breakdown.toMacroData
        
        // Then
        XCTAssertEqual(macroData.proteinG, 30.0, accuracy: 0.01)
        XCTAssertEqual(macroData.carbsG, 50.0, accuracy: 0.01)
        XCTAssertEqual(macroData.fatG, 20.0, accuracy: 0.01)
        XCTAssertEqual(macroData.calories, 0) // toMacroData sets calories to 0
    }
}

