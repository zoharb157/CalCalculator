//
//  DietAdherenceTests.swift
//  CalCalculatorTests
//
//  Unit tests for Diet Adherence tracking
//

import XCTest
@testable import playground
import SwiftData

final class DietAdherenceTests: XCTestCase {
    
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
    
    func testDietAdherenceCompletionRate() {
        // Given
        let data = DietAdherenceData(
            date: Date(),
            scheduledMeals: [
                ScheduledMeal(name: "Breakfast", category: .breakfast, time: Date(), daysOfWeek: [2]),
                ScheduledMeal(name: "Lunch", category: .lunch, time: Date(), daysOfWeek: [2])
            ],
            completedMeals: [UUID()], // Only 1 completed
            missedMeals: [],
            offDietMeals: [],
            offDietCalories: 0,
            goalAchievedMeals: [],
            goalMissedMeals: []
        )
        
        // Then
        XCTAssertEqual(data.completionRate, 0.5, accuracy: 0.01)
    }
    
    func testDietAdherencePerfectAdherence() {
        // Given
        let mealId = UUID()
        let data = DietAdherenceData(
            date: Date(),
            scheduledMeals: [
                ScheduledMeal(name: "Breakfast", category: .breakfast, time: Date(), daysOfWeek: [2])
            ],
            completedMeals: [mealId],
            missedMeals: [],
            offDietMeals: [],
            offDietCalories: 0,
            goalAchievedMeals: [mealId],
            goalMissedMeals: []
        )
        
        // Then
        XCTAssertTrue(data.hasPerfectAdherence)
    }
    
    func testDietAdherenceNotPerfectWithMissedMeals() {
        // Given
        let data = DietAdherenceData(
            date: Date(),
            scheduledMeals: [
                ScheduledMeal(name: "Breakfast", category: .breakfast, time: Date(), daysOfWeek: [2])
            ],
            completedMeals: [],
            missedMeals: [
                ScheduledMeal(name: "Breakfast", category: .breakfast, time: Date(), daysOfWeek: [2])
            ],
            offDietMeals: [],
            offDietCalories: 0,
            goalAchievedMeals: [],
            goalMissedMeals: []
        )
        
        // Then
        XCTAssertFalse(data.hasPerfectAdherence)
    }
    
    func testDietAdherenceNotPerfectWithOffDietMeals() {
        // Given
        let meal = Meal(name: "Off Diet Meal", timestamp: Date())
        let data = DietAdherenceData(
            date: Date(),
            scheduledMeals: [
                ScheduledMeal(name: "Breakfast", category: .breakfast, time: Date(), daysOfWeek: [2])
            ],
            completedMeals: [UUID()],
            missedMeals: [],
            offDietMeals: [meal],
            offDietCalories: 500,
            goalAchievedMeals: [],
            goalMissedMeals: []
        )
        
        // Then
        XCTAssertFalse(data.hasPerfectAdherence)
        XCTAssertEqual(data.offDietCalories, 500)
    }
    
    func testGetDietAdherence() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        try repository.saveDietPlan(plan)
        
