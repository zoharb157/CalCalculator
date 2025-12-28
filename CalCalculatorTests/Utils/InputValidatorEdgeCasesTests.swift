//
//  InputValidatorEdgeCasesTests.swift
//  CalCalculatorTests
//
//  Edge case tests for InputValidator
//

import XCTest
@testable import playground

final class InputValidatorEdgeCasesTests: XCTestCase {
    
    func testCaloriesBoundaryValues() {
        // Then
        XCTAssertTrue(InputValidator.validateCalories(1).isValid)
        XCTAssertTrue(InputValidator.validateCalories(10000).isValid)
        XCTAssertFalse(InputValidator.validateCalories(0).isValid)
        XCTAssertFalse(InputValidator.validateCalories(10001).isValid)
    }
    
    func testWeightBoundaryValues() {
        // Then
        // Minimum values
        XCTAssertTrue(InputValidator.validateWeight(20, unit: "kg").isValid)
        XCTAssertTrue(InputValidator.validateWeight(44, unit: "lbs").isValid)
        XCTAssertFalse(InputValidator.validateWeight(19.9, unit: "kg").isValid)
        XCTAssertFalse(InputValidator.validateWeight(43.9, unit: "lbs").isValid)
        
        // Maximum values
        XCTAssertTrue(InputValidator.validateWeight(300, unit: "kg").isValid)
        XCTAssertTrue(InputValidator.validateWeight(660, unit: "lbs").isValid)
        XCTAssertFalse(InputValidator.validateWeight(300.1, unit: "kg").isValid)
        XCTAssertFalse(InputValidator.validateWeight(660.1, unit: "lbs").isValid)
    }
    
    func testHeightBoundaryValues() {
        // Then
        // Minimum values
        XCTAssertTrue(InputValidator.validateHeight(50, unit: "cm").isValid)
        XCTAssertTrue(InputValidator.validateHeight(20, unit: "in").isValid)
        XCTAssertFalse(InputValidator.validateHeight(49.9, unit: "cm").isValid)
        XCTAssertFalse(InputValidator.validateHeight(19.9, unit: "in").isValid)
        
        // Maximum values
        XCTAssertTrue(InputValidator.validateHeight(250, unit: "cm").isValid)
        XCTAssertTrue(InputValidator.validateHeight(100, unit: "in").isValid)
        XCTAssertFalse(InputValidator.validateHeight(250.1, unit: "cm").isValid)
        XCTAssertFalse(InputValidator.validateHeight(100.1, unit: "in").isValid)
    }
    
    func testAgeBoundaryValues() {
        // Then
        XCTAssertTrue(InputValidator.validateAge(13).isValid)
        XCTAssertTrue(InputValidator.validateAge(120).isValid)
        XCTAssertFalse(InputValidator.validateAge(12).isValid)
        XCTAssertFalse(InputValidator.validateAge(121).isValid)
    }
    
    func testMacroBoundaryValues() {
        // Then
        // Protein
        XCTAssertTrue(InputValidator.validateMacro(500, type: .protein).isValid)
        XCTAssertFalse(InputValidator.validateMacro(500.1, type: .protein).isValid)
        
        // Carbs
        XCTAssertTrue(InputValidator.validateMacro(1000, type: .carbs).isValid)
        XCTAssertFalse(InputValidator.validateMacro(1000.1, type: .carbs).isValid)
        
        // Fat
        XCTAssertTrue(InputValidator.validateMacro(300, type: .fat).isValid)
        XCTAssertFalse(InputValidator.validateMacro(300.1, type: .fat).isValid)
    }
    
    func testTextValidationEdgeCases() {
        // Then
        // Minimum length
        XCTAssertTrue(InputValidator.validateText("A", minLength: 1).isValid)
        XCTAssertFalse(InputValidator.validateText("", minLength: 1).isValid)
        
        // Maximum length
        let maxLengthText = String(repeating: "A", count: 500)
        XCTAssertTrue(InputValidator.validateText(maxLengthText, maxLength: 500).isValid)
        
        let overMaxLengthText = String(repeating: "A", count: 501)
        XCTAssertFalse(InputValidator.validateText(overMaxLengthText, maxLength: 500).isValid)
    }
}


