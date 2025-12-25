//
//  InputValidatorTests.swift
//  CalCalculatorTests
//
//  Unit tests for InputValidator utility
//

import XCTest
@testable import playground

final class InputValidatorTests: XCTestCase {
    
    // MARK: - Calories Validation
    
    func testValidCalories() {
        XCTAssertTrue(InputValidator.validateCalories(100).isValid)
        XCTAssertTrue(InputValidator.validateCalories(2000).isValid)
        XCTAssertTrue(InputValidator.validateCalories(1).isValid)
        XCTAssertTrue(InputValidator.validateCalories(5000).isValid)
    }
    
    func testInvalidCalories() {
        XCTAssertFalse(InputValidator.validateCalories(-100).isValid)
        XCTAssertFalse(InputValidator.validateCalories(10001).isValid)
        if case .invalid(let message) = InputValidator.validateCalories(-100) {
            XCTAssertTrue(message.contains("negative"))
        }
        if case .invalid(let message) = InputValidator.validateCalories(10001) {
            XCTAssertTrue(message.contains("too high"))
        }
    }
    
    // MARK: - Weight Validation
    
    func testValidWeight() {
        XCTAssertTrue(InputValidator.validateWeight(70, unit: "kg").isValid)
        XCTAssertTrue(InputValidator.validateWeight(154, unit: "lbs").isValid)
        XCTAssertTrue(InputValidator.validateWeight(50, unit: "kg").isValid)
    }
    
    func testInvalidWeight() {
        XCTAssertFalse(InputValidator.validateWeight(19, unit: "kg").isValid)
        XCTAssertFalse(InputValidator.validateWeight(301, unit: "kg").isValid)
        XCTAssertFalse(InputValidator.validateWeight(43, unit: "lbs").isValid)
        XCTAssertFalse(InputValidator.validateWeight(661, unit: "lbs").isValid)
    }
    
    // MARK: - Height Validation
    
    func testValidHeight() {
        XCTAssertTrue(InputValidator.validateHeight(170, unit: "cm").isValid)
        XCTAssertTrue(InputValidator.validateHeight(67, unit: "in").isValid)
        XCTAssertTrue(InputValidator.validateHeight(50, unit: "cm").isValid)
    }
    
    func testInvalidHeight() {
        XCTAssertFalse(InputValidator.validateHeight(49, unit: "cm").isValid)
        XCTAssertFalse(InputValidator.validateHeight(251, unit: "cm").isValid)
        XCTAssertFalse(InputValidator.validateHeight(19, unit: "in").isValid)
        XCTAssertFalse(InputValidator.validateHeight(101, unit: "in").isValid)
    }
    
    // MARK: - Age Validation
    
    func testValidAge() {
        XCTAssertTrue(InputValidator.validateAge(18).isValid)
        XCTAssertTrue(InputValidator.validateAge(25).isValid)
        XCTAssertTrue(InputValidator.validateAge(100).isValid)
        XCTAssertTrue(InputValidator.validateAge(13).isValid)
    }
    
    func testInvalidAge() {
        XCTAssertFalse(InputValidator.validateAge(12).isValid)
        XCTAssertFalse(InputValidator.validateAge(121).isValid)
        if case .invalid(let message) = InputValidator.validateAge(12) {
            XCTAssertTrue(message.contains("13"))
        }
    }
    
    // MARK: - Macro Validation
    
    func testValidMacro() {
        XCTAssertTrue(InputValidator.validateMacro(50, type: .protein).isValid)
        XCTAssertTrue(InputValidator.validateMacro(100, type: .carbs).isValid)
        XCTAssertTrue(InputValidator.validateMacro(30, type: .fat).isValid)
        XCTAssertTrue(InputValidator.validateMacro(0, type: .protein).isValid)
    }
    
    func testInvalidMacro() {
        XCTAssertFalse(InputValidator.validateMacro(-10, type: .protein).isValid)
        XCTAssertFalse(InputValidator.validateMacro(501, type: .protein).isValid)
        XCTAssertFalse(InputValidator.validateMacro(1001, type: .carbs).isValid)
        XCTAssertFalse(InputValidator.validateMacro(301, type: .fat).isValid)
    }
    
    // MARK: - Text Validation
    
    func testValidText() {
        XCTAssertTrue(InputValidator.validateText("Hello").isValid)
        XCTAssertTrue(InputValidator.validateText("  Hello  ").isValid)
        XCTAssertTrue(InputValidator.validateText("A", minLength: 1).isValid)
    }
    
    func testInvalidText() {
        XCTAssertFalse(InputValidator.validateText("").isValid)
        XCTAssertFalse(InputValidator.validateText("   ").isValid)
        XCTAssertFalse(InputValidator.validateText("A", minLength: 2).isValid)
        XCTAssertFalse(InputValidator.validateText(String(repeating: "A", count: 501), maxLength: 500).isValid)
    }
}

