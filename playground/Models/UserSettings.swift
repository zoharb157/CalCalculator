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
        static let onboardingCompletedDate = "onboardingCompletedDate" // First day of app installation/onboarding completion
        static let calorieGoal = "calorieGoal"
        static let proteinGoal = "proteinGoal"
        static let carbsGoal = "carbsGoal"
        static let fatGoal = "fatGoal"
        static let useMetricUnits = "useMetricUnits"
        static let currentWeight = "currentWeight"
        static let targetWeight = "targetWeight"
        static let height = "height"
        static let gender = "gender"
        static let age = "age"
        static let birthdate = "birthdate"
        static let lastWeightDate = "lastWeightDate"
        static let lastWeightPromptDate = "lastWeightPromptDate"
        static let hasSeenDietWelcome = "hasSeenDietWelcome"
        static let subscriptionStatus = "subscriptionStatus"
        
        // Onboarding
        static let currentOnboardingStep = "currentOnboardingStep"
    }
    
    // MARK: - Properties
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }
    
    /// The date when onboarding was completed (first day of app installation)
    var onboardingCompletedDate: Date? {
        didSet { defaults.set(onboardingCompletedDate, forKey: Keys.onboardingCompletedDate) }
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
    
    var gender: String? { // "male" or "female"
        didSet {
            if let gender = gender {
                defaults.set(gender, forKey: Keys.gender)
                defaults.synchronize() // Ensure it's saved immediately
                print("✅ [UserSettings] Saved gender: \(gender)")
                
                // Verify it was actually saved
                let verifyGender = defaults.string(forKey: Keys.gender)
                if verifyGender == gender {
                    print("✅ [UserSettings] Verified gender in UserDefaults: '\(verifyGender ?? "nil")'")
                } else {
                    print("❌ [UserSettings] ERROR: Gender not found in UserDefaults after save! Expected: '\(gender)', Got: '\(verifyGender ?? "nil")'")
                }
            } else {
                defaults.removeObject(forKey: Keys.gender)
                defaults.synchronize()
                print("⚠️ [UserSettings] Removed gender")
            }
        }
    }
    
    var age: Int? { // in years
        didSet { defaults.set(age, forKey: Keys.age) }
    }
    
    var birthdate: Date? {
        didSet {
            defaults.set(birthdate, forKey: Keys.birthdate)
            defaults.synchronize() // Ensure it's saved immediately
            // Calculate age from birthdate
            if let birthdate = birthdate {
                let calendar = Calendar.current
                let ageComponents = calendar.dateComponents([.year], from: birthdate, to: Date())
                let calculatedAge = ageComponents.year
                self.age = calculatedAge
                print("✅ [UserSettings] Saved birthdate: \(birthdate), calculated age: \(calculatedAge ?? -1)")
                
                // Verify it was saved
                let verifyBirthdate = defaults.object(forKey: Keys.birthdate) as? Date
                if verifyBirthdate == birthdate {
                    print("✅ [UserSettings] Verified birthdate in UserDefaults")
                } else {
                    print("❌ [UserSettings] ERROR: Birthdate not found in UserDefaults after save!")
                }
            } else {
                print("⚠️ [UserSettings] Birthdate set to nil")
            }
        }
    }
    
    var lastWeightDate: Date? {
        didSet { defaults.set(lastWeightDate, forKey: Keys.lastWeightDate) }
    }
    
    var lastWeightPromptDate: Date? {
        didSet { defaults.set(lastWeightPromptDate, forKey: Keys.lastWeightPromptDate) }
    }
    
    var hasSeenDietWelcome: Bool {
        didSet { defaults.set(hasSeenDietWelcome, forKey: Keys.hasSeenDietWelcome) }
    }
    
    var currentOnboardingStep: Int? {
        get { defaults.object(forKey: Keys.currentOnboardingStep) as? Int }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Keys.currentOnboardingStep)
            } else {
                defaults.removeObject(forKey: Keys.currentOnboardingStep)
            }
        }
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
    
    /// Returns the preferred distance unit based on metric/imperial setting
    var preferredDistanceUnit: DistanceUnit {
        return useMetricUnits ? .kilometers : .miles
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
        self.onboardingCompletedDate = defaults.object(forKey: Keys.onboardingCompletedDate) as? Date
        self.calorieGoal = defaults.object(forKey: Keys.calorieGoal) as? Int ?? 2000
        self.proteinGoal = defaults.object(forKey: Keys.proteinGoal) as? Double ?? 150
        self.carbsGoal = defaults.object(forKey: Keys.carbsGoal) as? Double ?? 250
        self.fatGoal = defaults.object(forKey: Keys.fatGoal) as? Double ?? 65
        self.useMetricUnits = defaults.object(forKey: Keys.useMetricUnits) as? Bool ?? true
        self.currentWeight = defaults.object(forKey: Keys.currentWeight) as? Double ?? 70
        self.targetWeight = defaults.object(forKey: Keys.targetWeight) as? Double ?? 70
        self.height = defaults.object(forKey: Keys.height) as? Double ?? 170
        let loadedGender = defaults.string(forKey: Keys.gender)
        self.gender = loadedGender
        if let gender = loadedGender {
            print("✅ [UserSettings] Loaded gender from UserDefaults: \(gender)")
        } else {
            print("⚠️ [UserSettings] No gender found in UserDefaults")
        }
        let storedBirthdate = defaults.object(forKey: Keys.birthdate) as? Date
        self.birthdate = storedBirthdate
        // Initialize age: Always recalculate from birthdate if available, otherwise use stored age
        // This ensures age is always in sync with birthdate
        // Must do this after birthdate is initialized
        if let birthdate = storedBirthdate {
            // CRITICAL: Always recalculate age from birthdate to ensure it's current
            // The stored age may be outdated (e.g., if user's birthday passed since last save)
            let calendar = Calendar.current
            let ageComponents = calendar.dateComponents([.year], from: birthdate, to: Date())
            let calculatedAge = ageComponents.year
            self.age = calculatedAge
            if let age = calculatedAge {
                // Save the recalculated age to UserDefaults
                defaults.set(age, forKey: Keys.age)
                print("✅ [UserSettings] Calculated age from birthdate: \(age) years (recalculated on init)")
            } else {
                print("⚠️ [UserSettings] Could not calculate age from birthdate: \(birthdate)")
                // Fallback to stored age if calculation fails
                if let storedAge = defaults.object(forKey: Keys.age) as? Int {
                    self.age = storedAge
                    print("⚠️ [UserSettings] Using stored age as fallback: \(storedAge)")
                } else {
                    self.age = nil
                }
            }
        } else if let storedAge = defaults.object(forKey: Keys.age) as? Int {
            // No birthdate available, use stored age
            self.age = storedAge
            print("✅ [UserSettings] Loaded age from UserDefaults: \(storedAge) (no birthdate available)")
        } else {
            self.age = nil
            print("⚠️ [UserSettings] No birthdate or stored age found in UserDefaults, age is nil")
        }
        self.lastWeightDate = defaults.object(forKey: Keys.lastWeightDate) as? Date
        self.lastWeightPromptDate = defaults.object(forKey: Keys.lastWeightPromptDate) as? Date
        self.hasSeenDietWelcome = defaults.bool(forKey: Keys.hasSeenDietWelcome)
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
        currentOnboardingStep = nil
        if onboardingCompletedDate == nil {
            onboardingCompletedDate = Calendar.current.startOfDay(for: Date())
        }
    }
    
    func updateGoals(calories: Int, protein: Double, carbs: Double, fat: Double) {
        calorieGoal = calories
        proteinGoal = protein
        carbsGoal = carbs
        fatGoal = fat
        NotificationCenter.default.post(name: .nutritionGoalsChanged, object: nil)
    }

    func updateWeight(_ weight: Double) {
        let timestamp = Date()
        AppLogger.forClass("UserSettings").info("🔍 [updateWeight] Called at \(timestamp): \(weight) kg (currentWeight was: \(currentWeight))")
        AppLogger.forClass("UserSettings").info("🔍 [updateWeight] Stack trace: \(Thread.callStackSymbols.prefix(5).joined(separator: "\n"))")
        currentWeight = weight
        lastWeightDate = Date()
        AppLogger.forClass("UserSettings").info("🔍 [updateWeight] Completed - currentWeight is now: \(currentWeight)")
    }
    
    func markWeightPromptShown() {
        lastWeightPromptDate = Date()
    }
}

// MARK: - BMI Category

/// BMI (Body Mass Index) categories based on World Health Organization (WHO) classification.
///
/// Reference: World Health Organization. "Body mass index - BMI."
/// https://www.who.int/europe/news-room/fact-sheets/item/a-healthy-lifestyle---who-recommendations
///
/// BMI Categories (WHO International Classification):
/// - Underweight: < 18.5
/// - Normal weight: 18.5 - 24.9
/// - Overweight: 25.0 - 29.9
/// - Obese: ≥ 30.0
///
/// Note: BMI is a screening tool and not a diagnostic measure. Individual health assessments
/// should be conducted by qualified healthcare professionals.
enum BMICategory: String, CaseIterable {
    case underweight = "Underweight"
    case normal = "Normal"
    case overweight = "Overweight"
    case obese = "Obese"
    
    /// Reference URL for BMI category information
    static let referenceURL = "https://www.who.int/europe/news-room/fact-sheets/item/a-healthy-lifestyle---who-recommendations"
    
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
