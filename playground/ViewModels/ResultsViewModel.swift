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
        meal.items
    }
    
    // MARK: - Meal Editing
    
    func updateMealName(_ name: String) {
        meal.name = name
    }
    
    // MARK: - Item Editing
    
    func updateItemPortion(_ item: MealItem, newPortion: Double) {
        guard newPortion > 0 else { return }
        
        // Calculate scaling ratio
        let ratio = newPortion / item.originalPortion
        
        // Scale macros proportionally
        let baseCaloriesPerUnit = Double(item.calories) / (item.portion / item.originalPortion)
        let baseProteinPerUnit = item.proteinG / (item.portion / item.originalPortion)
        let baseCarbsPerUnit = item.carbsG / (item.portion / item.originalPortion)
        let baseFatPerUnit = item.fatG / (item.portion / item.originalPortion)
        
        item.calories = Int(baseCaloriesPerUnit * ratio)
        item.proteinG = baseProteinPerUnit * ratio
        item.carbsG = baseCarbsPerUnit * ratio
        item.fatG = baseFatPerUnit * ratio
        item.portion = newPortion
        
        HapticManager.shared.selection()
    }
    
    func deleteItem(_ item: MealItem) {
        meal.items.removeAll { $0.id == item.id }
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
