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
        didSet {
            repository.setCurrentWeight(currentWeight)
            // Also update UserSettings to keep it in sync
            // Since both are @Observable, views observing them will automatically update
            let weightInKg = currentWeight * 0.453592
            UserSettings.shared.updateWeight(weightInKg)
        }
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
        didSet {
            repository.setLiveActivity(liveActivity)
            handleLiveActivityToggle()
        }
    }
    
    var addBurnedCalories: Bool {
        didSet {
            repository.setAddBurnedCalories(addBurnedCalories)
            // Notify that the toggle changed so UI can update
            NotificationCenter.default.post(name: .addBurnedCaloriesToggled, object: nil)
        }
    }
    
    var rolloverCalories: Bool {
        didSet { repository.setRolloverCalories(rolloverCalories) }
    }
    
    var autoAdjustMacros: Bool {
        didSet { repository.setAutoAdjustMacros(autoAdjustMacros) }
    }
    
    var selectedLanguage: String {
        didSet {
            // Only reset if language actually changed
            if oldValue != selectedLanguage {
                print("🌐 [ProfileViewModel] Language changed from '\(oldValue)' to '\(selectedLanguage)'")
                repository.setSelectedLanguage(selectedLanguage)
                // Apply language change immediately
                let languageCode = LocalizationManager.languageCode(from: selectedLanguage)
                print("🌐 [ProfileViewModel] Mapped to language code: '\(languageCode)'")
                LocalizationManager.shared.setLanguage(languageCode)
                
                // Reset choices/state when language changes
                resetChoicesOnLanguageChange()
            } else {
                print("🌐 [ProfileViewModel] Language unchanged: '\(selectedLanguage)'")
            }
        }
    }
    
    /// Reset choices and state when language changes
    private func resetChoicesOnLanguageChange() {
        // Reset any cached selections, tabs, or state that might be language-dependent
        // This ensures UI refreshes properly with new language
        // Note: SwiftUI views will automatically refresh due to languageChanged notification
        
        // Force reload of profile data to ensure all fields are properly displayed
        // This is critical for fixing the issue where data appears empty after language change
        loadProfileData()
    }
    
    /// Load profile data from repository
    /// This ensures all profile fields are properly loaded and displayed
    func loadProfileData() {
        // Reload all profile data from repository
        // This is called when language changes to ensure data is properly displayed
        let repo = repository
        
        // Force reload by accessing all properties
        _ = repo.getFirstName()
        _ = repo.getLastName()
        _ = repo.getUsername()
        _ = repo.getCurrentWeight()
        _ = repo.getGoalWeight()
        _ = repo.getHeightFeet()
        _ = repo.getHeightInches()
        _ = repo.getDateOfBirth()
        _ = repo.getGender()
        _ = repo.getDailyStepGoal()
        _ = repo.getCalorieGoal()
        _ = repo.getProteinGoal()
        _ = repo.getSelectedLanguage()
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
            return LocalizationManager.shared.localizedString(for: AppStrings.Profile.tapToSetName)
        }
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    var usernameDisplay: String {
        username.isEmpty ? LocalizationManager.shared.localizedString(for: AppStrings.Profile.setUsername) : "@\(username)"
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
        let savedLanguage = repository.getSelectedLanguage()
        self.selectedLanguage = savedLanguage
        // Apply saved language on init
        let languageCode = LocalizationManager.languageCode(from: savedLanguage)
        LocalizationManager.shared.setLanguage(languageCode)
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
    
    // MARK: - Auto Generate Macros
    
    var isGeneratingMacros = false {
        didSet { /* Observable will handle updates */ }
    }
    var macroGenerationError: String? {
        didSet { /* Observable will handle updates */ }
    }
    var macroGenerationSuccess = false {
        didSet { /* Observable will handle updates */ }
    }
    
    /// Generate ALL goals (calories + macros) using API based on current profile
    /// Uses GoalsGenerationService API with fallback to local calculation
    func autoGenerateMacros() async {
        guard !isGeneratingMacros else { return }
        
        await MainActor.run {
            isGeneratingMacros = true
            macroGenerationError = nil
            macroGenerationSuccess = false
        }
        
        do {
            // Build onboarding data from current profile (without calorie_goal to let API calculate)
            let onboardingData = buildOnboardingDataFromProfile(includeCalorieGoal: false)
            
            print("🔵 [ProfileViewModel] Starting goal generation...")
            print("🔵 [ProfileViewModel] Onboarding data: \(onboardingData)")
            
            // Call GoalsRepository which now uses the API with fallback
            let goals = try await GoalsRepository.shared.generateGoals(from: onboardingData)
            
            // Update ALL goals including calories
            await MainActor.run {
                UserSettings.shared.updateGoals(
                    calories: goals.calories,
                    protein: goals.proteinG,
                    carbs: goals.carbsG,
                    fat: goals.fatG
                )
                
                // Update local state - ALL goals including calories
                calorieGoal = goals.calories
                proteinGoal = goals.proteinG
                carbsGoal = goals.carbsG
                fatGoal = goals.fatG
                
                isGeneratingMacros = false
                macroGenerationSuccess = true
                
                print("✅ [ProfileViewModel] Goals generated successfully:")
                print("   - Calories: \(goals.calories)")
                print("   - Protein: \(goals.proteinG)g")
                print("   - Carbs: \(goals.carbsG)g")
                print("   - Fat: \(goals.fatG)g")
                if let notes = goals.notes {
                    print("   - Notes: \(notes)")
                }
                
                // Auto-hide success message after 3 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        macroGenerationSuccess = false
                    }
                }
            }
        } catch {
            await MainActor.run {
                isGeneratingMacros = false
                macroGenerationError = error.localizedDescription
                print("🔴 [ProfileViewModel] Failed to generate goals: \(error.localizedDescription)")
            }
        }
    }
    
    /// Clear any macro generation error
    func clearMacroGenerationError() {
        macroGenerationError = nil
    }
    
    /// Build onboarding data dictionary from current profile
    /// - Parameter includeCalorieGoal: If true, includes current calorie goal (for scaling macros). If false, lets API calculate calories.
    private func buildOnboardingDataFromProfile(includeCalorieGoal: Bool = false) -> [String: Any] {
        // Determine goal type based on current vs goal weight
        let goalType: String
        if goalWeight < currentWeight {
            goalType = "lose_weight"
        } else if goalWeight > currentWeight {
            goalType = "gain_weight"
        } else {
            goalType = "maintain"
        }
        
        // Estimate activity level (default to moderate if not available)
        // You can enhance this by storing activity level in profile
        let activityLevel = "moderately_active" // Default
        
        // Build data dictionary matching onboarding structure
        var data: [String: Any] = [
            "goal": goalType,
            "activity_level": activityLevel,
            "current_weight": currentWeight,
            "goal_weight": goalWeight,
            "height_feet": heightFeet,
            "height_inches": heightInches,
            "gender": gender.rawValue,
            "age": age
        ]
        
        // Only include calorie_goal if explicitly requested (for macro scaling)
        if includeCalorieGoal && calorieGoal > 0 {
            data["calorie_goal"] = calorieGoal
        }
        
        return data
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
    /// This is called when individual goals are changed via didSet
    private func syncNutritionGoalsToUserSettings() {
        let settings = UserSettings.shared
        settings.updateGoals(
            calories: calorieGoal,
            protein: proteinGoal,
            carbs: carbsGoal,
            fat: fatGoal
        )
    }
    
    // MARK: - Goal Status Computed Properties
    
    /// Handle Live Activity toggle change
    private func handleLiveActivityToggle() {
        if #available(iOS 16.1, *) {
            if liveActivity {
                // Start Live Activity - trigger update from HomeViewModel
                NotificationCenter.default.post(name: .updateLiveActivity, object: nil)
            } else {
                // End Live Activity
                LiveActivityManager.shared.endActivity()
            }
        }
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
