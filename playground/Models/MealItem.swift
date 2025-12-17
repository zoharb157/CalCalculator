//
//  MealItem.swift
//  playground
//
//  CalAI Clone - Individual food item within a meal
//

import Foundation
import SwiftData

/// Represents a single food item within a meal
@Model
final class MealItem {
    var id: UUID
    var name: String
    var portion: Double
    var unit: String
    var calories: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    
    /// Original portion for calculating scaling ratio
    var originalPortion: Double
    
    @Relationship(inverse: \Meal.items)
    var meal: Meal?
    
    init(
        id: UUID = UUID(),
        name: String,
        portion: Double,
        unit: String,
        calories: Int,
        proteinG: Double,
        carbsG: Double,
        fatG: Double
    ) {
        self.id = id
        self.name = name
        self.portion = portion
        self.unit = unit
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.originalPortion = portion
    }
    
    /// Macro data for this item
    var macros: MacroData {
        MacroData(
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG
        )
    }
    
    /// Recalculates macros when portion changes
    func updatePortion(to newPortion: Double) {
        guard originalPortion > 0 else { return }
        
        // Get base values per original portion
        let baseCaloriesPerUnit = Double(calories) / (portion / originalPortion)
        let baseProteinPerUnit = proteinG / (portion / originalPortion)
        let baseCarbsPerUnit = carbsG / (portion / originalPortion)
        let baseFatPerUnit = fatG / (portion / originalPortion)
        
        // Calculate new values
        let newRatio = newPortion / originalPortion
        calories = Int(baseCaloriesPerUnit * newRatio / (portion / originalPortion))
        proteinG = baseProteinPerUnit * newRatio / (portion / originalPortion)
        carbsG = baseCarbsPerUnit * newRatio / (portion / originalPortion)
        fatG = baseFatPerUnit * newRatio / (portion / originalPortion)
        
        portion = newPortion
    }
}

// MARK: - Codable DTO for API responses
struct MealItemDTO: Codable {
    let name: String
    let portion: Double
    let unit: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    
    enum CodingKeys: String, CodingKey {
        case name, portion, unit, calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
    }
    
    func toMealItem() -> MealItem {
        MealItem(
            name: name,
            portion: portion,
            unit: unit,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG
        )
    }
}
