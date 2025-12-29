//
//  MacroNutrients.swift
//  CaloriesCalculatorWidgets
//
//  Shared model for macro nutritional data used by the widget
//

import Foundation

/// Represents macronutrient data for widget display
/// This is a lightweight, Codable struct for App Group sharing
struct MacroNutrients: Codable, Equatable, Sendable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let calorieGoal: Int
    let proteinGoal: Int
    let carbsGoal: Int
    let fatsGoal: Int
    
    // MARK: - Computed Properties
    
    var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(Double(calories) / Double(calorieGoal), 1.0)
    }
    
    var proteinProgress: Double {
        guard proteinGoal > 0 else { return 0 }
        return min(Double(protein) / Double(proteinGoal), 1.0)
    }
    
    var carbsProgress: Double {
        guard carbsGoal > 0 else { return 0 }
        return min(Double(carbs) / Double(carbsGoal), 1.0)
    }
    
    var fatsProgress: Double {
        guard fatsGoal > 0 else { return 0 }
        return min(Double(fats) / Double(fatsGoal), 1.0)
    }
    
    var remainingCalories: Int {
        max(0, calorieGoal - calories)
    }
    
    var caloriePercentage: Int {
        guard calorieGoal > 0 else { return 0 }
        return min(Int((Double(calories) / Double(calorieGoal)) * 100), 100)
    }
    
    var proteinPercentage: Int {
        guard proteinGoal > 0 else { return 0 }
        return min(Int((Double(protein) / Double(proteinGoal)) * 100), 100)
    }
    
    var carbsPercentage: Int {
        guard carbsGoal > 0 else { return 0 }
        return min(Int((Double(carbs) / Double(carbsGoal)) * 100), 100)
    }
    
    var fatsPercentage: Int {
        guard fatsGoal > 0 else { return 0 }
        return min(Int((Double(fats) / Double(fatsGoal)) * 100), 100)
    }
    
    // MARK: - Initialization
    
    init(
        calories: Int = 0,
        protein: Int = 0,
        carbs: Int = 0,
        fats: Int = 0,
        calorieGoal: Int = 2000,
        proteinGoal: Int = 150,
        carbsGoal: Int = 250,
        fatsGoal: Int = 65
    ) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.calorieGoal = calorieGoal
        self.proteinGoal = proteinGoal
        self.carbsGoal = carbsGoal
        self.fatsGoal = fatsGoal
    }
    
    // MARK: - Static Properties
    
    static let empty = MacroNutrients()
    
    static let placeholder = MacroNutrients(
        calories: 1250,
        protein: 85,
        carbs: 140,
        fats: 45,
        calorieGoal: 2000,
        proteinGoal: 150,
        carbsGoal: 250,
        fatsGoal: 65
    )
}

// MARK: - Macro Type Enum

enum MacroType: String, CaseIterable, Identifiable {
    case calories
    case protein
    case carbs
    case fats
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .calories: return "Calories"
        case .protein: return "Protein"
        case .carbs: return "Carbs"
        case .fats: return "Fats"
        }
    }
    
    var shortName: String {
        switch self {
        case .calories: return "Cal"
        case .protein: return "Pro"
        case .carbs: return "Carb"
        case .fats: return "Fat"
        }
    }
    
    var unit: String {
        switch self {
        case .calories: return "kcal"
        case .protein, .carbs, .fats: return "g"
        }
    }
    
    func value(from macros: MacroNutrients) -> Int {
        switch self {
        case .calories: return macros.calories
        case .protein: return macros.protein
        case .carbs: return macros.carbs
        case .fats: return macros.fats
        }
    }
    
    func goal(from macros: MacroNutrients) -> Int {
        switch self {
        case .calories: return macros.calorieGoal
        case .protein: return macros.proteinGoal
        case .carbs: return macros.carbsGoal
        case .fats: return macros.fatsGoal
        }
    }
    
    func progress(from macros: MacroNutrients) -> Double {
        switch self {
        case .calories: return macros.calorieProgress
        case .protein: return macros.proteinProgress
        case .carbs: return macros.carbsProgress
        case .fats: return macros.fatsProgress
        }
    }
    
    func percentage(from macros: MacroNutrients) -> Int {
        switch self {
        case .calories: return macros.caloriePercentage
        case .protein: return macros.proteinPercentage
        case .carbs: return macros.carbsPercentage
        case .fats: return macros.fatsPercentage
        }
    }
}
