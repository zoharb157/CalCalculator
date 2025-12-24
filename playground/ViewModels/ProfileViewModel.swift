//
//  ProfileViewModel.swift
//  playground
//
//  ViewModel for Profile-related views with proper state management
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// ViewModel managing profile state and business logic
@Observable
final class ProfileViewModel {
    
    // MARK: - Dependencies
    
    private let repository: UserProfileRepositoryProtocol
    
    // MARK: - Personal Details State
    
    var firstName: String {
        didSet { repository.setFirstName(firstName) }
    }
    
    var lastName: String {
        didSet { repository.setLastName(lastName) }
    }
    
    var username: String {
        didSet { repository.setUsername(username) }
    }
    
    var currentWeight: Double {
        didSet { repository.setCurrentWeight(currentWeight) }
    }
    
    var goalWeight: Double {
        didSet { repository.setGoalWeight(goalWeight) }
    }
    
    var heightFeet: Int {
        didSet { repository.setHeightFeet(heightFeet) }
    }
    
    var heightInches: Int {
        didSet { repository.setHeightInches(heightInches) }
    }
    
    var dateOfBirth: Date {
        didSet { repository.setDateOfBirth(dateOfBirth) }
    }
    
    var gender: Gender {
        didSet { repository.setGender(gender) }
    }
    
    var dailyStepGoal: Int {
        didSet { repository.setDailyStepGoal(dailyStepGoal) }
    }
    
    // MARK: - Preferences State
    
    var appearanceMode: AppearanceMode {
        didSet {
            repository.setAppearanceMode(appearanceMode)
            NotificationCenter.default.post(name: .appearanceModeChanged, object: appearanceMode)
        }
    }
    
    var badgeCelebrations: Bool {
        didSet { repository.setBadgeCelebrations(badgeCelebrations) }
    }
    
    var liveActivity: Bool {
        didSet { repository.setLiveActivity(liveActivity) }
    }
    
    var addBurnedCalories: Bool {
        didSet { repository.setAddBurnedCalories(addBurnedCalories) }
    }
    
    var rolloverCalories: Bool {
        didSet { repository.setRolloverCalories(rolloverCalories) }
    }
    
    var autoAdjustMacros: Bool {
        didSet { repository.setAutoAdjustMacros(autoAdjustMacros) }
    }
    
    var selectedLanguage: String {
        didSet { repository.setSelectedLanguage(selectedLanguage) }
    }
    
    // MARK: - Nutrition Goals State
    
    var calorieGoal: Int {
        didSet {
            repository.setCalorieGoal(calorieGoal)
            syncNutritionGoalsToUserSettings()
        }
    }
    
    var proteinGoal: Double {
        didSet {
            repository.setProteinGoal(proteinGoal)
            syncNutritionGoalsToUserSettings()
        }
    }
    
    var carbsGoal: Double {
        didSet {
            repository.setCarbsGoal(carbsGoal)
            syncNutritionGoalsToUserSettings()
        }
    }
    
    var fatGoal: Double {
        didSet {
            repository.setFatGoal(fatGoal)
            syncNutritionGoalsToUserSettings()
        }
    }
    
    // MARK: - Referral
    
    var promoCode: String {
        didSet { repository.setPromoCode(promoCode) }
    }
    
    // MARK: - Computed Properties
    
    var fullName: String {
        if firstName.isEmpty && lastName.isEmpty {
            return "Tap to set name"
        }
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    var usernameDisplay: String {
        username.isEmpty ? "Set username" : "@\(username)"
    }
    
    var heightDisplay: String {
        "\(heightFeet) ft \(heightInches) in"
    }
    
    var currentWeightDisplay: String {
        "\(Int(currentWeight)) lbs"
    }
    
    var goalWeightDisplay: String {
        String(format: "%.1f lbs", goalWeight)
    }
    
    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
    
    var bmi: Double {
        let heightInMeters = (Double(heightFeet) * 12 + Double(heightInches)) * 0.0254
        let weightInKg = currentWeight * 0.453592
        guard heightInMeters > 0 else { return 0 }
        return weightInKg / (heightInMeters * heightInMeters)
    }
    
    var bmiCategory: String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }
    
