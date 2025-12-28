//
//  ScheduledMealTimeTests.swift
//  CalCalculatorTests
//
//  Unit tests for ScheduledMeal time-related functionality
//

import XCTest
@testable import playground
import Foundation

final class ScheduledMealTimeTests: XCTestCase {
    
    func testScheduledMealFormattedTime() {
        // Given
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 8
        components.minute = 30
        let time = calendar.date(from: components) ?? Date()
        
        let meal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: time,
            daysOfWeek: [2]
        )
        
        // When
        let formatted = meal.formattedTime
        
        // Then
        XCTAssertFalse(formatted.isEmpty)
        // Should contain time information
        XCTAssertTrue(formatted.contains("8") || formatted.contains("AM") || formatted.contains("08"))
    }
    
    func testScheduledMealDayNames() {
        // Given
        let meal = ScheduledMeal(
            name: "Weekday Meal",
            category: .lunch,
            time: Date(),
            daysOfWeek: [2, 3, 4, 5, 6] // Mon-Fri
        )
        
        // When
        let dayNames = meal.dayNames
        
        // Then
        XCTAssertTrue(dayNames.contains("Mon"))
        XCTAssertTrue(dayNames.contains("Wed"))
        XCTAssertTrue(dayNames.contains("Fri"))
        XCTAssertFalse(dayNames.contains("Sun"))
        XCTAssertFalse(dayNames.contains("Sat"))
    }
    
    func testScheduledMealIsScheduledToday() {
        // Given
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())
        
        let meal = ScheduledMeal(
            name: "Today's Meal",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [today]
        )
        
        // Then
        XCTAssertTrue(meal.isScheduledToday)
    }
    
    func testScheduledMealNextScheduledTime() {
        // Given
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.component(.weekday, from: now)
        
        // Create a meal scheduled for tomorrow
        let tomorrow = (today % 7) + 1
        var timeComponents = calendar.dateComponents([.hour, .minute], from: now)
        timeComponents.hour = 12
        timeComponents.minute = 0
        let mealTime = calendar.date(from: timeComponents) ?? now
        
        let meal = ScheduledMeal(
            name: "Tomorrow's Meal",
            category: .lunch,
            time: mealTime,
            daysOfWeek: [tomorrow]
        )
        
        // When
        let nextTime = meal.nextScheduledTime()
        
        // Then
        XCTAssertNotNil(nextTime)
        if let next = nextTime {
            XCTAssertTrue(next > now)
        }
    }
}


