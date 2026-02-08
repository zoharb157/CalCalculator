//
//  UserProfile.swift
//  playground
//
//  User profile and personal details model
//

import Foundation
import SwiftUI

/// User profile data including personal details, preferences, and goals
@Observable
final class UserProfile {
    static let shared = UserProfile()
    
    private let defaults = UserDefaults.standard
    
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
        static let activeCaloriesGoal = "userProfile_activeCaloriesGoal"
        static let exerciseMinutesGoal = "userProfile_exerciseMinutesGoal"
        static let distanceGoalKm = "userProfile_distanceGoalKm"
        static let appearanceMode = "userProfile_appearanceMode"
        static let badgeCelebrations = "userProfile_badgeCelebrations"
        static let liveActivity = "userProfile_liveActivity"
        static let addBurnedCalories = "userProfile_addBurnedCalories"
        static let rolloverCalories = "userProfile_rolloverCalories"
        static let autoAdjustMacros = "userProfile_autoAdjustMacros"
        static let selectedLanguage = "userProfile_selectedLanguage"
        static let promoCode = "userProfile_promoCode"
    }
    
    // MARK: - Personal Details
    var firstName: String {
        didSet { defaults.set(firstName, forKey: Keys.firstName) }
    }
    
    var lastName: String {
        didSet { defaults.set(lastName, forKey: Keys.lastName) }
    }
    
    var username: String {
        didSet { defaults.set(username, forKey: Keys.username) }
    }
    
    var currentWeight: Double { // in lbs
        didSet { defaults.set(currentWeight, forKey: Keys.currentWeight) }
    }
    
    var goalWeight: Double { // in lbs
        didSet { defaults.set(goalWeight, forKey: Keys.goalWeight) }
    }
    
    var heightFeet: Int {
        didSet { defaults.set(heightFeet, forKey: Keys.heightFeet) }
    }
    
    var heightInches: Int {
        didSet { defaults.set(heightInches, forKey: Keys.heightInches) }
    }
    
    var dateOfBirth: Date {
        didSet { defaults.set(dateOfBirth, forKey: Keys.dateOfBirth) }
    }
    
    var gender: Gender {
        didSet { defaults.set(gender.rawValue, forKey: Keys.gender) }
    }
    
    var dailyStepGoal: Int {
        didSet { defaults.set(dailyStepGoal, forKey: Keys.dailyStepGoal) }
    }
    
    var activeCaloriesGoal: Int {
        didSet { defaults.set(activeCaloriesGoal, forKey: Keys.activeCaloriesGoal) }
    }
    
    var exerciseMinutesGoal: Int {
        didSet { defaults.set(exerciseMinutesGoal, forKey: Keys.exerciseMinutesGoal) }
    }
    
    var distanceGoalKm: Double {
        didSet { defaults.set(distanceGoalKm, forKey: Keys.distanceGoalKm) }
    }
    
    // MARK: - Preferences
    var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }
    
    var badgeCelebrations: Bool {
        didSet { defaults.set(badgeCelebrations, forKey: Keys.badgeCelebrations) }
    }
    
    var liveActivity: Bool {
        didSet { defaults.set(liveActivity, forKey: Keys.liveActivity) }
    }
    
    var addBurnedCalories: Bool {
        didSet { defaults.set(addBurnedCalories, forKey: Keys.addBurnedCalories) }
    }
    
    var rolloverCalories: Bool {
        didSet { defaults.set(rolloverCalories, forKey: Keys.rolloverCalories) }
    }
    
    var autoAdjustMacros: Bool {
        didSet { defaults.set(autoAdjustMacros, forKey: Keys.autoAdjustMacros) }
    }
    
    var selectedLanguage: String {
        didSet { defaults.set(selectedLanguage, forKey: Keys.selectedLanguage) }
    }
    
    // MARK: - Referral
    var promoCode: String {
        didSet { defaults.set(promoCode, forKey: Keys.promoCode) }
    }
    
    // MARK: - Computed Properties
    var fullName: String {
        if firstName.isEmpty && lastName.isEmpty {
            return LocalizationManager.shared.localizedString(for: AppStrings.Profile.tapToSetName)
        }
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    var heightDisplay: String {
        "\(heightFeet) ft \(heightInches) in"
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
    
    var weightProgressPercentage: Double {
        guard goalWeight > 0 else { return 0 }
        let totalChange = abs(currentWeight - goalWeight)
        let progress = abs(goalWeight - currentWeight) / totalChange
        return min(progress * 100, 100)
    }
    
    // MARK: - Initialization
    private init() {
        // Initialize all properties with default values first
        let firstNameValue = defaults.string(forKey: Keys.firstName) ?? ""
        let lastNameValue = defaults.string(forKey: Keys.lastName) ?? ""
        let usernameValue = defaults.string(forKey: Keys.username) ?? ""
        let currentWeightValue = defaults.object(forKey: Keys.currentWeight) as? Double ?? 119.0
        let goalWeightValue = defaults.object(forKey: Keys.goalWeight) as? Double ?? 106.9
        let heightFeetValue = defaults.object(forKey: Keys.heightFeet) as? Int ?? 5
        let heightInchesValue = defaults.object(forKey: Keys.heightInches) as? Int ?? 6
        let dateOfBirthValue = defaults.object(forKey: Keys.dateOfBirth) as? Date ?? Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        let genderValue = Gender(rawValue: defaults.string(forKey: Keys.gender) ?? "male") ?? .male
        let dailyStepGoalValue = defaults.object(forKey: Keys.dailyStepGoal) as? Int ?? 10000
        let activeCaloriesGoalValue = defaults.object(forKey: Keys.activeCaloriesGoal) as? Int ?? 500
        let exerciseMinutesGoalValue = defaults.object(forKey: Keys.exerciseMinutesGoal) as? Int ?? 30
        let distanceGoalKmValue = defaults.object(forKey: Keys.distanceGoalKm) as? Double ?? 5.0
        let appearanceModeValue = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearanceMode) ?? "system") ?? .system
        let badgeCelebrationsValue = defaults.object(forKey: Keys.badgeCelebrations) as? Bool ?? true
        let liveActivityValue = defaults.object(forKey: Keys.liveActivity) as? Bool ?? false
        let addBurnedCaloriesValue = defaults.object(forKey: Keys.addBurnedCalories) as? Bool ?? false
        let rolloverCaloriesValue = defaults.object(forKey: Keys.rolloverCalories) as? Bool ?? false
        let autoAdjustMacrosValue = defaults.object(forKey: Keys.autoAdjustMacros) as? Bool ?? true
        let selectedLanguageValue = defaults.string(forKey: Keys.selectedLanguage) ?? "English"
        
        // Generate promo code if not exists
        let promoCodeValue: String
        if let existing = defaults.string(forKey: Keys.promoCode), !existing.isEmpty {
            promoCodeValue = existing
        } else {
            promoCodeValue = String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        }
        
        // Assign all values
        self.firstName = firstNameValue
        self.lastName = lastNameValue
        self.username = usernameValue
        self.currentWeight = currentWeightValue
        self.goalWeight = goalWeightValue
        self.heightFeet = heightFeetValue
        self.heightInches = heightInchesValue
        self.dateOfBirth = dateOfBirthValue
        self.gender = genderValue
        self.dailyStepGoal = dailyStepGoalValue
        self.activeCaloriesGoal = activeCaloriesGoalValue
        self.exerciseMinutesGoal = exerciseMinutesGoalValue
        self.distanceGoalKm = distanceGoalKmValue
        self.appearanceMode = appearanceModeValue
        self.badgeCelebrations = badgeCelebrationsValue
        self.liveActivity = liveActivityValue
        self.addBurnedCalories = addBurnedCaloriesValue
        self.rolloverCalories = rolloverCaloriesValue
        self.autoAdjustMacros = autoAdjustMacrosValue
        self.selectedLanguage = selectedLanguageValue
        self.promoCode = promoCodeValue
    }
}

// MARK: - Supporting Types
// Gender and AppearanceMode enums are now defined in UserProfileRepository.swift