        let scheduledMeal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: createDate(hour: 8, minute: 0),
            daysOfWeek: [2] // Monday
        )
        scheduledMeal.dietPlan = plan
        try repository.saveScheduledMeal(scheduledMeal)
        
        // Create a completed reminder
        let reminder = MealReminder(
            scheduledMealId: scheduledMeal.id,
            reminderDate: createDate(hour: 8, minute: 0),
            wasCompleted: true,
            completedMealId: UUID()
        )
        try repository.saveMealReminder(reminder)
        
        // When
        let adherence = try repository.getDietAdherence(
            for: createDate(hour: 8, minute: 0),
            activePlans: [plan]
        )
        
        // Then
        XCTAssertEqual(adherence.scheduledMeals.count, 1)
        XCTAssertEqual(adherence.completedMeals.count, 1)
        XCTAssertTrue(adherence.completionRate > 0)
    }
    
    func testGoalAchievementRate_AllAchieved() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        try repository.saveDietPlan(plan)
        
        let scheduledMeal1 = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [Calendar.current.component(.weekday, from: Date())]
        )
        scheduledMeal1.dietPlan = plan
        
        let scheduledMeal2 = ScheduledMeal(
            name: "Lunch",
            category: .lunch,
            time: Date(),
            daysOfWeek: [Calendar.current.component(.weekday, from: Date())]
        )
        scheduledMeal2.dietPlan = plan
        
        try repository.saveScheduledMeal(scheduledMeal1)
        try repository.saveScheduledMeal(scheduledMeal2)
        
        // Create reminders with goals achieved
        let reminder1 = MealReminder(
            scheduledMealId: scheduledMeal1.id,
            reminderDate: Date(),
            wasCompleted: true,
            completedMealId: UUID(),
            completedAt: Date(),
            goalAchieved: true,
            goalDeviation: 0.05
        )
        
        let reminder2 = MealReminder(
            scheduledMealId: scheduledMeal2.id,
            reminderDate: Date(),
            wasCompleted: true,
            completedMealId: UUID(),
            completedAt: Date(),
            goalAchieved: true,
            goalDeviation: 0.10
        )
        
        try repository.saveMealReminder(reminder1)
        try repository.saveMealReminder(reminder2)
        
        // When
        let adherence = try repository.getDietAdherence(
            for: Date(),
            activePlans: [plan]
        )
        
        // Then
        XCTAssertEqual(adherence.completedMeals.count, 2)
        XCTAssertEqual(adherence.goalAchievedMeals.count, 2)
        XCTAssertEqual(adherence.goalMissedMeals.count, 0)
        XCTAssertEqual(adherence.goalAchievementRate, 1.0, accuracy: 0.01)
    }
    
    func testGoalAchievementRate_PartialAchievement() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        try repository.saveDietPlan(plan)
        
        let scheduledMeal1 = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [Calendar.current.component(.weekday, from: Date())]
        )
        scheduledMeal1.dietPlan = plan
        
        let scheduledMeal2 = ScheduledMeal(
            name: "Lunch",
            category: .lunch,
            time: Date(),
            daysOfWeek: [Calendar.current.component(.weekday, from: Date())]
        )
        scheduledMeal2.dietPlan = plan
        
        try repository.saveScheduledMeal(scheduledMeal1)
        try repository.saveScheduledMeal(scheduledMeal2)
        
        // Create reminders - one achieved, one missed
        let reminder1 = MealReminder(
            scheduledMealId: scheduledMeal1.id,
            reminderDate: Date(),
            wasCompleted: true,
            completedMealId: UUID(),
            completedAt: Date(),
            goalAchieved: true,
            goalDeviation: 0.05
        )
        
        let reminder2 = MealReminder(
            scheduledMealId: scheduledMeal2.id,
            reminderDate: Date(),
            wasCompleted: true,
            completedMealId: UUID(),
            completedAt: Date(),
            goalAchieved: false,
            goalDeviation: 0.30
        )
        
        try repository.saveMealReminder(reminder1)
        try repository.saveMealReminder(reminder2)
        
        // When
        let adherence = try repository.getDietAdherence(
            for: Date(),
            activePlans: [plan]
        )
        
        // Then
        XCTAssertEqual(adherence.completedMeals.count, 2)
        XCTAssertEqual(adherence.goalAchievedMeals.count, 1)
        XCTAssertEqual(adherence.goalMissedMeals.count, 1)
        XCTAssertEqual(adherence.goalAchievementRate, 0.5, accuracy: 0.01)
    }
    
    func testHasPerfectAdherence_WithGoalMissed() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        try repository.saveDietPlan(plan)
        
        let scheduledMeal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [Calendar.current.component(.weekday, from: Date())]
        )
        scheduledMeal.dietPlan = plan
        try repository.saveScheduledMeal(scheduledMeal)
        
        // Create reminder with goal missed
        let reminder = MealReminder(
            scheduledMealId: scheduledMeal.id,
            reminderDate: Date(),
            wasCompleted: true,
            completedMealId: UUID(),
            completedAt: Date(),
            goalAchieved: false,
            goalDeviation: 0.25
        )
        try repository.saveMealReminder(reminder)
        
        // When
        let adherence = try repository.getDietAdherence(
            for: Date(),
            activePlans: [plan]
        )
        
        // Then
        XCTAssertFalse(adherence.hasPerfectAdherence) // Should be false because goal was missed
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

