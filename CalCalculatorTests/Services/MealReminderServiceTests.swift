//
//  MealReminderServiceTests.swift
//  CalCalculatorTests
//
//  Unit tests for MealReminderService
//

import XCTest
@testable import playground
import SwiftData
import UserNotifications

@MainActor
final class MealReminderServiceTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    var dietRepository: DietPlanRepository!
    var mealRepository: MealRepository!
    var service: MealReminderService!
    
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
        dietRepository = DietPlanRepository(context: context)
        mealRepository = MealRepository(context: context)
        service = MealReminderService(repository: dietRepository, mealRepository: mealRepository)
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
        dietRepository = nil
        mealRepository = nil
        service = nil
    }
    
    func testSharedInstance() {
        // When
        let shared = MealReminderService.shared(context: context)
        
        // Then
        XCTAssertNotNil(shared)
    }
    
    func testHandleMealReminderNotification() {
        // Given
        let scheduledMealId = UUID()
        let userInfo: [AnyHashable: Any] = [
            "scheduledMealId": scheduledMealId.uuidString,
            "mealName": "Breakfast",
            "category": "breakfast"
        ]
        
        // When
        let action = service.handleMealReminderNotification(userInfo: userInfo)
        
        // Then
        XCTAssertNotNil(action)
        XCTAssertEqual(action?.scheduledMealId, scheduledMealId)
        XCTAssertEqual(action?.mealName, "Breakfast")
        XCTAssertEqual(action?.category, .breakfast)
    }
    
    func testHandleMealReminderNotificationInvalid() {
        // Given
        let userInfo: [AnyHashable: Any] = [:]
        
        // When
        let action = service.handleMealReminderNotification(userInfo: userInfo)
        
        // Then
        XCTAssertNil(action)
    }
    
    func testCancelAllReminders() async {
        // When - Should not throw
        await service.cancelAllReminders()
        
        // Then - No assertion needed, just verify it doesn't crash
    }
    
    func testCancelRemindersForScheduledMeal() async {
        // Given
        let plan = DietPlan(name: "Test Plan", isActive: true)
        try? dietRepository.saveDietPlan(plan)
        
        let meal = ScheduledMeal(
            name: "Breakfast",
            category: .breakfast,
            time: Date(),
            daysOfWeek: [2]
        )
        meal.dietPlan = plan
        try? dietRepository.saveScheduledMeal(meal)
        
        // When - Should not throw
        await service.cancelReminders(for: meal)
        
        // Then - No assertion needed, just verify it doesn't crash
    }
}

