//
//  DietPlanRepositoryTests.swift
//  CalCalculatorTests
//
//  Unit tests for DietPlanRepository
//

import XCTest
@testable import playground
import SwiftData

final class DietPlanRepositoryTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    var repository: DietPlanRepository!
    
    override func setUpWithError() throws {
        let schema = Schema([
            DietPlan.self,
            ScheduledMeal.self,
            MealTemplate.self,
            MealReminder.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        repository = DietPlanRepository(context: context)
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
        repository = nil
    }
    
    func testSaveDietPlan() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        
        // When
        try repository.saveDietPlan(plan)
        
        // Then
        let plans = try repository.fetchAllDietPlans()
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.name, "Test Plan")
    }
    
    func testDeleteDietPlan() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        try repository.saveDietPlan(plan)
        
        // When
        try repository.deleteDietPlan(plan)
        
        // Then
        let plans = try repository.fetchAllDietPlans()
        XCTAssertTrue(plans.isEmpty)
    }
    
    func testFetchActiveDietPlans() throws {
        // Given
        let activePlan = DietPlan(name: "Active Plan", isActive: true)
        let inactivePlan = DietPlan(name: "Inactive Plan", isActive: false)
        
        try repository.saveDietPlan(activePlan)
        try repository.saveDietPlan(inactivePlan)
        
        // When
        let activePlans = try repository.fetchActiveDietPlans()
        
        // Then
        XCTAssertEqual(activePlans.count, 1)
        XCTAssertEqual(activePlans.first?.name, "Active Plan")
    }
    
    func testFetchDietPlanById() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        try repository.saveDietPlan(plan)
        let planId = plan.id
        
        // When
        let fetchedPlan = try repository.fetchDietPlan(by: planId)
        
        // Then
        XCTAssertNotNil(fetchedPlan)
        XCTAssertEqual(fetchedPlan?.name, "Test Plan")
    }
    
    func testSaveScheduledMeal() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        try repository.saveDietPlan(plan)
        
        let meal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2, 3, 4, 5, 6] // Mon-Fri
        )
        meal.dietPlan = plan
        
        // When
        try repository.saveScheduledMeal(meal)
        
        // Then
        XCTAssertEqual(plan.scheduledMeals.count, 1)
        XCTAssertEqual(plan.scheduledMeals.first?.name, "Breakfast")
    }
    
    func testSaveMealReminder() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        try repository.saveDietPlan(plan)
        
        let meal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2]
        )
        meal.dietPlan = plan
        try repository.saveScheduledMeal(meal)
        
        let reminder = MealReminder(
            scheduledMealId: meal.id,
            reminderDate: Date()
        )
        
        // When
        try repository.saveMealReminder(reminder)
        
        // Then
        let reminders = try repository.fetchMealReminders(for: Date())
        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(reminders.first?.scheduledMealId, meal.id)
    }
    
    func testFetchMealReminderByScheduledMealId() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        try repository.saveDietPlan(plan)
        
        let meal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2]
        )
        meal.dietPlan = plan
        try repository.saveScheduledMeal(meal)
        
        let reminder = MealReminder(
            scheduledMealId: meal.id,
            reminderDate: Date()
        )
        try repository.saveMealReminder(reminder)
        
        // When
        let fetchedReminder = try repository.fetchMealReminder(by: meal.id, for: Date())
        
        // Then
        XCTAssertNotNil(fetchedReminder)
        XCTAssertEqual(fetchedReminder?.scheduledMealId, meal.id)
    }
    
    func testUpdateMealReminderCompletion() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        try repository.saveDietPlan(plan)
        
        let meal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2]
        )
        meal.dietPlan = plan
        try repository.saveScheduledMeal(meal)
        
        let reminder = MealReminder(
            scheduledMealId: meal.id,
            reminderDate: Date()
        )
        try repository.saveMealReminder(reminder)
        let mealId = UUID()
        
        // When
        try repository.updateMealReminderCompletion(reminder, completedMealId: mealId)
        
        // Then
        XCTAssertTrue(reminder.wasCompleted)
        XCTAssertEqual(reminder.completedMealId, mealId)
        XCTAssertNotNil(reminder.completedAt)
    }
    
    // MARK: - Goal Achievement Tests
    
    func testEvaluateMealGoalAchievement_ExactMatch() throws {
        // Given
        let template = MealTemplate(
            name: "Oatmeal",
            templateItems: [
                TemplateMealItem(
                    name: "Oatmeal",
                    portion: 1.0,
                    unit: "cup",
                    calories: 300,
                    proteinG: 10,
                    carbsG: 50,
                    fatG: 5
                )
            ]
        )
        
        let scheduledMeal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2],
            mealTemplate: template
        )
        
        let actualMeal = Meal(
            name: "Oatmeal",
            timestamp: Date(),
            category: .breakfast,
            items: [
                MealItem(
                    name: "Oatmeal",
                    portion: 1.0,
                    unit: "cup",
                    calories: 300,
                    proteinG: 10,
                    carbsG: 50,
                    fatG: 5
                )
            ]
        )
        
        // When
        let (achieved, deviation) = repository.evaluateMealGoalAchievement(
            actualMeal: actualMeal,
            scheduledMeal: scheduledMeal
        )
        
        // Then
        XCTAssertTrue(achieved)
        XCTAssertEqual(deviation, 0.0, accuracy: 0.01)
    }
    
    func testEvaluateMealGoalAchievement_WithinTolerance() throws {
        // Given - 15% over goal (within 20% tolerance)
        let template = MealTemplate(
            name: "Oatmeal",
            templateItems: [
                TemplateMealItem(
                    name: "Oatmeal",
                    portion: 1.0,
                    unit: "cup",
                    calories: 300,
                    proteinG: 10,
                    carbsG: 50,
                    fatG: 5
                )
            ]
        )
        
        let scheduledMeal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2],
            mealTemplate: template
        )
        
        let actualMeal = Meal(
            name: "Oatmeal",
            timestamp: Date(),
            category: .breakfast,
            items: [
                MealItem(
                    name: "Oatmeal",
                    portion: 1.0,
                    unit: "cup",
                    calories: 345, // 15% over
                    proteinG: 11.5,
                    carbsG: 57.5,
                    fatG: 5.75
                )
            ]
        )
        
        // When
        let (achieved, deviation) = repository.evaluateMealGoalAchievement(
            actualMeal: actualMeal,
            scheduledMeal: scheduledMeal
        )
        
        // Then
        XCTAssertTrue(achieved)
        XCTAssertEqual(deviation, 0.15, accuracy: 0.01)
    }
    
    func testEvaluateMealGoalAchievement_OverTolerance() throws {
        // Given - 25% over goal (outside 20% tolerance)
        let template = MealTemplate(
            name: "Oatmeal",
            templateItems: [
                TemplateMealItem(
                    name: "Oatmeal",
                    portion: 1.0,
                    unit: "cup",
                    calories: 300,
                    proteinG: 10,
                    carbsG: 50,
                    fatG: 5
                )
            ]
        )
        
        let scheduledMeal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2],
            mealTemplate: template
        )
        
        let actualMeal = Meal(
            name: "Oatmeal",
            timestamp: Date(),
            category: .breakfast,
            items: [
                MealItem(
                    name: "Oatmeal",
                    portion: 1.0,
                    unit: "cup",
                    calories: 375, // 25% over
                    proteinG: 12.5,
                    carbsG: 62.5,
                    fatG: 6.25
                )
            ]
        )
        
        // When
        let (achieved, deviation) = repository.evaluateMealGoalAchievement(
            actualMeal: actualMeal,
            scheduledMeal: scheduledMeal
        )
        
        // Then
        XCTAssertFalse(achieved)
        XCTAssertEqual(deviation, 0.25, accuracy: 0.01)
    }
    
    func testEvaluateMealGoalAchievement_UnderTolerance() throws {
        // Given - 15% under goal (within 20% tolerance)
        let template = MealTemplate(
            name: "Oatmeal",
            templateItems: [
                TemplateMealItem(
                    name: "Oatmeal",
                    portion: 1.0,
                    unit: "cup",
                    calories: 300,
                    proteinG: 10,
                    carbsG: 50,
                    fatG: 5
                )
            ]
        )
        
        let scheduledMeal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2],
            mealTemplate: template
        )
        
        let actualMeal = Meal(
            name: "Oatmeal",
            timestamp: Date(),
            category: .breakfast,
            items: [
                MealItem(
                    name: "Oatmeal",
                    portion: 1.0,
                    unit: "cup",
                    calories: 255, // 15% under
                    proteinG: 8.5,
                    carbsG: 42.5,
                    fatG: 4.25
                )
            ]
        )
        
        // When
        let (achieved, deviation) = repository.evaluateMealGoalAchievement(
            actualMeal: actualMeal,
            scheduledMeal: scheduledMeal
        )
        
        // Then
        XCTAssertTrue(achieved)
        XCTAssertEqual(deviation, -0.15, accuracy: 0.01)
    }
    
    func testEvaluateMealGoalAchievement_NoTemplate() throws {
        // Given - scheduled meal without template
        let scheduledMeal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2],
            mealTemplate: nil
        )
        
        let actualMeal = Meal(
            name: "Breakfast",
            timestamp: Date(),
            category: .breakfast,
            items: []
        )
        
        // When
        let (achieved, deviation) = repository.evaluateMealGoalAchievement(
            actualMeal: actualMeal,
            scheduledMeal: scheduledMeal
        )
        
        // Then - should be considered achieved if no template
        XCTAssertTrue(achieved)
        XCTAssertEqual(deviation, 0.0, accuracy: 0.01)
    }
    
    func testUpdateMealReminderGoalAchievement() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        try repository.saveDietPlan(plan)
        
        let meal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2]
        )
        meal.dietPlan = plan
        try repository.saveScheduledMeal(meal)
        
        let reminder = MealReminder(
            scheduledMealId: meal.id,
            reminderDate: Date()
        )
        try repository.saveMealReminder(reminder)
        
        // When
        try repository.updateMealReminderGoalAchievement(
            reminder,
            goalAchieved: true,
            goalDeviation: 0.05
        )
        
        // Then
        XCTAssertEqual(reminder.goalAchieved, true)
        XCTAssertEqual(reminder.goalDeviation, 0.05, accuracy: 0.01)
    }
    
    func testGetDietAdherence_WithGoalAchievement() throws {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        try repository.saveDietPlan(plan)
        
        let template = MealTemplate(
            name: "Oatmeal",
            templateItems: [
                TemplateMealItem(
                    name: "Oatmeal",
                    portion: 1.0,
                    unit: "cup",
                    calories: 300,
                    proteinG: 10,
                    carbsG: 50,
                    fatG: 5
                )
            ]
        )
        
        let scheduledMeal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [Calendar.current.component(.weekday, from: Date())],
            mealTemplate: template
        )
        scheduledMeal.dietPlan = plan
        try repository.saveScheduledMeal(scheduledMeal)
        
        // Create a reminder with goal achievement
        let reminder = MealReminder(
            scheduledMealId: scheduledMeal.id,
            reminderDate: Date(),
            wasCompleted: true,
            completedMealId: UUID(),
            completedAt: Date(),
            goalAchieved: true,
            goalDeviation: 0.05
        )
        try repository.saveMealReminder(reminder)
        
        // When
        let adherence = try repository.getDietAdherence(
            for: Date(),
            activePlans: [plan]
        )
        
        // Then
        XCTAssertEqual(adherence.completedMeals.count, 1)
        XCTAssertEqual(adherence.goalAchievedMeals.count, 1)
        XCTAssertEqual(adherence.goalMissedMeals.count, 0)
        XCTAssertEqual(adherence.goalAchievementRate, 1.0, accuracy: 0.01)
    }
    
    func testGetDietAdherence_WithGoalMissed() throws {
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
        
        // Create a reminder with goal missed
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
        XCTAssertEqual(adherence.completedMeals.count, 1)
        XCTAssertEqual(adherence.goalAchievedMeals.count, 0)
        XCTAssertEqual(adherence.goalMissedMeals.count, 1)
        XCTAssertEqual(adherence.goalAchievementRate, 0.0, accuracy: 0.01)
    }
}

