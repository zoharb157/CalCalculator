//
//  ConfidenceLevelTests.swift
//  CalCalculatorTests
//
//  Unit tests for ConfidenceLevel
//

import XCTest
@testable import playground

final class ConfidenceLevelTests: XCTestCase {
    
    func testConfidenceLevelRawValues() {
        // Then
        XCTAssertEqual(ConfidenceLevel.high.rawValue, "high")
        XCTAssertEqual(ConfidenceLevel.medium.rawValue, "medium")
        XCTAssertEqual(ConfidenceLevel.low.rawValue, "low")
    }
    
    func testConfidenceLevelFromRawValue() {
        // Then
        XCTAssertEqual(ConfidenceLevel(rawValue: "high"), .high)
        XCTAssertEqual(ConfidenceLevel(rawValue: "medium"), .medium)
        XCTAssertEqual(ConfidenceLevel(rawValue: "low"), .low)
        XCTAssertNil(ConfidenceLevel(rawValue: "invalid"))
    }
    
    func testConfidenceLevelNumericValue() {
        // Then
        XCTAssertEqual(ConfidenceLevel.high.numericValue, 0.9, accuracy: 0.01)
        XCTAssertEqual(ConfidenceLevel.medium.numericValue, 0.7, accuracy: 0.01)
        XCTAssertEqual(ConfidenceLevel.low.numericValue, 0.5, accuracy: 0.01)
    }
    
    func testConfidenceLevelAllCases() {
        // Then
        let allCases = ConfidenceLevel.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.high))
        XCTAssertTrue(allCases.contains(.medium))
        XCTAssertTrue(allCases.contains(.low))
    }
}


