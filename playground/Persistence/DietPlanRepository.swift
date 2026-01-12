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
    
    /// Creates a new diet plan.
    /// If the plan is marked as active, all other plans will be deactivated.
    /// - Parameters:
    ///   - name: The name of the diet plan
    ///   - description: Optional description
    ///   - isActive: Whether this plan should be active (default: true)
    ///   - dailyCalorieGoal: Optional daily calorie goal
    ///   - scheduledMeals: Array of meal data to create scheduled meals from
    /// - Returns: The created DietPlan
    /// - Throws: `DietPlanError.noMeals` if no meals are provided
    @discardableResult
    func createDietPlan(
        name: String,
        description: String?,
        isActive: Bool = true,
        dailyCalorieGoal: Int?,
        scheduledMeals mealData: [(name: String, category: MealCategory, time: Date, daysOfWeek: [Int])]
    ) throws -> DietPlan {
        guard !mealData.isEmpty else {
            throw DietPlanError.noMeals
        }
        
        print("🍽️ [DietPlanRepository] Creating diet plan: '\(name)' with \(mealData.count) meals, isActive: \(isActive)")
        
        // If this plan will be active, deactivate all existing active plans first
        if isActive {
            try deactivateAllPlans()
        }
        
        // Create fresh ScheduledMeal objects (not passed in from outside)
        let meals = mealData.map { data in
            ScheduledMeal(
                name: data.name,
                category: data.category,
                time: data.time,
                daysOfWeek: data.daysOfWeek
            )
        }
        
        // Create the new plan
        let plan = DietPlan(
            name: name,
            planDescription: description,
            isActive: isActive,
            dailyCalorieGoal: dailyCalorieGoal,
            scheduledMeals: meals
        )
        
        context.insert(plan)
        try context.save()
        
        print("✅ [DietPlanRepository] Successfully saved diet plan with ID: \(plan.id)")
        
        // Verify the plan was saved by fetching it back
        if let savedPlan = try? fetchDietPlan(by: plan.id) {
            print("✅ [DietPlanRepository] Verified: Plan '\(savedPlan.name)' exists in database with \(savedPlan.scheduledMeals.count) meals")
        } else {
            print("⚠️ [DietPlanRepository] Warning: Could not verify plan was saved!")
        }
        
        return plan
    }
    
    /// Updates an existing diet plan.
    /// If the plan is being set to active, all other plans will be deactivated.
    /// - Parameters:
    ///   - plan: The plan to update
    ///   - name: New name
    ///   - description: New description
    ///   - isActive: Whether this plan should be active
    ///   - dailyCalorieGoal: New calorie goal
    ///   - scheduledMeals: New array of meal data
    /// - Throws: `DietPlanError.noMeals` if no meals are provided
    func updateDietPlan(
        _ plan: DietPlan,
        name: String,
        description: String?,
        isActive: Bool,
        dailyCalorieGoal: Int?,
        scheduledMeals mealData: [(name: String, category: MealCategory, time: Date, daysOfWeek: [Int])]
    ) throws {
        guard !mealData.isEmpty else {
            throw DietPlanError.noMeals
        }
        
        // If activating this plan, deactivate others first
        if isActive {
            try deactivateAllPlans(except: plan.id)
        }
        
        // Delete old scheduled meals
        for meal in plan.scheduledMeals {
            context.delete(meal)
        }
        
        // Create new scheduled meals
        let meals = mealData.map { data in
            ScheduledMeal(
                name: data.name,
                category: data.category,
                time: data.time,
                daysOfWeek: data.daysOfWeek
            )
        }
        
        // Update plan properties
        plan.name = name
        plan.planDescription = description
        plan.isActive = isActive
        plan.dailyCalorieGoal = dailyCalorieGoal
        plan.scheduledMeals = meals
        
        try context.save()
    }
    
    /// Activates a specific plan and deactivates all others.
    /// - Parameter plan: The plan to activate
    func activatePlan(_ plan: DietPlan) throws {
        try deactivateAllPlans(except: plan.id)
        plan.isActive = true
        try context.save()
    }
    
    /// Deactivates a specific plan.
    /// - Parameter plan: The plan to deactivate
    func deactivatePlan(_ plan: DietPlan) throws {
        plan.isActive = false
        try context.save()
    }
    
    /// Deactivates all plans except the one with the given ID.
    /// - Parameter exceptId: Optional ID of plan to keep active
    private func deactivateAllPlans(except exceptId: UUID? = nil) throws {
        let allPlans = try fetchAllDietPlans()
        for existingPlan in allPlans {
            if existingPlan.id != exceptId && existingPlan.isActive {
                existingPlan.isActive = false
            }
        }
        // Save immediately to ensure deactivation persists
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
        
        // Create a lookup dictionary for meals by ID
        let mealsById = Dictionary(uniqueKeysWithValues: actualMeals.map { ($0.id, $0) })
        
        // Calculate which scheduled meals were completed and goal achievement
        var completedMeals: [UUID] = []
        var missedMeals: [ScheduledMeal] = []
        var goalAchievedMeals: [UUID] = []
        var goalMissedMeals: [UUID] = []
        var completedMealDetails: [UUID: CompletedMealInfo] = [:]
        
        for scheduledMeal in scheduledMeals {
            // Check if there's a reminder that marks this as completed
            let reminder = reminders.first { $0.scheduledMealId == scheduledMeal.id && $0.wasCompleted }
            
            if let reminder = reminder, let completedMealId = reminder.completedMealId {
                completedMeals.append(scheduledMeal.id)
                
                // Look up the actual meal to get details
                if let actualMeal = mealsById[completedMealId] {
                    completedMealDetails[scheduledMeal.id] = CompletedMealInfo(from: actualMeal)
                }
                
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
                let _ = calendar.component(.minute, from: scheduledTime)
                
                let matchingMeal = actualMeals.first { meal in
                    let mealHour = calendar.component(.hour, from: meal.timestamp)
                    let _ = calendar.component(.minute, from: meal.timestamp)
                    // Consider it a match if within 2 hours of scheduled time
                    let hourDiff = abs(mealHour - scheduledHour)
                    return hourDiff <= 2 && meal.category == scheduledMeal.category
                }
                
                if let meal = matchingMeal {
                    completedMeals.append(scheduledMeal.id)
                    
                    // Store the meal details for display
                    completedMealDetails[scheduledMeal.id] = CompletedMealInfo(from: meal)
                    
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
        let _ = Set(scheduledMeals.map { $0.id })
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
            goalMissedMeals: goalMissedMeals,
            completedMealDetails: completedMealDetails
        )
    }
}

// MARK: - Diet Plan Errors

enum DietPlanError: LocalizedError {
    case noMeals
    
    var errorDescription: String? {
        switch self {
        case .noMeals:
            return "A diet plan must have at least one scheduled meal."
        }
    }
}

/// Information about a completed meal for display purposes
struct CompletedMealInfo {
    let mealId: UUID
    let mealName: String
    let calories: Int
    let foodItemsSummary: String // e.g., "Eggs, Toast, Coffee"
    
    /// Create a formatted display string (e.g., "Eggs, Toast • 450 cal")
    var displayString: String {
        if foodItemsSummary.isEmpty {
            return "\(calories) cal"
        }
        return "\(foodItemsSummary) • \(calories) cal"
    }
    
    /// Create from a Meal object
    init(from meal: Meal) {
        self.mealId = meal.id
        self.mealName = meal.name
        self.calories = meal.totalCalories
        
        // Get first 3 food items for summary
        let itemsArray = Array(meal.items)
        let itemNames = itemsArray.prefix(3).map { $0.name }
        if itemsArray.count > 3 {
            self.foodItemsSummary = itemNames.joined(separator: ", ") + "..."
        } else {
            self.foodItemsSummary = itemNames.joined(separator: ", ")
        }
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
    let completedMealDetails: [UUID: CompletedMealInfo] // Maps scheduledMealId to meal details
    
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

