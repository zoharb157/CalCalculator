//
//  DateFormatterExtensionsTests.swift
//  CalCalculatorTests
//
//  Unit tests for DateFormatter+Extensions
//

import XCTest
@testable import playground

final class DateFormatterExtensionsTests: XCTestCase {
    
    func testFullDateString() {
        // Given
        let date = createDate(year: 2024, month: 1, day: 25)
        
        // When
        let formatted = date.fullDateString
        
        // Then
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("2024") || formatted.contains("January") || formatted.contains("25"))
    }
    
    func testMediumDateString() {
        // Given
        let date = createDate(year: 2024, month: 1, day: 25)
        
        // When
        let formatted = date.mediumDateString
        
        // Then
        XCTAssertFalse(formatted.isEmpty)
    }
    
    func testShortDateString() {
        // Given
        let date = createDate(year: 2024, month: 1, day: 25)
        
        // When
        let formatted = date.shortDateString
        
        // Then
        XCTAssertFalse(formatted.isEmpty)
    }
    
    func testDayNameString() {
        // Given
        let date = createDate(year: 2024, month: 1, day: 25) // Thursday
        
        // When
        let dayName = date.dayNameString
        
        // Then
        XCTAssertFalse(dayName.isEmpty)
        // Should be full day name like "Thursday"
    }
    
    func testShortDayNameString() {
        // Given
        let date = createDate(year: 2024, month: 1, day: 25)
        
        // When
        let shortDayName = date.shortDayNameString
        
        // Then
        XCTAssertFalse(shortDayName.isEmpty)
        // Should be short day name like "Thu"
    }
    
    func testMonthDayString() {
        // Given
        let date = createDate(year: 2024, month: 1, day: 25)
        
        // When
        let monthDay = date.monthDayString
        
        // Then
        XCTAssertFalse(monthDay.isEmpty)
        // Should be like "January 25"
    }
    
    func testShortMonthDayString() {
        // Given
        let date = createDate(year: 2024, month: 1, day: 25)
        
        // When
        let shortMonthDay = date.shortMonthDayString
        
        // Then
        XCTAssertFalse(shortMonthDay.isEmpty)
        // Should be like "Jan 25"
    }
    
    func testTimeString() {
        // Given
        let date = createDate(year: 2024, month: 1, day: 25, hour: 14, minute: 30)
        
        // When
        let time = date.timeString
        
        // Then
        XCTAssertFalse(time.isEmpty)
        // Should be like "2:30 PM" or "14:30"
    }
    
    func testWeekdayMonthDayString() {
        // Given
        let date = createDate(year: 2024, month: 1, day: 25)
        
        // When
        let weekdayMonthDay = date.weekdayMonthDayString
        
        // Then
        XCTAssertFalse(weekdayMonthDay.isEmpty)
        // Should be like "Thu, Jan 25"
    }
    
    // MARK: - Helper Methods
    
    private func createDate(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

