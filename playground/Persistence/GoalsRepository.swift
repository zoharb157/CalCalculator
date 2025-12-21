//
//  GoalsRepository.swift
//  playground
//
//  Repository for generating user goals based on onboarding data
//

import Foundation

/// Generated nutrition goals based on user onboarding data
struct GeneratedGoals: Equatable {
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    
    static let `default` = GeneratedGoals(
        calories: 2000,
        proteinG: 150,
        carbsG: 250,
        fatG: 65
    )
}

/// Repository for generating and managing user nutrition goals
@MainActor
final class GoalsRepository {
    static let shared = GoalsRepository()
    
    private init() {}
    
    /// Generate goals based on onboarding data
    /// - Parameter onboardingData: Dictionary containing user's onboarding responses
    /// - Returns: Generated nutrition goals
    /// - Note: Currently uses a static delay for demo purposes. Replace with actual API call when ready.
    func generateGoals(from onboardingData: [String: Any]) async throws -> GeneratedGoals {
        // Simulate API delay for demo purposes
        try await Task.sleep(nanoseconds: 3_500_000_000) // 3.5 seconds
        
        // TODO: Replace with actual API call
        // For now, generate mock goals based on some basic calculations
        let goals = calculateMockGoals(from: onboardingData)
        
        return goals
    }
    
    /// Calculate mock goals based on onboarding data
    /// In a real implementation, this would be done server-side
    private func calculateMockGoals(from data: [String: Any]) -> GeneratedGoals {
        // Extract basic info from onboarding data
        // These keys should match your onboarding.json structure
        
        var baseCalories = 2000
        var proteinMultiplier = 1.0
        
        // Check for activity level
        if let activityLevel = data["activity_level"] as? String {
            switch activityLevel.lowercased() {
            case "sedentary":
                baseCalories = 1800
                proteinMultiplier = 0.8
            case "lightly_active", "light":
                baseCalories = 2000
                proteinMultiplier = 1.0
            case "moderately_active", "moderate":
                baseCalories = 2200
                proteinMultiplier = 1.1
            case "very_active", "active":
                baseCalories = 2500
                proteinMultiplier = 1.2
            case "extra_active", "athlete":
                baseCalories = 2800
                proteinMultiplier = 1.3
            default:
                break
            }
        }
        
        // Check for goal type
        if let goal = data["goal"] as? String {
            switch goal.lowercased() {
            case "lose_weight", "weight_loss", "lose":
                baseCalories = Int(Double(baseCalories) * 0.8)
            case "maintain", "maintain_weight":
                break // Keep as is
            case "gain_weight", "weight_gain", "gain", "build_muscle":
                baseCalories = Int(Double(baseCalories) * 1.15)
            default:
                break
            }
        }
        
        // Calculate macros based on calories
        // Standard macro split: 30% protein, 40% carbs, 30% fat
        let proteinCalories = Double(baseCalories) * 0.30
        let carbsCalories = Double(baseCalories) * 0.40
        let fatCalories = Double(baseCalories) * 0.30
        
        // Convert to grams
        // Protein: 4 cal/g, Carbs: 4 cal/g, Fat: 9 cal/g
        let proteinG = (proteinCalories / 4.0) * proteinMultiplier
        let carbsG = carbsCalories / 4.0
        let fatG = fatCalories / 9.0
        
        return GeneratedGoals(
            calories: baseCalories,
            proteinG: round(proteinG),
            carbsG: round(carbsG),
            fatG: round(fatG)
        )
    }
    
    /// Save generated goals to UserDefaults
    func saveGoals(_ goals: GeneratedGoals) {
        let settings = UserSettings.shared
        settings.calorieGoal = goals.calories
        settings.proteinGoal = goals.proteinG
        settings.carbsGoal = goals.carbsG
        settings.fatGoal = goals.fatG
    }
}
