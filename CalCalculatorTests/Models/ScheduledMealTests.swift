//
//  ScheduledMealTests.swift
//  CalCalculatorTests
//
//  Unit tests for ScheduledMeal model
//

import XCTest
@testable import playground
import Foundation

final class ScheduledMealTests: XCTestCase {
    
    func testScheduledMealInitialization() {
        // Given
        let name = "Breakfast"
        let category = MealCategory.breakfast
        let time = createDate(hour: 8, minute: 0)
        let daysOfWeek = [2, 3, 4, 5, 6] // Mon-Fri
        
        // When
        let meal = ScheduledMeal(
            name: name,
            category: category,
            time: time,
            daysOfWeek: daysOfWeek
        )
        
        // Then
        XCTAssertEqual(meal.name, name)
        XCTAssertEqual(meal.category, category)
        XCTAssertEqual(meal.time, time)
        XCTAssertEqual(meal.daysOfWeek, daysOfWeek)
    }
    
    func testScheduledMealFormattedTime() {
        // Given
        let meal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: createDate(hour: 8, minute: 30),
            daysOfWeek: [2]
        )
        
        // When
        let formattedTime = meal.formattedTime
        
        // Then
        XCTAssertFalse(formattedTime.isEmpty)
        // Should contain time information
        XCTAssertTrue(formattedTime.contains("8") || formattedTime.contains("08"))
    }
    
    func testScheduledMealDayNames() {
        // Given
        let meal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2, 3, 4] // Mon, Tue, Wed
        )
        
        // When
        let dayNames = meal.dayNames
        
        // Then
        XCTAssertFalse(dayNames.isEmpty)
        // Should contain day abbreviations
        XCTAssertTrue(dayNames.contains("Mon") || dayNames.contains("Mon,"))
    }
    
    func testScheduledMealIsScheduledToday() {
        // Given
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())
        
        let todayMeal = ScheduledMeal(
            name: "Today Meal",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [today]
        )
        
        let otherDayMeal = ScheduledMeal(
            name: "Other Day Meal",
            category: .lunch,
            time: Date(),
            daysOfWeek: [(today % 7) + 1] // Next day
        )
        
        // Then
        XCTAssertTrue(todayMeal.isScheduledToday)
        XCTAssertFalse(otherDayMeal.isScheduledToday)
    }
    
    func testScheduledMealNextScheduledTime() {
        // Given
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        // Create a meal scheduled for today at a future time
        let futureHour = (currentHour + 2) % 24
        let futureTime = createDate(hour: futureHour, minute: 0)
        let today = calendar.component(.weekday, from: now)
        
        let meal = ScheduledMeal(
            name: "Future Meal",
            category: .lunch,
            time: futureTime,
            daysOfWeek: [today]
        )
        
        // When
        let nextTime = meal.nextScheduledTime()
        
        // Then
        XCTAssertNotNil(nextTime)
        if let nextTime = nextTime {
            let nextHour = calendar.component(.hour, from: nextTime)
            XCTAssertEqual(nextHour, futureHour)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

