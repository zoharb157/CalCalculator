//
//  DaySummary.swift
//  playground
//
//  CalAI Clone - Daily summary of nutrition intake
//

import Foundation
import SwiftData

/// Time range options for diet plan views
enum DietTimeRange: String, CaseIterable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    
    var localizedKey: String {
        switch self {
        case .today: return AppStrings.DietPlan.today
        case .week: return AppStrings.DietPlan.thisWeek
        case .month: return AppStrings.DietPlan.thisMonth
        }
    }
    
    var startDate: Date {
        let calendar = Calendar.current
        switch self {
        case .today:
            return calendar.startOfDay(for: Date())
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        }
    }
}

/// Represents a daily summary of nutritional intake
@Model
final class DaySummary {
    var id: UUID
    @Attribute(.unique) var date: Date
    var totalCalories: Int
    var totalProteinG: Double
    var totalCarbsG: Double
    var totalFatG: Double
    var mealCount: Int
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        totalCalories: Int = 0,
        totalProteinG: Double = 0,
        totalCarbsG: Double = 0,
        totalFatG: Double = 0,
        mealCount: Int = 0
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.totalCalories = totalCalories
        self.totalProteinG = totalProteinG
        self.totalCarbsG = totalCarbsG
        self.totalFatG = totalFatG
        self.mealCount = mealCount
    }
    
    var macros: MacroData {
        MacroData(
            calories: totalCalories,
            proteinG: totalProteinG,
            carbsG: totalCarbsG,
            fatG: totalFatG
        )
    }
    
    /// Add a meal's macros to the daily summary
    func addMeal(_ meal: Meal) {
        let mealMacros = meal.totalMacros
        totalCalories += mealMacros.calories
        totalProteinG += mealMacros.proteinG
        totalCarbsG += mealMacros.carbsG
        totalFatG += mealMacros.fatG
        mealCount += 1
    }
    
    /// Remove a meal's macros from the daily summary
    func removeMeal(_ meal: Meal) {
        let mealMacros = meal.totalMacros
        totalCalories = max(0, totalCalories - mealMacros.calories)
        totalProteinG = max(0, totalProteinG - mealMacros.proteinG)
        totalCarbsG = max(0, totalCarbsG - mealMacros.carbsG)
        totalFatG = max(0, totalFatG - mealMacros.fatG)
        mealCount = max(0, mealCount - 1)
    }
    
    /// Formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    /// Check if this summary is for today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}
