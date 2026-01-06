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
    nonisolated var macros: MacroData {
        MacroData(
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG
        )
    }
    
    /// Recalculates macros when portion changes
    /// Safely handles division by zero and maintains accuracy
    func updatePortion(to newPortion: Double) {
        guard newPortion > 0 else { return }
        guard originalPortion > 0 else {
            print("⚠️ [MealItem] Cannot update portion: originalPortion is 0")
            return
        }
        
        // Calculate the ratio of new portion to original portion
        let newRatio = newPortion / originalPortion
        
        // Get the current ratio (how much the current portion differs from original)
        // If portion is 0, assume it's the same as original (ratio = 1.0)
        let currentRatio = portion > 0 ? portion / originalPortion : 1.0
        
        // Calculate base values (what they would be for the original portion)
        let baseCalories = Double(calories) / currentRatio
        let baseProtein = proteinG / currentRatio
        let baseCarbs = carbsG / currentRatio
        let baseFat = fatG / currentRatio
        
        // Apply the new ratio to get the new values
        calories = Int(baseCalories * newRatio)
        proteinG = baseProtein * newRatio
        carbsG = baseCarbs * newRatio
        fatG = baseFat * newRatio
        
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
