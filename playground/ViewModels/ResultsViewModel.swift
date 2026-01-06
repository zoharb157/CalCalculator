//
//  ResultsViewModel.swift
//  playground
//
//  CalAI Clone - View model for meal results editing
//

import SwiftUI

/// View model for editing meal analysis results
@MainActor
@Observable
final class ResultsViewModel {
    // MARK: - State
    var meal: Meal
    var isEditing = false
    var editingItemId: UUID?
    
    init(meal: Meal) {
        self.meal = meal
    }
    
    // MARK: - Computed Properties
    
    var totalMacros: MacroData {
        meal.totalMacros
    }
    
    var items: [MealItem] {
        // Safely access items relationship by creating a local copy first
        // This prevents InvalidFutureBackingData errors
        Array(meal.items)
    }
    
    // MARK: - Meal Editing
    
    func updateMealName(_ name: String) {
        meal.name = name
    }
    
    // MARK: - Item Editing
    
    func updateItemPortion(_ item: MealItem, newPortion: Double) {
        guard newPortion > 0 else { return }
        guard item.originalPortion > 0 else {
            print("⚠️ [ResultsViewModel] Cannot update portion: originalPortion is 0")
            return
        }
        
        // Calculate scaling ratio based on original portion
        // This is simpler and safer than the previous complex calculation
        let ratio = newPortion / item.originalPortion
        
        // Scale macros proportionally based on the ratio
        // If current portion differs from original, we need to account for that
        let currentRatio = item.portion > 0 ? item.portion / item.originalPortion : 1.0
        let baseCalories = Double(item.calories) / currentRatio
        let baseProtein = item.proteinG / currentRatio
        let baseCarbs = item.carbsG / currentRatio
        let baseFat = item.fatG / currentRatio
        
        // Apply new ratio
        item.calories = Int(baseCalories * ratio)
        item.proteinG = baseProtein * ratio
        item.carbsG = baseCarbs * ratio
        item.fatG = baseFat * ratio
        item.portion = newPortion
        
        HapticManager.shared.selection()
    }
    
    func deleteItem(_ item: MealItem) {
        // Safely access items relationship by creating a local copy first
        // Then filter and reassign to prevent InvalidFutureBackingData errors
        let itemsArray = Array(meal.items)
        meal.items = itemsArray.filter { $0.id != item.id }
        HapticManager.shared.impact(.light)
    }
    
    // MARK: - Static Methods for Portion Recalculation
    
    /// Recalculates macros based on portion change
    static func recalculateMacros(
        originalPortion: Double,
        newPortion: Double,
        originalMacros: MacroData
    ) -> MacroData {
        guard originalPortion > 0 else { return originalMacros }
        
        let ratio = newPortion / originalPortion
        return MacroData(
            calories: Int(Double(originalMacros.calories) * ratio),
            proteinG: originalMacros.proteinG * ratio,
            carbsG: originalMacros.carbsG * ratio,
            fatG: originalMacros.fatG * ratio
        )
    }
    
    /// Computes total macros from a list of items
    static func computeTotalMacros(from items: [MealItem]) -> MacroData {
        items.reduce(MacroData.zero) { result, item in
            result + item.macros
        }
    }
}
