//
//  PersistenceController.swift
//  playground
//
//  CalAI Clone - SwiftData persistence management
//

import Foundation
import SwiftData

/// Manages SwiftData model container and context
@MainActor
final class PersistenceController {
    static let shared = PersistenceController()
    
    let container: ModelContainer
    
    var mainContext: ModelContext {
        container.mainContext
    }
    
    private init() {
        let schema = Schema([
            Meal.self,
            MealItem.self,
            DaySummary.self,
            WeightEntry.self,
            Exercise.self,
            DietPlan.self,
            ScheduledMeal.self,
            MealTemplate.self,
            MealReminder.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    /// Creates an in-memory container for previews and testing
    static func preview() -> PersistenceController {
        let controller = PersistenceController.inMemory()
        return controller
    }
    
    private static func inMemory() -> PersistenceController {
        let instance = PersistenceController(inMemory: true)
        return instance
    }
    
    private init(inMemory: Bool) {
        let schema = Schema([
            Meal.self,
            MealItem.self,
            DaySummary.self,
            WeightEntry.self,
            Exercise.self,
            DietPlan.self,
            ScheduledMeal.self,
            MealTemplate.self,
            MealReminder.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true
        )
        
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
