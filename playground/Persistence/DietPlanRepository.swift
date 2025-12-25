//
//  DietPlanRepository.swift
//  playground
//
//  Repository for diet plan operations
//

import Foundation
import SwiftData

/// Repository for managing diet plan operations
final class DietPlanRepository {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Diet Plan Operations
    
    func saveDietPlan(_ plan: DietPlan) throws {
        context.insert(plan)
        try context.save()
    }
    
    func deleteDietPlan(_ plan: DietPlan) throws {
        context.delete(plan)
        try context.save()
    }
    
    func fetchAllDietPlans() throws -> [DietPlan] {
        let descriptor = FetchDescriptor<DietPlan>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    func fetchActiveDietPlans() throws -> [DietPlan] {
        let descriptor = FetchDescriptor<DietPlan>(
            predicate: #Predicate<DietPlan> { plan in
                plan.isActive == true
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    func fetchDietPlan(by id: UUID) throws -> DietPlan? {
        let descriptor = FetchDescriptor<DietPlan>(
            predicate: #Predicate<DietPlan> { plan in
                plan.id == id
            }
        )
        return try context.fetch(descriptor).first
    }
    
    // MARK: - Scheduled Meal Operations
    
    func saveScheduledMeal(_ meal: ScheduledMeal) throws {
        context.insert(meal)
        try context.save()
    }
    
    func deleteScheduledMeal(_ meal: ScheduledMeal) throws {
        context.delete(meal)
        try context.save()
    }
    
    func fetchScheduledMeals(for date: Date) throws -> [ScheduledMeal] {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: date)
        
        let descriptor = FetchDescriptor<ScheduledMeal>(
            predicate: #Predicate<ScheduledMeal> { meal in
                // Check if meal is scheduled for this day
                // Note: SwiftData doesn't support array contains directly, so we'll filter in memory
                meal.daysOfWeek.contains(dayOfWeek)
            }
        )
        
        // Note: Since SwiftData predicate doesn't support array.contains well,
        // we fetch all and filter in memory
        let allMeals = try context.fetch(FetchDescriptor<ScheduledMeal>())
        return allMeals.filter { $0.daysOfWeek.contains(dayOfWeek) }
    }
    
    // MARK: - Meal Template Operations
    
    func saveMealTemplate(_ template: MealTemplate) throws {
        context.insert(template)
        try context.save()
    }
    
    func deleteMealTemplate(_ template: MealTemplate) throws {
        context.delete(template)
        try context.save()
    }
    