    var bmiColor: Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }
    
    var macroGoals: MacroData {
        MacroData(
            calories: calorieGoal,
            proteinG: proteinGoal,
            carbsG: carbsGoal,
            fatG: fatGoal
        )
    }
    
    // MARK: - Initialization
    
    init(repository: UserProfileRepositoryProtocol = UserProfileRepository.shared) {
        self.repository = repository
        
        // Load initial state from repository
        self.firstName = repository.getFirstName()
        self.lastName = repository.getLastName()
        self.username = repository.getUsername()
        self.currentWeight = repository.getCurrentWeight()
        self.goalWeight = repository.getGoalWeight()
        self.heightFeet = repository.getHeightFeet()
        self.heightInches = repository.getHeightInches()
        self.dateOfBirth = repository.getDateOfBirth()
        self.gender = repository.getGender()
        self.dailyStepGoal = repository.getDailyStepGoal()
        self.appearanceMode = repository.getAppearanceMode()
        self.badgeCelebrations = repository.getBadgeCelebrations()
        self.liveActivity = repository.getLiveActivity()
        self.addBurnedCalories = repository.getAddBurnedCalories()
        self.rolloverCalories = repository.getRolloverCalories()
        self.autoAdjustMacros = repository.getAutoAdjustMacros()
        self.selectedLanguage = repository.getSelectedLanguage()
        self.calorieGoal = repository.getCalorieGoal()
        self.proteinGoal = repository.getProteinGoal()
        self.carbsGoal = repository.getCarbsGoal()
        self.fatGoal = repository.getFatGoal()
        self.promoCode = repository.getPromoCode()
    }
    
    // MARK: - Actions
    
    func resetToDefaults() {
        repository.resetToDefaults()
        refreshFromRepository()
    }
    
    func refreshFromRepository() {
        firstName = repository.getFirstName()
        lastName = repository.getLastName()
        username = repository.getUsername()
        currentWeight = repository.getCurrentWeight()
        goalWeight = repository.getGoalWeight()
        heightFeet = repository.getHeightFeet()
        heightInches = repository.getHeightInches()
        dateOfBirth = repository.getDateOfBirth()
        gender = repository.getGender()
        dailyStepGoal = repository.getDailyStepGoal()
        appearanceMode = repository.getAppearanceMode()
        badgeCelebrations = repository.getBadgeCelebrations()
        liveActivity = repository.getLiveActivity()
        addBurnedCalories = repository.getAddBurnedCalories()
        rolloverCalories = repository.getRolloverCalories()
        autoAdjustMacros = repository.getAutoAdjustMacros()
        selectedLanguage = repository.getSelectedLanguage()
        calorieGoal = repository.getCalorieGoal()
        proteinGoal = repository.getProteinGoal()
        carbsGoal = repository.getCarbsGoal()
        fatGoal = repository.getFatGoal()
        promoCode = repository.getPromoCode()
    }
    
    func copyPromoCode() {
        #if canImport(UIKit)
        UIPasteboard.general.string = promoCode
        #endif
    }
    
    /// Calculate recommended macros based on goals
    func autoGenerateMacros() {
        // Standard macro split: 30% protein, 40% carbs, 30% fat
        // Protein: 4 cal/g, Carbs: 4 cal/g, Fat: 9 cal/g
        let proteinCalories = Double(calorieGoal) * 0.30
        let carbsCalories = Double(calorieGoal) * 0.40
        let fatCalories = Double(calorieGoal) * 0.30
        
        proteinGoal = proteinCalories / 4.0
        carbsGoal = carbsCalories / 4.0
        fatGoal = fatCalories / 9.0
    }
    
    /// Calculate recommended daily calories based on user metrics and goals
    func calculateRecommendedCalories() -> Int {
        // Harris-Benedict equation for BMR
        let weightKg = currentWeight * 0.453592
        let heightCm = (Double(heightFeet) * 12 + Double(heightInches)) * 2.54
        
        let bmr: Double
        switch gender {
        case .male:
            bmr = 88.362 + (13.397 * weightKg) + (4.799 * heightCm) - (5.677 * Double(age))
        case .female:
            bmr = 447.593 + (9.247 * weightKg) + (3.098 * heightCm) - (4.330 * Double(age))
        case .other:
            // Average of male and female formulas
            let maleBmr = 88.362 + (13.397 * weightKg) + (4.799 * heightCm) - (5.677 * Double(age))
            let femaleBmr = 447.593 + (9.247 * weightKg) + (3.098 * heightCm) - (4.330 * Double(age))
            bmr = (maleBmr + femaleBmr) / 2
        }
        
        // Assume moderate activity level (1.55 multiplier)
        let tdee = bmr * 1.55
        
        // Adjust for weight goal (500 cal deficit for loss, 300 cal surplus for gain)
        if goalWeight < currentWeight {
            return Int(tdee - 500)
        } else if goalWeight > currentWeight {
            return Int(tdee + 300)
        }
        return Int(tdee)
    }
    
    /// Sync nutrition goals to UserSettings.shared so HomeView stays updated
    private func syncNutritionGoalsToUserSettings() {
        let settings = UserSettings.shared
        settings.calorieGoal = calorieGoal
        settings.proteinGoal = proteinGoal
        settings.carbsGoal = carbsGoal
        settings.fatGoal = fatGoal
        NotificationCenter.default.post(name: .nutritionGoalsChanged, object: nil)
    }
}

// MARK: - Language Support

extension ProfileViewModel {
    
    static let supportedLanguages: [(name: String, flag: String, code: String)] = [
        ("English", "US", "en"),
        ("Spanish", "ES", "es"),
        ("French", "FR", "fr"),
        ("German", "DE", "de"),
        ("Italian", "IT", "it"),
        ("Portuguese", "BR", "pt"),
        ("Chinese", "CN", "zh"),
        ("Japanese", "JP", "ja"),
        ("Korean", "KR", "ko"),
        ("Russian", "RU", "ru"),
        ("Arabic", "SA", "ar"),
        ("Hindi", "IN", "hi")
    ]
}
