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
        static let currentWeight = "currentWeight"
        static let targetWeight = "targetWeight"
        static let height = "height"
        static let lastWeightDate = "lastWeightDate"
        static let lastWeightPromptDate = "lastWeightPromptDate"
        static let debugOverrideSubscription = "debugOverrideSubscription"
        static let debugIsSubscribed = "debugIsSubscribed"
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
    
    var currentWeight: Double { // in kg
        didSet { defaults.set(currentWeight, forKey: Keys.currentWeight) }
    }
    
    var targetWeight: Double { // in kg
        didSet { defaults.set(targetWeight, forKey: Keys.targetWeight) }
    }
    
    var height: Double { // in cm
        didSet { defaults.set(height, forKey: Keys.height) }
    }
    
    var lastWeightDate: Date? {
        didSet { defaults.set(lastWeightDate, forKey: Keys.lastWeightDate) }
    }
    
    var lastWeightPromptDate: Date? {
        didSet { defaults.set(lastWeightPromptDate, forKey: Keys.lastWeightPromptDate) }
    }
    
    // MARK: - Debug Properties
    var debugOverrideSubscription: Bool {
        didSet { defaults.set(debugOverrideSubscription, forKey: Keys.debugOverrideSubscription) }
    }
    
    var debugIsSubscribed: Bool {
        didSet { defaults.set(debugIsSubscribed, forKey: Keys.debugIsSubscribed) }
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
    
    /// Days until next weight check
    var daysUntilNextWeightCheck: Int {
        guard let lastDate = lastWeightDate else { return 0 }
        let nextDate = Calendar.current.date(byAdding: .day, value: 7, to: lastDate) ?? Date()
        let days = Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day ?? 0
        return max(0, days)
    }
    
    /// Whether it's time to prompt for weight
    var shouldPromptForWeight: Bool {
        // If no weight has been set at all, don't prompt (let onboarding handle it)
        guard currentWeight > 0 else { return false }
        
        // If weight exists but no lastWeightDate, it means it came from onboarding
        // Set the date to today so we don't prompt immediately
        if lastWeightDate == nil && currentWeight > 0 {
            lastWeightDate = Date()
            return false
        }
        
        guard let lastDate = lastWeightDate else { return false }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        // Check if it's the first day of the week (Sunday = 1, Monday = 2)
        let isFirstDayOfWeek = weekday == 1 || weekday == 2
        
        // Check if 7 days have passed
        let daysSinceLastWeight = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        
        // Check if we already prompted today
        if let lastPromptDate = lastWeightPromptDate,
           calendar.isDateInToday(lastPromptDate) {
            return false
        }
        
        return isFirstDayOfWeek && daysSinceLastWeight >= 7
    }
    
    /// Calculate BMI
    var bmi: Double? {
        guard height > 0, currentWeight > 0 else { return nil }
        let heightInMeters = height / 100
        return currentWeight / (heightInMeters * heightInMeters)
    }
    
    /// BMI Category
    var bmiCategory: BMICategory? {
        guard let bmi = bmi else { return nil }
        return BMICategory.category(for: bmi)
    }
    
    /// Weight in display units
    var displayWeight: Double {
        useMetricUnits ? currentWeight : currentWeight * 2.20462
    }
    
    /// Weight unit string
    var weightUnit: String {
        useMetricUnits ? "kg" : "lbs"
    }
    
    /// Height in display units
    var displayHeight: Double {
        useMetricUnits ? height : height / 2.54
    }
    
    /// Height unit string
    var heightUnit: String {
        useMetricUnits ? "cm" : "in"
    }
    
    // MARK: - Initialization
    private init() {
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.calorieGoal = defaults.object(forKey: Keys.calorieGoal) as? Int ?? 2000
        self.proteinGoal = defaults.object(forKey: Keys.proteinGoal) as? Double ?? 150
        self.carbsGoal = defaults.object(forKey: Keys.carbsGoal) as? Double ?? 250
        self.fatGoal = defaults.object(forKey: Keys.fatGoal) as? Double ?? 65
        self.useMetricUnits = defaults.object(forKey: Keys.useMetricUnits) as? Bool ?? true
        self.currentWeight = defaults.object(forKey: Keys.currentWeight) as? Double ?? 70
        self.targetWeight = defaults.object(forKey: Keys.targetWeight) as? Double ?? 70
        self.height = defaults.object(forKey: Keys.height) as? Double ?? 170
        self.lastWeightDate = defaults.object(forKey: Keys.lastWeightDate) as? Date
        self.lastWeightPromptDate = defaults.object(forKey: Keys.lastWeightPromptDate) as? Date
        self.debugOverrideSubscription = defaults.bool(forKey: Keys.debugOverrideSubscription)
        self.debugIsSubscribed = defaults.bool(forKey: Keys.debugIsSubscribed)
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
    
    func updateWeight(_ weight: Double) {
        currentWeight = weight
        lastWeightDate = Date()
    }
    
    func markWeightPromptShown() {
        lastWeightPromptDate = Date()
    }
}

// MARK: - BMI Category

enum BMICategory: String, CaseIterable {
    case underweight = "Underweight"
    case normal = "Normal"
    case overweight = "Overweight"
    case obese = "Obese"
    
    static func category(for bmi: Double) -> BMICategory {
        switch bmi {
        case ..<18.5:
            return .underweight
        case 18.5..<25:
            return .normal
        case 25..<30:
            return .overweight
        default:
            return .obese
        }
    }
    
    var color: Color {
        switch self {
        case .underweight:
            return .blue
        case .normal:
            return .green
        case .overweight:
            return .orange
        case .obese:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .underweight:
            return "arrow.down.circle.fill"
        case .normal:
            return "checkmark.circle.fill"
        case .overweight:
            return "exclamationmark.circle.fill"
        case .obese:
            return "xmark.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .underweight:
            return "BMI below 18.5"
        case .normal:
            return "BMI 18.5 - 24.9"
        case .overweight:
            return "BMI 25 - 29.9"
        case .obese:
            return "BMI 30 or above"
        }
    }
}
