//
//  UserProfileRepository.swift
//  playground
//
//  Repository for managing user profile data persistence
//

import Foundation
import SwiftUI

// MARK: - Supporting Types (moved here for modularity)

enum Gender: String, CaseIterable, Codable {
    case male = "male"
    case female = "female"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        let localizationManager = LocalizationManager.shared
        switch self {
        case .system: return localizationManager.localizedString(for: AppStrings.Profile.system)
        case .light: return localizationManager.localizedString(for: AppStrings.Profile.light)
        case .dark: return localizationManager.localizedString(for: AppStrings.Profile.dark)
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Protocol defining the contract for user profile data operations
protocol UserProfileRepositoryProtocol {
    // Personal Details
    func getFirstName() -> String
    func setFirstName(_ value: String)
    func getLastName() -> String
    func setLastName(_ value: String)
    func getUsername() -> String
    func setUsername(_ value: String)
    func getCurrentWeight() -> Double
    func setCurrentWeight(_ value: Double)
    func getGoalWeight() -> Double
    func setGoalWeight(_ value: Double)
    func getHeightFeet() -> Int
    func setHeightFeet(_ value: Int)
    func getHeightInches() -> Int
    func setHeightInches(_ value: Int)
    func getDateOfBirth() -> Date
    func setDateOfBirth(_ value: Date)
    func getGender() -> Gender
    func setGender(_ value: Gender)
    func getDailyStepGoal() -> Int
    func setDailyStepGoal(_ value: Int)
    
    // Preferences
    func getAppearanceMode() -> AppearanceMode
    func setAppearanceMode(_ value: AppearanceMode)
    func getBadgeCelebrations() -> Bool
    func setBadgeCelebrations(_ value: Bool)
    func getLiveActivity() -> Bool
    func setLiveActivity(_ value: Bool)
    func getAddBurnedCalories() -> Bool
    func setAddBurnedCalories(_ value: Bool)
    func getRolloverCalories() -> Bool
    func setRolloverCalories(_ value: Bool)
    func getAutoAdjustMacros() -> Bool
    func setAutoAdjustMacros(_ value: Bool)
    func getSelectedLanguage() -> String
    func setSelectedLanguage(_ value: String)
    
    // Nutrition Goals
    func getCalorieGoal() -> Int
    func setCalorieGoal(_ value: Int)
    func getProteinGoal() -> Double
    func setProteinGoal(_ value: Double)
    func getCarbsGoal() -> Double
    func setCarbsGoal(_ value: Double)
    func getFatGoal() -> Double
    func setFatGoal(_ value: Double)
    
    // Referral
    func getPromoCode() -> String
    func setPromoCode(_ value: String)
    
    // Utility
    func resetToDefaults()
}

/// Repository implementation using UserDefaults for local persistence
final class UserProfileRepository: UserProfileRepositoryProtocol {
    
    static let shared = UserProfileRepository()
    
    private let defaults: UserDefaults
    
    // MARK: - Keys
    private enum Keys {
        static let firstName = "userProfile_firstName"
        static let lastName = "userProfile_lastName"
        static let username = "userProfile_username"
        static let currentWeight = "userProfile_currentWeight"
        static let goalWeight = "userProfile_goalWeight"
        static let heightFeet = "userProfile_heightFeet"
        static let heightInches = "userProfile_heightInches"
        static let dateOfBirth = "userProfile_dateOfBirth"
        static let gender = "userProfile_gender"
        static let dailyStepGoal = "userProfile_dailyStepGoal"
        static let appearanceMode = "userProfile_appearanceMode"
        static let badgeCelebrations = "userProfile_badgeCelebrations"
        static let liveActivity = "userProfile_liveActivity"
        static let addBurnedCalories = "userProfile_addBurnedCalories"
        static let rolloverCalories = "userProfile_rolloverCalories"
        static let autoAdjustMacros = "userProfile_autoAdjustMacros"
        static let selectedLanguage = "userProfile_selectedLanguage"
        static let promoCode = "userProfile_promoCode"
        static let calorieGoal = "calorieGoal"
        static let proteinGoal = "proteinGoal"
        static let carbsGoal = "carbsGoal"
        static let fatGoal = "fatGoal"
    }
    
    // MARK: - Default Values
    private enum Defaults {
        static let firstName = ""
        static let lastName = ""
        static let username = ""
        static let currentWeight: Double = 150.0
        static let goalWeight: Double = 140.0
        static let heightFeet = 5
        static let heightInches = 8
        static let dailyStepGoal = 10000
        static let badgeCelebrations = true
        static let liveActivity = false
        static let addBurnedCalories = false
        static let rolloverCalories = false
        static let autoAdjustMacros = true
        static let selectedLanguage = "English"
        static let calorieGoal = 2000
        static let proteinGoal: Double = 150
        static let carbsGoal: Double = 250
        static let fatGoal: Double = 65
    }
    
    // MARK: - Initialization
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    // MARK: - Personal Details
    
    func getFirstName() -> String {
        defaults.string(forKey: Keys.firstName) ?? Defaults.firstName
    }
    
    func setFirstName(_ value: String) {
        defaults.set(value, forKey: Keys.firstName)
    }
    
    func getLastName() -> String {
        defaults.string(forKey: Keys.lastName) ?? Defaults.lastName
    }
    
    func setLastName(_ value: String) {
        defaults.set(value, forKey: Keys.lastName)
    }
    
    func getUsername() -> String {
        defaults.string(forKey: Keys.username) ?? Defaults.username
    }
    
    func setUsername(_ value: String) {
        defaults.set(value, forKey: Keys.username)
    }
    
    func getCurrentWeight() -> Double {
        let weightInKg = UserSettings.shared.currentWeight
        return weightInKg * 2.20462
    }
    
    func setCurrentWeight(_ value: Double) {
        let weightInKg = value / 2.20462
        UserSettings.shared.updateWeight(weightInKg)
    }
    
    func getGoalWeight() -> Double {
        let targetInKg = UserSettings.shared.targetWeight
        return targetInKg * 2.20462
    }
    
    func setGoalWeight(_ value: Double) {
        let weightInKg = value / 2.20462
        UserSettings.shared.targetWeight = weightInKg
    }
    
    func getHeightFeet() -> Int {
        let heightInCm = UserSettings.shared.height
        let totalInches = heightInCm / 2.54
        return Int(totalInches / 12)
    }
    
    func setHeightFeet(_ value: Int) {
        let currentInches = getHeightInches()
        let totalInches = Double(value * 12 + currentInches)
        UserSettings.shared.height = totalInches * 2.54
    }
    
    func getHeightInches() -> Int {
        let heightInCm = UserSettings.shared.height
        let totalInches = heightInCm / 2.54
        return Int(totalInches) % 12
    }
    
    func setHeightInches(_ value: Int) {
        let currentFeet = getHeightFeet()
        let totalInches = Double(currentFeet * 12 + value)
        UserSettings.shared.height = totalInches * 2.54
    }
    
    func getDateOfBirth() -> Date {
        UserSettings.shared.birthdate ?? Calendar.current.date(byAdding: .year, value: -30, to: Date())!
    }
    
    func setDateOfBirth(_ value: Date) {
        UserSettings.shared.birthdate = value
    }
    
    func getGender() -> Gender {
        guard let rawValue = defaults.string(forKey: Keys.gender) else { return .male }
        return Gender(rawValue: rawValue) ?? .male
    }
    
    func setGender(_ value: Gender) {
        defaults.set(value.rawValue, forKey: Keys.gender)
    }
    
    func getDailyStepGoal() -> Int {
        defaults.object(forKey: Keys.dailyStepGoal) as? Int ?? Defaults.dailyStepGoal
    }
    
    func setDailyStepGoal(_ value: Int) {
        defaults.set(value, forKey: Keys.dailyStepGoal)
    }
    
    // MARK: - Preferences
    
    func getAppearanceMode() -> AppearanceMode {
        guard let rawValue = defaults.string(forKey: Keys.appearanceMode) else { return .system }
        return AppearanceMode(rawValue: rawValue) ?? .system
    }
    
    func setAppearanceMode(_ value: AppearanceMode) {
        defaults.set(value.rawValue, forKey: Keys.appearanceMode)
    }
    
    func getBadgeCelebrations() -> Bool {
        defaults.object(forKey: Keys.badgeCelebrations) as? Bool ?? Defaults.badgeCelebrations
    }
    
    func setBadgeCelebrations(_ value: Bool) {
        defaults.set(value, forKey: Keys.badgeCelebrations)
    }
    
    func getLiveActivity() -> Bool {
        defaults.object(forKey: Keys.liveActivity) as? Bool ?? Defaults.liveActivity
    }
    
    func setLiveActivity(_ value: Bool) {
        defaults.set(value, forKey: Keys.liveActivity)
    }
    
    func getAddBurnedCalories() -> Bool {
        defaults.object(forKey: Keys.addBurnedCalories) as? Bool ?? Defaults.addBurnedCalories
    }
    
    func setAddBurnedCalories(_ value: Bool) {
        defaults.set(value, forKey: Keys.addBurnedCalories)
    }
    
    func getRolloverCalories() -> Bool {
        defaults.object(forKey: Keys.rolloverCalories) as? Bool ?? Defaults.rolloverCalories
    }
    
    func setRolloverCalories(_ value: Bool) {
        defaults.set(value, forKey: Keys.rolloverCalories)
    }
    
    func getAutoAdjustMacros() -> Bool {
        defaults.object(forKey: Keys.autoAdjustMacros) as? Bool ?? Defaults.autoAdjustMacros
    }
    
    func setAutoAdjustMacros(_ value: Bool) {
        defaults.set(value, forKey: Keys.autoAdjustMacros)
    }
    
    func getSelectedLanguage() -> String {
        defaults.string(forKey: Keys.selectedLanguage) ?? Defaults.selectedLanguage
    }
    
    func setSelectedLanguage(_ value: String) {
        defaults.set(value, forKey: Keys.selectedLanguage)
    }
    
    // MARK: - Nutrition Goals
    
    func getCalorieGoal() -> Int {
        UserSettings.shared.calorieGoal
    }
    
    func setCalorieGoal(_ value: Int) {
        UserSettings.shared.calorieGoal = value
    }
    
    func getProteinGoal() -> Double {
        UserSettings.shared.proteinGoal
    }
    
    func setProteinGoal(_ value: Double) {
        UserSettings.shared.proteinGoal = value
    }
    
    func getCarbsGoal() -> Double {
        UserSettings.shared.carbsGoal
    }
    
    func setCarbsGoal(_ value: Double) {
        UserSettings.shared.carbsGoal = value
    }
    
    func getFatGoal() -> Double {
        UserSettings.shared.fatGoal
    }
    
    func setFatGoal(_ value: Double) {
        UserSettings.shared.fatGoal = value
    }
    
    // MARK: - Referral
    
    func getPromoCode() -> String {
        if let existing = defaults.string(forKey: Keys.promoCode), !existing.isEmpty {
            return existing
        }
        // Generate a new promo code
        let newCode = String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        setPromoCode(newCode)
        return newCode
    }
    
    func setPromoCode(_ value: String) {
        defaults.set(value, forKey: Keys.promoCode)
    }
    
    // MARK: - Utility
    
    func resetToDefaults() {
        setFirstName(Defaults.firstName)
        setLastName(Defaults.lastName)
        setUsername(Defaults.username)
        setCurrentWeight(Defaults.currentWeight)
        setGoalWeight(Defaults.goalWeight)
        setHeightFeet(Defaults.heightFeet)
        setHeightInches(Defaults.heightInches)
        setDateOfBirth(Calendar.current.date(byAdding: .year, value: -30, to: Date())!)
        setGender(.male)
        setDailyStepGoal(Defaults.dailyStepGoal)
        setAppearanceMode(.system)
        setBadgeCelebrations(Defaults.badgeCelebrations)
        setLiveActivity(Defaults.liveActivity)
        setAddBurnedCalories(Defaults.addBurnedCalories)
        setRolloverCalories(Defaults.rolloverCalories)
        setAutoAdjustMacros(Defaults.autoAdjustMacros)
        setSelectedLanguage(Defaults.selectedLanguage)
        setCalorieGoal(Defaults.calorieGoal)
        setProteinGoal(Defaults.proteinGoal)
        setCarbsGoal(Defaults.carbsGoal)
        setFatGoal(Defaults.fatGoal)
    }
}

// MARK: - Computed Properties Extension

extension UserProfileRepository {
    
    var fullName: String {
        let first = getFirstName()
        let last = getLastName()
        if first.isEmpty && last.isEmpty {
            return LocalizationManager.shared.localizedString(for: AppStrings.Profile.tapToSetName)
        }
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }
    
    var heightDisplay: String {
        "\(getHeightFeet()) ft \(getHeightInches()) in"
    }
    
    var age: Int {
        Calendar.current.dateComponents([.year], from: getDateOfBirth(), to: Date()).year ?? 0
    }
    
    var bmi: Double {
        let heightInMeters = (Double(getHeightFeet()) * 12 + Double(getHeightInches())) * 0.0254
        let weightInKg = getCurrentWeight() * 0.453592
        guard heightInMeters > 0 else { return 0 }
        return weightInKg / (heightInMeters * heightInMeters)
    }
}
