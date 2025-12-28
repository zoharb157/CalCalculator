//
//  WeekDayTests.swift
//  CalCalculatorTests
//
//  Unit tests for WeekDay struct
//

import XCTest
@testable import playground
import SwiftUI

final class WeekDayTests: XCTestCase {
    
    func testWeekDayInitialization() {
        // Given
        let date = Date()
        let summary = DaySummary(date: date, totalCalories: 2000)
        
        // When
        let weekDay = WeekDay(
            date: date,
            dayName: "Mon",
            dayNumber: 1,
            isToday: true,
            isSelected: true,
            progress: 0.8,
            summary: summary,
            caloriesConsumed: 1600,
            calorieGoal: 2000,
            hasMeals: true
        )
        
        // Then
        XCTAssertEqual(weekDay.date, date)
        XCTAssertEqual(weekDay.dayName, "Mon")
        XCTAssertEqual(weekDay.dayNumber, 1)
        XCTAssertTrue(weekDay.isToday)
        XCTAssertTrue(weekDay.isSelected)
        XCTAssertEqual(weekDay.progress, 0.8, accuracy: 0.01)
        XCTAssertEqual(weekDay.caloriesConsumed, 1600)
        XCTAssertEqual(weekDay.calorieGoal, 2000)
        XCTAssertTrue(weekDay.hasMeals)
    }
    
    func testWeekDayCaloriesOverGoal() {
        // Given
        let weekDay = WeekDay(
            date: Date(),
            dayName: "Mon",
            dayNumber: 1,
            isToday: false,
            isSelected: false,
            progress: 1.1,
            summary: nil,
            caloriesConsumed: 2200,
            calorieGoal: 2000,
            hasMeals: true
        )
        
        // When
        let overGoal = weekDay.caloriesOverGoal
        
        // Then
        XCTAssertEqual(overGoal, 200)
    }
    
    func testWeekDayCaloriesOverGoalZero() {
        // Given
        let weekDay = WeekDay(
            date: Date(),
            dayName: "Mon",
            dayNumber: 1,
            isToday: false,
            isSelected: false,
            progress: 0.8,
            summary: nil,
            caloriesConsumed: 1600,
            calorieGoal: 2000,
            hasMeals: true
        )
        
        // When
        let overGoal = weekDay.caloriesOverGoal
        
        // Then
        XCTAssertEqual(overGoal, 0)
    }
    
    func testWeekDayIsDotted() {
        // Given
        let weekDayWithMeals = WeekDay(
            date: Date(),
            dayName: "Mon",
            dayNumber: 1,
            isToday: false,
            isSelected: false,
            progress: 0.5,
            summary: nil,
            caloriesConsumed: 1000,
            calorieGoal: 2000,
            hasMeals: true
        )
        
        let weekDayWithoutMeals = WeekDay(
            date: Date(),
            dayName: "Tue",
            dayNumber: 2,
            isToday: false,
            isSelected: false,
            progress: 0.0,
            summary: nil,
            caloriesConsumed: 0,
            calorieGoal: 2000,
            hasMeals: false
        )
        
        // Then
        XCTAssertFalse(weekDayWithMeals.isDotted)
        XCTAssertTrue(weekDayWithoutMeals.isDotted)
    }
    
    func testWeekDayProgressColor() {
        // Given
        let greenDay = WeekDay(
            date: Date(),
            dayName: "Mon",
            dayNumber: 1,
            isToday: false,
            isSelected: false,
            progress: 1.0,
            summary: nil,
            caloriesConsumed: 2000,
            calorieGoal: 2000,
            hasMeals: true
        )
        
        let yellowDay = WeekDay(
            date: Date(),
            dayName: "Tue",
            dayNumber: 2,
            isToday: false,
            isSelected: false,
            progress: 1.05,
            summary: nil,
            caloriesConsumed: 2100,
            calorieGoal: 2000,
            hasMeals: true
        )
        
        let redDay = WeekDay(
            date: Date(),
            dayName: "Wed",
            dayNumber: 3,
            isToday: false,
            isSelected: false,
            progress: 1.2,
            summary: nil,
            caloriesConsumed: 2400,
            calorieGoal: 2000,
            hasMeals: true
        )
        
        let grayDay = WeekDay(
            date: Date(),
            dayName: "Thu",
            dayNumber: 4,
            isToday: false,
            isSelected: false,
            progress: 0.0,
            summary: nil,
            caloriesConsumed: 0,
            calorieGoal: 2000,
            hasMeals: false
        )
        
        // Then
        XCTAssertEqual(greenDay.progressColor, .green)
        XCTAssertEqual(yellowDay.progressColor, .yellow)
        XCTAssertEqual(redDay.progressColor, .red)
        XCTAssertEqual(grayDay.progressColor, .gray)
    }
}


