//
//  ExerciseSaveLimitManager.swift
//  playground
//
//  Manages free exercise save limit for non-subscribed users
//

import Foundation

/// Manager for tracking free exercise save usage
@MainActor
final class ExerciseSaveLimitManager {
    static let shared = ExerciseSaveLimitManager()
    
    private let userDefaults = UserDefaults.standard
    private let exerciseSaveCountKey = "free_exercise_save_count"
    private let freeExerciseSaveLimit = 1 // One free exercise save allowed
    
    private init() {}
    
    /// Get current exercise save count
    var currentExerciseSaveCount: Int {
        userDefaults.integer(forKey: exerciseSaveCountKey)
    }
    
    /// Check if user can save an exercise - always true (app is free)
    func canSaveExercise() -> Bool {
        return true
    }
    
    /// Record that an exercise was saved
    /// Returns true if successfully recorded, false if limit already reached
    func recordExerciseSave() -> Bool {
        let current = currentExerciseSaveCount
        guard current < freeExerciseSaveLimit else {
            return false // Limit already reached
        }
        userDefaults.set(current + 1, forKey: exerciseSaveCountKey)
        // Note: UserDefaults auto-syncs, synchronize() is deprecated and not needed
        return true
    }
    
    /// Reset exercise save count (for testing or subscription upgrade)
    func resetExerciseSaveCount() {
        userDefaults.removeObject(forKey: exerciseSaveCountKey)
        // Note: UserDefaults auto-syncs, synchronize() is deprecated and not needed
    }
    
    /// Get remaining free exercise saves - unlimited (app is free)
    func remainingFreeExerciseSaves() -> Int {
        return Int.max
    }
}
