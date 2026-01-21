//
//  MealSaveLimitManager.swift
//  playground
//
//  Manages free meal save limit for non-subscribed users
//

import Foundation

/// Manager for tracking free meal save usage
@MainActor
final class MealSaveLimitManager {
    static let shared = MealSaveLimitManager()
    
    private let userDefaults = UserDefaults.standard
    private let mealSaveCountKey = "free_meal_save_count"
    private let freeMealSaveLimit = 1 // One free meal save allowed
    
    private init() {}
    
    /// Get current meal save count
    var currentMealSaveCount: Int {
        userDefaults.integer(forKey: mealSaveCountKey)
    }
    
    /// Check if user can save a meal - always true (app is free)
    func canSaveMeal() -> Bool {
        return true
    }
    
    /// Record that a meal was saved
    /// Returns true if successfully recorded, false if limit already reached
    func recordMealSave() -> Bool {
        let current = currentMealSaveCount
        guard current < freeMealSaveLimit else {
            return false // Limit already reached
        }
        userDefaults.set(current + 1, forKey: mealSaveCountKey)
        // Note: UserDefaults auto-syncs, synchronize() is deprecated and not needed
        return true
    }
    
    /// Reset meal save count (for testing or subscription upgrade)
    func resetMealSaveCount() {
        userDefaults.removeObject(forKey: mealSaveCountKey)
        // Note: UserDefaults auto-syncs, synchronize() is deprecated and not needed
    }
    
    /// Get remaining free meal saves - unlimited (app is free)
    func remainingFreeMealSaves() -> Int {
        return Int.max
    }
}
