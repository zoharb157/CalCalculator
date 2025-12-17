//
//  MealRepository.swift
//  playground
//
//  CalAI Clone - Repository for meal data operations
//

import Foundation
import SwiftData

/// Repository for managing meal data operations
@MainActor
final class MealRepository {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Meal Operations
    
    func saveMeal(_ meal: Meal) throws {
        context.insert(meal)
        try context.save()
        
        // Update or create day summary
        try updateDaySummary(for: meal.timestamp, adding: meal)
    }
    
    func deleteMeal(_ meal: Meal) throws {
        // Update day summary before deletion
        try updateDaySummary(for: meal.timestamp, removing: meal)
        
        context.delete(meal)
        try context.save()
    }
    
    func fetchMeals(for date: Date? = nil) throws -> [Meal] {
        var descriptor = FetchDescriptor<Meal>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        if let date = date {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            descriptor.predicate = #Predicate<Meal> { meal in
                meal.timestamp >= startOfDay && meal.timestamp < endOfDay
            }
        }
        
        return try context.fetch(descriptor)
    }
    
    func fetchTodaysMeals() throws -> [Meal] {
        return try fetchMeals(for: Date())
    }
    
    func fetchMeal(by id: UUID) throws -> Meal? {
        let descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate<Meal> { meal in
                meal.id == id
            }
        )
        return try context.fetch(descriptor).first
    }
    
    func fetchRecentMeals(limit: Int = 10) throws -> [Meal] {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        var descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate<Meal> { meal in
                meal.timestamp >= startOfDay && meal.timestamp < endOfDay
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return try context.fetch(descriptor)
    }
    
    // MARK: - Day Summary Operations
    
    func fetchDaySummary(for date: Date) throws -> DaySummary? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let descriptor = FetchDescriptor<DaySummary>(
            predicate: #Predicate<DaySummary> { summary in
                summary.date == startOfDay
            }
        )
        
        return try context.fetch(descriptor).first
    }
    
    func fetchTodaySummary() throws -> DaySummary {
        if let summary = try fetchDaySummary(for: Date()) {
            return summary
        }
        
        // Create new summary for today
        let summary = DaySummary(date: Date())
        context.insert(summary)
        try context.save()
        return summary
    }
    
    func fetchAllDaySummaries() throws -> [DaySummary] {
        let descriptor = FetchDescriptor<DaySummary>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Fetch summaries for the current week (Sunday to Saturday)
    func fetchCurrentWeekSummaries() throws -> [Date: DaySummary] {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the start of the week (Sunday)
        let weekday = calendar.component(.weekday, from: today)
        guard let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: calendar.startOfDay(for: today)),
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else {
            return [:]
        }
        
        let descriptor = FetchDescriptor<DaySummary>(
            predicate: #Predicate<DaySummary> { summary in
                summary.date >= startOfWeek && summary.date < endOfWeek
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        
        let summaries = try context.fetch(descriptor)
        
        // Convert to dictionary keyed by date
        var result: [Date: DaySummary] = [:]
        for summary in summaries {
            let dayStart = calendar.startOfDay(for: summary.date)
            result[dayStart] = summary
        }
        
        return result
    }
    
    private func updateDaySummary(for date: Date, adding meal: Meal) throws {
        let summary = try fetchDaySummary(for: date) ?? {
            let newSummary = DaySummary(date: date)
            context.insert(newSummary)
            return newSummary
        }()
        
        summary.addMeal(meal)
        try context.save()
    }
    
    private func updateDaySummary(for date: Date, removing meal: Meal) throws {
        guard let summary = try fetchDaySummary(for: date) else { return }
        summary.removeMeal(meal)
        try context.save()
    }
    
    // MARK: - Data Management
    
    func deleteAllData() throws {
        try context.delete(model: Meal.self)
        try context.delete(model: MealItem.self)
        try context.delete(model: DaySummary.self)
        try context.save()
    }
    
    func exportAllMeals() throws -> Data {
        let meals = try fetchMeals()
        let exportData = meals.map { meal in
            ExportMeal(
                name: meal.name,
                timestamp: meal.timestamp,
                totalCalories: meal.totalCalories,
                macros: meal.totalMacros,
                items: meal.items.map { item in
                    ExportMealItem(
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
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(exportData)
    }
}

// MARK: - Export Models

struct ExportMeal: Codable {
    let name: String
    let timestamp: Date
    let totalCalories: Int
    let macros: MacroData
    let items: [ExportMealItem]
}

struct ExportMealItem: Codable {
    let name: String
    let portion: Double
    let unit: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
}
