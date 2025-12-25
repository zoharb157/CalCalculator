//
//  DietPlan.swift
//  playground
//
//  Diet plan with scheduled meals
//

import Foundation
import SwiftData

/// Represents a diet plan with scheduled meals
@Model
final class DietPlan: Identifiable {
    var id: UUID
    var name: String
    var planDescription: String? // Using planDescription to avoid conflict with NSObject.description
    var createdAt: Date
    var isActive: Bool
    
    @Relationship(deleteRule: .cascade)
    var scheduledMeals: [ScheduledMeal]
    
    init(
        id: UUID = UUID(),
        name: String,
        planDescription: String? = nil,
        createdAt: Date = Date(),
        isActive: Bool = true,
        scheduledMeals: [ScheduledMeal] = []
    ) {
        self.id = id
        self.name = name
        self.planDescription = planDescription
        self.createdAt = createdAt
        self.isActive = isActive
        self.scheduledMeals = scheduledMeals
    }
    
    /// Get scheduled meals for a specific day of week (1 = Sunday, 7 = Saturday)
    func scheduledMeals(for dayOfWeek: Int) -> [ScheduledMeal] {
        scheduledMeals.filter { $0.daysOfWeek.contains(dayOfWeek) }
    }
    
    /// Get all scheduled meals for today
    func todaysScheduledMeals() -> [ScheduledMeal] {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: Date())
        return scheduledMeals(for: dayOfWeek)
    }
}

/// Represents a meal that repeats on specific days and times
@Model
final class ScheduledMeal: Identifiable {
    var id: UUID
    var name: String
    var category: MealCategory
    var time: Date // Time of day (only hour/minute matter)
    var daysOfWeek: [Int] // 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    var mealTemplate: MealTemplate? // Optional template meal to use
    
    @Relationship(inverse: \DietPlan.scheduledMeals)
    var dietPlan: DietPlan?
    
    init(
        id: UUID = UUID(),
        name: String,
        category: MealCategory,
        time: Date,
        daysOfWeek: [Int] = [],
        mealTemplate: MealTemplate? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.mealTemplate = mealTemplate
    }
    
    /// Get formatted time string (e.g., "8:00 AM")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    /// Get day names for display (e.g., "Mon, Wed, Fri")
    var dayNames: String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return daysOfWeek.sorted().map { dayNames[$0 - 1] }.joined(separator: ", ")
    }
    
    /// Check if this meal is scheduled for today
    var isScheduledToday: Bool {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())
        return daysOfWeek.contains(today)
    }
    
    /// Get the next scheduled time for this meal
    func nextScheduledTime() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.component(.weekday, from: now)
        
        // Get time components
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        
        // Check if today is scheduled and time hasn't passed
        if daysOfWeek.contains(today) {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = hour
            components.minute = minute
            if let todayTime = calendar.date(from: components), todayTime > now {
                return todayTime
            }
        }
        
        // Find next scheduled day
        let sortedDays = daysOfWeek.sorted()
        for dayOffset in 1...7 {
            let checkDay = (today + dayOffset - 1) % 7 + 1
            if sortedDays.contains(checkDay) {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.day = (components.day ?? 0) + dayOffset
                components.hour = hour
                components.minute = minute
                return calendar.date(from: components)
            }
        }
        
        return nil
    }
}

/// Template meal that can be used for scheduled meals
@Model
final class MealTemplate: Identifiable {
    var id: UUID
    var name: String
    var notes: String?
    
    // Store items as encoded data to avoid relationship conflicts
    // We'll create new MealItems when creating a Meal from template
    @Attribute(.externalStorage) var templateItemsData: Data?
    
    init(
        id: UUID = UUID(),
        name: String,
        notes: String? = nil,
        templateItems: [TemplateMealItem] = []
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.templateItemsData = try? JSONEncoder().encode(templateItems)
    }
    
    /// Get template items
    var templateItems: [TemplateMealItem] {
        get {
            guard let data = templateItemsData,
                  let items = try? JSONDecoder().decode([TemplateMealItem].self, from: data) else {
                return []
            }
            return items
        }
        set {
            templateItemsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    /// Get expected total calories from template
    var expectedCalories: Int {
        templateItems.reduce(0) { $0 + $1.calories }
    }
    
    /// Create a Meal from this template
    func createMeal(at timestamp: Date, category: MealCategory) -> Meal {
        Meal(
            name: name,
            timestamp: timestamp,
            confidence: 1.0,
            notes: notes,
            category: category,
            items: templateItems.map { item in
                MealItem(
                    name: item.name,
                    portion: item.portion,
                    unit: item.unit,
                    calories: item.calories,
                    proteinG: item.proteinG,
                    carbsG: item.carbsG,
                    fatG: item.fatG
                )
            }
        )
    }
}

/// Value type for storing template meal items (to avoid relationship issues)
struct TemplateMealItem: Codable {
    var name: String
    var portion: Double
    var unit: String
    var calories: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    
    init(
        name: String,
        portion: Double,
        unit: String,
        calories: Int,
        proteinG: Double,
        carbsG: Double,
        fatG: Double
    ) {
        self.name = name
        self.portion = portion
        self.unit = unit
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }
    
    init(from mealItem: MealItem) {
        self.name = mealItem.name
        self.portion = mealItem.portion
        self.unit = mealItem.unit
        self.calories = mealItem.calories
        self.proteinG = mealItem.proteinG
        self.carbsG = mealItem.carbsG
        self.fatG = mealItem.fatG
    }
}

/// Tracks meal reminders and completion status
@Model
final class MealReminder: Identifiable {
    var id: UUID
    var scheduledMealId: UUID
    var reminderDate: Date
    var notificationId: String?
    var wasCompleted: Bool
    var completedMealId: UUID? // Reference to the actual Meal if completed
    var completedAt: Date?
    var goalAchieved: Bool? // Whether the meal goal was achieved (nil = not checked, true = achieved, false = not achieved)
    var goalDeviation: Double? // Percentage deviation from goal (e.g., 0.15 = 15% over)
    
    init(
        id: UUID = UUID(),
        scheduledMealId: UUID,
        reminderDate: Date,
        notificationId: String? = nil,
        wasCompleted: Bool = false,
        completedMealId: UUID? = nil,
        completedAt: Date? = nil,
        goalAchieved: Bool? = nil,
        goalDeviation: Double? = nil
    ) {
        self.id = id
        self.scheduledMealId = scheduledMealId
        self.reminderDate = reminderDate
        self.notificationId = notificationId
        self.wasCompleted = wasCompleted
        self.completedMealId = completedMealId
        self.completedAt = completedAt
        self.goalAchieved = goalAchieved
        self.goalDeviation = goalDeviation
    }
}

