//
//  MockData.swift
//  CaloriesCalculatorWidgets
//
//  Mock data for widget previews
//

import Foundation

/// Mock data for widget previews
enum MockData {
    
    // MARK: - Standard Mock Data
    
    /// Mid-day progress - typical use case
    static let midDayProgress = MacroNutrients(
        calories: 1250,
        protein: 85,
        carbs: 140,
        fats: 45,
        calorieGoal: 2000,
        proteinGoal: 150,
        carbsGoal: 250,
        fatsGoal: 65
    )
    
    /// Morning - just started
    static let morningStart = MacroNutrients(
        calories: 320,
        protein: 25,
        carbs: 40,
        fats: 12,
        calorieGoal: 2000,
        proteinGoal: 150,
        carbsGoal: 250,
        fatsGoal: 65
    )
    
    /// Almost complete - near goals
    static let almostComplete = MacroNutrients(
        calories: 1850,
        protein: 142,
        carbs: 235,
        fats: 58,
        calorieGoal: 2000,
        proteinGoal: 150,
        carbsGoal: 250,
        fatsGoal: 65
    )
    
    /// Goals met
    static let goalsReached = MacroNutrients(
        calories: 2000,
        protein: 150,
        carbs: 250,
        fats: 65,
        calorieGoal: 2000,
        proteinGoal: 150,
        carbsGoal: 250,
        fatsGoal: 65
    )
    
    /// Empty - no food logged
    static let empty = MacroNutrients(
        calories: 0,
        protein: 0,
        carbs: 0,
        fats: 0,
        calorieGoal: 2000,
        proteinGoal: 150,
        carbsGoal: 250,
        fatsGoal: 65
    )
    
    /// High calorie goal (weight gain)
    static let highCalorieGoal = MacroNutrients(
        calories: 2100,
        protein: 130,
        carbs: 280,
        fats: 75,
        calorieGoal: 3000,
        proteinGoal: 180,
        carbsGoal: 350,
        fatsGoal: 100
    )
    
    /// Low calorie goal (weight loss)
    static let lowCalorieGoal = MacroNutrients(
        calories: 980,
        protein: 95,
        carbs: 80,
        fats: 35,
        calorieGoal: 1500,
        proteinGoal: 120,
        carbsGoal: 150,
        fatsGoal: 50
    )
    
    /// Over goals (exceeded)
    static let overGoals = MacroNutrients(
        calories: 2400,
        protein: 165,
        carbs: 290,
        fats: 80,
        calorieGoal: 2000,
        proteinGoal: 150,
        carbsGoal: 250,
        fatsGoal: 65
    )
}
