//
//  UserSettings.swift
//  playground
//
//  CalAI Clone - User preferences and settings
//

import Foundation
import SwiftUI

/// User settings and preferences stored in UserDefaults
@Observable
final class UserSettings {
    static let shared = UserSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let calorieGoal = "calorieGoal"
        static let proteinGoal = "proteinGoal"
        static let carbsGoal = "carbsGoal"
        static let fatGoal = "fatGoal"
        static let useMetricUnits = "useMetricUnits"
    }
    
    // MARK: - Properties
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }
    
    var calorieGoal: Int {
        didSet { defaults.set(calorieGoal, forKey: Keys.calorieGoal) }
    }
    
    var proteinGoal: Double {
        didSet { defaults.set(proteinGoal, forKey: Keys.proteinGoal) }
    }
    
    var carbsGoal: Double {
        didSet { defaults.set(carbsGoal, forKey: Keys.carbsGoal) }
    }
    
    var fatGoal: Double {
        didSet { defaults.set(fatGoal, forKey: Keys.fatGoal) }
    }
    
    var useMetricUnits: Bool {
        didSet { defaults.set(useMetricUnits, forKey: Keys.useMetricUnits) }
    }
    
    // MARK: - Computed Properties
    var macroGoals: MacroData {
        MacroData(
            calories: calorieGoal,
            proteinG: proteinGoal,
            carbsG: carbsGoal,
            fatG: fatGoal
        )
    }
    
    var remainingCalories: Int {
        calorieGoal
    }
    
    // MARK: - Initialization
    private init() {
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.calorieGoal = defaults.object(forKey: Keys.calorieGoal) as? Int ?? 2000
        self.proteinGoal = defaults.object(forKey: Keys.proteinGoal) as? Double ?? 150
        self.carbsGoal = defaults.object(forKey: Keys.carbsGoal) as? Double ?? 250
        self.fatGoal = defaults.object(forKey: Keys.fatGoal) as? Double ?? 65
        self.useMetricUnits = defaults.object(forKey: Keys.useMetricUnits) as? Bool ?? true
    }
    
    // MARK: - Methods
    func resetToDefaults() {
        calorieGoal = 2000
        proteinGoal = 150
        carbsGoal = 250
        fatGoal = 65
        useMetricUnits = true
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}
