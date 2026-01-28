//
//  DietPlanCalculator.swift
//  playground
//
//  Utility for calculating diet plan macros and calories from user profile
//
//  SCIENTIFIC REFERENCES:
//  - Harris-Benedict BMR Equation: Harris JA, Benedict FG. "A Biometric Study of Human Basal Metabolism."
//    Proceedings of the National Academy of Sciences. 1918;4(12):370-373.
//    https://doi.org/10.1073/pnas.4.12.370
//
//  - TDEE Activity Multipliers: Based on the Mifflin-St Jeor activity factors.
//    Mifflin MD, St Jeor ST, et al. "A new predictive equation for resting energy expenditure."
//    American Journal of Clinical Nutrition. 1990;51(2):241-247.
//    https://doi.org/10.1093/ajcn/51.2.241
//
//  - Macronutrient Energy Values: USDA Food Composition Databases.
//    Protein: 4 kcal/g, Carbohydrates: 4 kcal/g, Fat: 9 kcal/g
//    https://www.nal.usda.gov/fnic/how-many-calories-are-one-gram-fat-carbohydrate-or-protein
//
//  - Safe Calorie Deficit/Surplus: American College of Sports Medicine Guidelines.
//    500 kcal/day deficit for ~1 lb/week weight loss.
//    https://www.acsm.org
//

import Foundation

/// Utility struct for calculating diet plan values
///
/// All calculations are based on peer-reviewed scientific research.
/// See file header for complete citations and references.
struct DietPlanCalculator {
    
    // MARK: - Scientific Reference URLs
    
    /// URL to Harris-Benedict equation reference
    static let harrisBenedictReferenceURL = "https://doi.org/10.1073/pnas.4.12.370"
    
    /// URL to USDA macronutrient energy values
    static let macronutrientEnergyReferenceURL = "https://www.nal.usda.gov/fnic/how-many-calories-are-one-gram-fat-carbohydrate-or-protein"
    
    /// URL to activity multiplier research
    static let activityMultiplierReferenceURL = "https://doi.org/10.1093/ajcn/51.2.241"
    
    /// Calculate macros from calorie goal
    /// Uses standard macro split: 30% protein, 40% carbs, 30% fat
    ///
    /// Reference: USDA Food Composition Databases for macronutrient energy values:
    /// - Protein: 4 kcal/g
    /// - Carbohydrates: 4 kcal/g
    /// - Fat: 9 kcal/g
    ///
    /// - Parameter calories: Daily calorie goal
    /// - Returns: Tuple of (proteinG, carbsG, fatG)
    static func calculateMacros(from calories: Int) -> (proteinG: Double, carbsG: Double, fatG: Double) {
        // Standard macro split: 30% protein, 40% carbs, 30% fat
        let proteinCalories = Double(calories) * 0.30
        let carbsCalories = Double(calories) * 0.40
        let fatCalories = Double(calories) * 0.30
        
        // Convert to grams using USDA standard energy values
        // Protein: 4 cal/g, Carbs: 4 cal/g, Fat: 9 cal/g
        let proteinG = proteinCalories / 4.0
        let carbsG = carbsCalories / 4.0
        let fatG = fatCalories / 9.0
        
        return (proteinG: proteinG, carbsG: carbsG, fatG: fatG)
    }
    
    /// Calculate recommended calories and macros from user profile
    ///
    /// Uses the Harris-Benedict equation for BMR calculation:
    /// - Male: BMR = 88.362 + (13.397 × weight_kg) + (4.799 × height_cm) - (5.677 × age)
    /// - Female: BMR = 447.593 + (9.247 × weight_kg) + (3.098 × height_cm) - (4.330 × age)
    ///
    /// Reference: Harris JA, Benedict FG. "A Biometric Study of Human Basal Metabolism."
    /// Proceedings of the National Academy of Sciences. 1918;4(12):370-373.
    ///
    /// Activity multipliers based on Mifflin-St Jeor research:
    /// - Sedentary: 1.2, Lightly Active: 1.375, Moderately Active: 1.55
    /// - Very Active: 1.725, Extra Active: 1.9
    ///
    /// - Parameter repository: User profile repository
    /// - Returns: Tuple of (calories, proteinG, carbsG, fatG)
    static func calculateFromUserProfile(_ repository: UserProfileRepositoryProtocol) -> (calories: Int, proteinG: Double, carbsG: Double, fatG: Double) {
        // Get user profile data
        let weight = repository.getCurrentWeight()
        let heightFeet = repository.getHeightFeet()
        let heightInches = repository.getHeightInches()
        let gender = repository.getGender()
        let goalWeight = repository.getGoalWeight()
        
        // Calculate age from date of birth
        let dateOfBirth = repository.getDateOfBirth()
        let calendar = Calendar.current
        let age = calendar.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 30
        
        // Use default activity level and goal if not available
        let activityLevel = "moderately_active" // Default
        let goal = "maintain" // Default
        
        // Calculate BMR using Harris-Benedict equation
        let weightKg = weight * 0.453592
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
        
        // Calculate TDEE based on activity level
        let activityMultiplier: Double
        switch activityLevel.lowercased() {
        case "sedentary":
            activityMultiplier = 1.2
        case "lightly_active", "light":
            activityMultiplier = 1.375
        case "moderately_active", "moderate":
            activityMultiplier = 1.55
        case "very_active", "active":
            activityMultiplier = 1.725
        case "extra_active", "athlete":
            activityMultiplier = 1.9
        default:
            activityMultiplier = 1.55 // Default to moderate
        }
        
        var tdee = bmr * activityMultiplier
        
        // Adjust for weight goal
        if goalWeight < weight {
            // Weight loss: 500 cal deficit
            tdee -= 500
        } else if goalWeight > weight {
            // Weight gain: 300 cal surplus
            tdee += 300
        }
        
        let calories = max(1200, Int(tdee)) // Minimum 1200 calories
        
        // Calculate macros with protein multiplier based on goal
        var proteinMultiplier = 1.0
        switch goal.lowercased() {
        case "gain_weight", "weight_gain", "gain", "build_muscle":
            proteinMultiplier = 1.2 // Higher protein for muscle gain
        case "lose_weight", "weight_loss", "lose":
            proteinMultiplier = 1.1 // Higher protein to preserve muscle
        default:
            proteinMultiplier = 1.0
        }
        
        // Adjust protein based on activity level
        if activityLevel.lowercased() == "very_active" || activityLevel.lowercased() == "active" || 
           activityLevel.lowercased() == "extra_active" || activityLevel.lowercased() == "athlete" {
            proteinMultiplier *= 1.1
        }
        
        // Calculate macros
        let proteinCalories = Double(calories) * 0.30
        let carbsCalories = Double(calories) * 0.40
        let fatCalories = Double(calories) * 0.30
        
        let proteinG = (proteinCalories / 4.0) * proteinMultiplier
        let carbsG = carbsCalories / 4.0
        let fatG = fatCalories / 9.0
        
        return (calories: calories, proteinG: proteinG, carbsG: carbsG, fatG: fatG)
    }
}
