//
//  MealRepositoryPerformanceTests.swift
//  CalCalculatorTests
//
//  Performance tests for MealRepository
//

import XCTest
@testable import playground
import SwiftData

final class MealRepositoryPerformanceTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    var repository: MealRepository!
    
    override func setUpWithError() throws {
        let schema = Schema([Meal.self, MealItem.self, DaySummary.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        repository = MealRepository(context: context)
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
        repository = nil
    }
    
    func testSaveManyMealsPerformance() throws {
        // Given
        let meals = (1...100).map { index in
            let meal = Meal(name: "Meal \(index)", timestamp: Date())
            let item = MealItem(
                name: "Item \(index)",
                portion: 100,
                unit: "g",
                calories: 100,
                proteinG: 10,
                carbsG: 20,
                fatG: 5
            )
            meal.items.append(item)
            return meal
        }
        
        // When
        measure {
            for meal in meals {
                try? repository.saveMeal(meal)
            }
        }
    }
    
    func testFetchMealsPerformance() throws {
        // Given - Create many meals first
        for i in 1...50 {
            let meal = Meal(name: "Meal \(i)", timestamp: Date())
            try repository.saveMeal(meal)
        }
        
        // When
        measure {
            _ = try? repository.fetchMeals()
        }
    }
    
    func testFetchTodaysMealsPerformance() throws {
        // Given - Create many meals for today
        let today = Date()
        for i in 1...50 {
            let meal = Meal(name: "Meal \(i)", timestamp: today)
            try repository.saveMeal(meal)
        }
        
        // When
        measure {
            _ = try? repository.fetchTodaysMeals()
        }
    }
}


