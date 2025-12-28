//
//  DietPlanTests.swift
//  CalCalculatorTests
//
//  Unit tests for DietPlan model
//

import XCTest
@testable import playground
import Foundation

final class DietPlanTests: XCTestCase {
    
    func testDietPlanInitialization() {
        // Given
        let name = "Keto Diet"
        let description = "Low carb, high fat"
        
        // When
        let plan = DietPlan(
            name: name,
            planDescription: description,
            isActive: true
        )
        
        // Then
        XCTAssertEqual(plan.name, name)
        XCTAssertEqual(plan.planDescription, description)
        XCTAssertTrue(plan.isActive)
        XCTAssertTrue(plan.scheduledMeals.isEmpty)
    }
    
    func testDietPlanScheduledMealsForDay() {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        let mondayMeal = ScheduledMeal(
            name: "Monday Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2] // Monday
        )
        let weekdayMeal = ScheduledMeal(
            name: "Weekday Lunch",
            category: .lunch,
            time: Date(),
            daysOfWeek: [2, 3, 4, 5, 6] // Mon-Fri
        )
        
        plan.scheduledMeals.append(mondayMeal)
        plan.scheduledMeals.append(weekdayMeal)
        
        // When
        let mondayMeals = plan.scheduledMeals(for: 2) // Monday
        let tuesdayMeals = plan.scheduledMeals(for: 3) // Tuesday
        
        // Then
        XCTAssertEqual(mondayMeals.count, 2) // Both meals scheduled for Monday
        XCTAssertEqual(tuesdayMeals.count, 1) // Only weekday meal scheduled for Tuesday
    }
    
    func testDietPlanTodaysScheduledMeals() {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
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
        
        plan.scheduledMeals.append(todayMeal)
        plan.scheduledMeals.append(otherDayMeal)
        
        // When
        let todaysMeals = plan.todaysScheduledMeals()
        
        // Then
        XCTAssertEqual(todaysMeals.count, 1)
        XCTAssertEqual(todaysMeals.first?.name, "Today Meal")
    }
}


