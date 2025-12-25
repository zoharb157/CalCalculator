//
//  WeightEntryTests.swift
//  CalCalculatorTests
//
//  Unit tests for WeightEntry model
//

import XCTest
@testable import playground

final class WeightEntryTests: XCTestCase {
    
    func testWeightEntryInitialization() {
        // Given
        let weight = 70.5
        let date = Date()
        let note = "Morning weight"
        
        // When
        let entry = WeightEntry(weight: weight, date: date, note: note)
        
        // Then
        XCTAssertEqual(entry.weight, weight, accuracy: 0.01)
        XCTAssertEqual(entry.date, Calendar.current.startOfDay(for: date))
        XCTAssertEqual(entry.note, note)
    }
    
    func testWeightEntryDefaultValues() {
        // When
        let entry = WeightEntry(weight: 70.0)
        
        // Then
        XCTAssertNil(entry.note)
        XCTAssertEqual(entry.date, Calendar.current.startOfDay(for: Date()))
    }
    
    func testWeightEntryWeightInPounds() {
        // Given
        let weightKg = 70.0
        let entry = WeightEntry(weight: weightKg)
        
        // When
        let weightLbs = entry.weightInPounds
        
        // Then
        let expectedLbs = weightKg * 2.20462
        XCTAssertEqual(weightLbs, expectedLbs, accuracy: 0.01)
    }
    
    func testWeightEntryFormattedDate() {
        // Given
        let date = Date()
        let entry = WeightEntry(weight: 70.0, date: date)
        
        // When
        let formatted = entry.formattedDate
        
        // Then
        XCTAssertFalse(formatted.isEmpty)
    }
    
    func testWeightEntryShortDate() {
        // Given
        let date = Date()
        let entry = WeightEntry(weight: 70.0, date: date)
        
        // When
        let shortDate = entry.shortDate
        
        // Then
        XCTAssertFalse(shortDate.isEmpty)
        // Should be in "MMM d" format (e.g., "Jan 25")
    }
}