    func fetchMealTemplate(by id: UUID) throws -> MealTemplate? {
        let descriptor = FetchDescriptor<MealTemplate>(
            predicate: #Predicate<MealTemplate> { template in
                template.id == id
            }
        )
        return try context.fetch(descriptor).first
    }
    
    // MARK: - Meal Reminder Operations
    
    func saveMealReminder(_ reminder: MealReminder) throws {
        context.insert(reminder)
        try context.save()
    }
    
    func fetchMealReminders(for date: Date) throws -> [MealReminder] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<MealReminder>(
            predicate: #Predicate<MealReminder> { reminder in
                reminder.reminderDate >= startOfDay && reminder.reminderDate < endOfDay
            },
            sortBy: [SortDescriptor(\.reminderDate, order: .forward)]
        )
        return try context.fetch(descriptor)
    }
    
    func fetchMealReminder(by scheduledMealId: UUID, for date: Date) throws -> MealReminder? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<MealReminder>(
            predicate: #Predicate<MealReminder> { reminder in
                reminder.scheduledMealId == scheduledMealId &&
                reminder.reminderDate >= startOfDay &&
                reminder.reminderDate < endOfDay
            }
        )
        return try context.fetch(descriptor).first
    }
    
    func updateMealReminderCompletion(_ reminder: MealReminder, completedMealId: UUID?) throws {
        reminder.wasCompleted = true
        reminder.completedMealId = completedMealId
        reminder.completedAt = Date()
        try context.save()
    }
    
    /// Update meal reminder with goal achievement information
    func updateMealReminderGoalAchievement(
        _ reminder: MealReminder,
        goalAchieved: Bool,
        goalDeviation: Double
    ) throws {
        reminder.goalAchieved = goalAchieved
        reminder.goalDeviation = goalDeviation
        try context.save()
    }
    
    /// Compare actual meal with planned meal template to determine goal achievement
    /// - Parameters:
    ///   - actualMeal: The meal that was actually consumed
    ///   - scheduledMeal: The scheduled meal with its template
    /// - Returns: A tuple with (achieved: Bool, deviation: Double) where deviation is the percentage difference
    func evaluateMealGoalAchievement(
        actualMeal: Meal,
        scheduledMeal: ScheduledMeal
    ) -> (achieved: Bool, deviation: Double) {
        guard let template = scheduledMeal.mealTemplate else {
            // No template means no specific goal - consider it achieved if meal was logged
            return (true, 0.0)
        }
        
        let expectedCalories = template.expectedCalories
        guard expectedCalories > 0 else {
            // Avoid division by zero
            return (true, 0.0)
        }
        
        let actualCalories = actualMeal.totalCalories
        
        // Calculate deviation percentage
        let deviation = Double(actualCalories - expectedCalories) / Double(expectedCalories)
        
        // Goal is achieved if within 20% of expected calories
        // Allow some flexibility: -20% to +20% is acceptable
        let achieved = abs(deviation) <= 0.20
        
        return (achieved, deviation)
    }
    
    // MARK: - Diet Adherence Tracking
    
    /// Get diet adherence data for a specific date
    func getDietAdherence(for date: Date, activePlans: [DietPlan]) throws -> DietAdherenceData {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: date)
        
        // Get all scheduled meals for this day
        var scheduledMeals: [ScheduledMeal] = []
        for plan in activePlans {
            scheduledMeals.append(contentsOf: plan.scheduledMeals(for: dayOfWeek))
        }
        
        // Get reminders for this date
        let reminders = try fetchMealReminders(for: date)
        
        // Get actual meals logged for this date
        let mealRepository = MealRepository(context: context)
        let actualMeals = try mealRepository.fetchMeals(for: date)
        
        // Calculate which scheduled meals were completed and goal achievement
        var completedMeals: [UUID] = []
        var missedMeals: [ScheduledMeal] = []
        var goalAchievedMeals: [UUID] = []
        var goalMissedMeals: [UUID] = []
        
        for scheduledMeal in scheduledMeals {
            // Check if there's a reminder that marks this as completed
            let reminder = reminders.first { $0.scheduledMealId == scheduledMeal.id && $0.wasCompleted }
            
            if let reminder = reminder, reminder.completedMealId != nil {
                completedMeals.append(scheduledMeal.id)
                
                // Check goal achievement from reminder
                if let goalAchieved = reminder.goalAchieved {
                    if goalAchieved {
                        goalAchievedMeals.append(scheduledMeal.id)
                    } else {
                        goalMissedMeals.append(scheduledMeal.id)
                    }
                }
            } else {
                // Check if there's a meal logged around the scheduled time
                let scheduledTime = scheduledMeal.time
                let scheduledHour = calendar.component(.hour, from: scheduledTime)
                let scheduledMinute = calendar.component(.minute, from: scheduledTime)
                
                let matchingMeal = actualMeals.first { meal in
                    let mealHour = calendar.component(.hour, from: meal.timestamp)
                    let mealMinute = calendar.component(.minute, from: meal.timestamp)
                    // Consider it a match if within 2 hours of scheduled time
                    let hourDiff = abs(mealHour - scheduledHour)
                    return hourDiff <= 2 && meal.category == scheduledMeal.category
                }
                
                if let meal = matchingMeal {
                    completedMeals.append(scheduledMeal.id)
                    
                    // Evaluate goal achievement for this meal
                    let (achieved, _) = evaluateMealGoalAchievement(
                        actualMeal: meal,
                        scheduledMeal: scheduledMeal
                    )
                    if achieved {
                        goalAchievedMeals.append(scheduledMeal.id)
                    } else {
                        goalMissedMeals.append(scheduledMeal.id)
                    }
                } else {
                    missedMeals.append(scheduledMeal)
                }
            }
        }
        
        // Calculate off-diet calories (meals not part of scheduled meals)
        let scheduledMealIds = Set(scheduledMeals.map { $0.id })
        let offDietMeals = actualMeals.filter { meal in
            // Check if meal matches any scheduled meal
            !scheduledMeals.contains { scheduled in
                let mealHour = calendar.component(.hour, from: meal.timestamp)
                let scheduledHour = calendar.component(.hour, from: scheduled.time)
                let hourDiff = abs(mealHour - scheduledHour)
                return hourDiff <= 2 && meal.category == scheduled.category
            }
        }
        
        let offDietCalories = offDietMeals.reduce(0) { $0 + $1.totalCalories }
        
        return DietAdherenceData(
            date: date,
            scheduledMeals: scheduledMeals,
            completedMeals: completedMeals,
            missedMeals: missedMeals,
            offDietMeals: offDietMeals,
            offDietCalories: offDietCalories,
            goalAchievedMeals: goalAchievedMeals,
            goalMissedMeals: goalMissedMeals
        )
    }
}

/// Data structure for diet adherence tracking
struct DietAdherenceData {
    let date: Date
    let scheduledMeals: [ScheduledMeal]
    let completedMeals: [UUID] // IDs of completed scheduled meals
    let missedMeals: [ScheduledMeal]
    let offDietMeals: [Meal] // Meals logged outside of diet plan
    let offDietCalories: Int
    let goalAchievedMeals: [UUID] // IDs of meals where goal was achieved
    let goalMissedMeals: [UUID] // IDs of meals where goal was not achieved
    
    var completionRate: Double {
        guard !scheduledMeals.isEmpty else { return 1.0 }
        return Double(completedMeals.count) / Double(scheduledMeals.count)
    }
    
    var goalAchievementRate: Double {
        guard !completedMeals.isEmpty else { return 0.0 }
        return Double(goalAchievedMeals.count) / Double(completedMeals.count)
    }
    
    var hasPerfectAdherence: Bool {
        missedMeals.isEmpty && offDietMeals.isEmpty && goalMissedMeals.isEmpty
    }
}

