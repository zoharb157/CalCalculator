//
//  DietAdherenceCalculationsTests.swift
//  CalCalculatorTests
//
//  Unit tests for diet adherence calculation logic
//

import XCTest
@testable import playground
import SwiftData
import Foundation

final class DietAdherenceCalculationsTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    var repository: DietPlanRepository!
    var mealRepository: MealRepository!
    
    override func setUpWithError() throws {
        let schema = Schema([
            DietPlan.self,
            ScheduledMeal.self,
            MealTemplate.self,
            MealReminder.self,
            Meal.self,
            MealItem.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        repository = DietPlanRepository(context: context)
        mealRepository = MealRepository(context: context)
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
        repository = nil
        mealRepository = nil
    }
    
    func testAdherenceWithNoScheduledMeals() throws {
        // Given
        let plan = DietPlan(name: "Empty Plan", isActive: true)
        try repository.saveDietPlan(plan)
        let date = Date()
        
        // When
        let adherence = try repository.getDietAdherence(
            for: date,
            activePlans: [plan]
        )
        
        // Then
        XCTAssertEqual(adherence.scheduledMeals.count, 0)
        XCTAssertEqual(adherence.completionRate, 1.0, accuracy: 0.01)
        XCTAssertTrue(adherence.hasPerfectAdherence)
    }
    
    func testAdherenceWithAllMealsCompleted() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        let meal1 = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2] // Monday
        )
        let meal2 = ScheduledMeal(
            name: "Lunch",
            category: .lunch,
            time: Date(),
            daysOfWeek: [2] // Monday
        )
        plan.scheduledMeals.append(meal1)
        plan.scheduledMeals.append(meal2)
        try repository.saveDietPlan(plan)
        
        // Create meals that match the scheduled meals
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.weekday = 2 // Monday
        components.hour = 8
        components.minute = 0
        let monday = calendar.date(from: components) ?? Date()
        
        let loggedMeal1 = Meal(
            name: "Breakfast",
            timestamp: monday,
            category: .breakfast
        )
        let loggedMeal2 = Meal(
            name: "Lunch",
            timestamp: monday,
            category: .lunch
        )
        try mealRepository.saveMeal(loggedMeal1)
        try mealRepository.saveMeal(loggedMeal2)
        
        // When
        let adherence = try repository.getDietAdherence(
            for: monday,
            activePlans: [plan]
        )
        
        // Then
        XCTAssertEqual(adherence.scheduledMeals.count, 2)
        XCTAssertEqual(adherence.completedMeals.count, 2)
        XCTAssertEqual(adherence.completionRate, 1.0, accuracy: 0.01)
        XCTAssertTrue(adherence.hasPerfectAdherence)
    }
    
    func testAdherenceWithOffDietMeals() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        let scheduledMeal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2] // Monday
        )
        plan.scheduledMeals.append(scheduledMeal)
        try repository.saveDietPlan(plan)
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.weekday = 2 // Monday
        let monday = calendar.date(from: components) ?? Date()
        
        // Create an off-diet meal (different category)
        let offDietMeal = Meal(
            name: "Snack",
            timestamp: monday,
            category: .snack
        )
        let item = MealItem(
            name: "Chips",
            portion: 100,
            unit: "g",
            calories: 500,
            proteinG: 5,
            carbsG: 50,
            fatG: 30
        )
        offDietMeal.items.append(item)
        try mealRepository.saveMeal(offDietMeal)
        
        // When
        let adherence = try repository.getDietAdherence(
            for: monday,
            activePlans: [plan]
        )
        
        // Then
        XCTAssertEqual(adherence.offDietMeals.count, 1)
        XCTAssertEqual(adherence.offDietCalories, 500)
        XCTAssertFalse(adherence.hasPerfectAdherence)
    }
    
    func testAdherenceCompletionRateCalculation() {
        // Given
        let scheduledMeals = [
            ScheduledMeal(name: "Meal 1", category: .breakfast, time: Date(), daysOfWeek: [2]),
            ScheduledMeal(name: "Meal 2", category: .lunch, time: Date(), daysOfWeek: [2]),
            ScheduledMeal(name: "Meal 3", category: .dinner, time: Date(), daysOfWeek: [2])
        ]
        let completedMealIds = [scheduledMeals[0].id, scheduledMeals[1].id]
        
        let data = DietAdherenceData(
            date: Date(),
            scheduledMeals: scheduledMeals,
            completedMeals: completedMealIds,
            missedMeals: [scheduledMeals[2]],
            offDietMeals: [],
            offDietCalories: 0
        )
        
        // Then
        XCTAssertEqual(data.completionRate, 2.0/3.0, accuracy: 0.01)
    }
}

