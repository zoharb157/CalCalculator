//
//  Models.swift
//  playground
//
//  Created by Bassam-Hillo on 18/12/2025.
//

import Foundation

// MARK: - API Request Model

struct AnalyzeRequest: Encodable {
    let image: String
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case image
        case userId = "user_id"
    }
}

// MARK: - API Response Models

struct AnalyzeResponse: Decodable {
    let ok: Bool
    let analysis: AnalysisData?
    let error: String?
    let exceptionType: String?
    
    enum CodingKeys: String, CodingKey {
        case ok
        case analysis
        case error
        case exceptionType = "exception_type"
    }
}

struct AnalysisData: Decodable {
    let foodDetected: Bool
    let foodName: String?
    let totalCalories: Int?
    let confidence: String?
    let breakdown: NutritionBreakdown?
    let items: [FoodItemData]?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case foodDetected = "food_detected"
        case foodName = "food_name"
        case totalCalories = "total_calories"
        case confidence
        case breakdown
        case items
        case notes
    }
}

struct NutritionBreakdown: Codable {
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    
    enum CodingKeys: String, CodingKey {
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
    }
    
    var toMacroData: MacroData {
        MacroData(
            calories: 0,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG
        )
    }
}

struct FoodItemData: Decodable {
    let name: String
    let calories: Int
    let portion: String
}

// MARK: - Domain Models

struct FoodItemResult {
    let name: String
    let calories: Int
    let portion: String
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    
    func toMealItem() -> MealItem {
        let (portionValue, unit) = parsePortionString(portion)
        
        return MealItem(
            name: name,
            portion: portionValue,
            unit: unit,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG
        )
    }
    
    private func parsePortionString(_ portion: String) -> (Double, String) {
        let pattern = "([0-9]+\\.?[0-9]*|[0-9]+/[0-9]+)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: portion, range: NSRange(portion.startIndex..., in: portion)),
              let range = Range(match.range(at: 1), in: portion) else {
            return (1.0, portion)
        }
        
        let numericPart = String(portion[range])
        let remainingPart = portion.replacingOccurrences(of: numericPart, with: "").trimmingCharacters(in: .whitespaces)
        let unit = remainingPart.isEmpty ? "serving" : remainingPart
        
        // Handle fraction format (e.g., "1/2")
        if numericPart.contains("/") {
            let parts = numericPart.split(separator: "/")
            if parts.count == 2,
               let numerator = Double(parts[0]),
               let denominator = Double(parts[1]),
               denominator != 0 {
                return (numerator / denominator, unit)
            }
        }
        
        // Handle decimal format
        if let value = Double(numericPart) {
            return (value, unit)
        }
        
        return (1.0, portion)
    }
}

struct FoodAnalysisResult {
    let foodDetected: Bool
    let mealName: String?
    let totalCalories: Int?
    let confidence: ConfidenceLevel?
    let breakdown: NutritionBreakdown?
    let items: [FoodItemResult]?
    let notes: String?
    
    func toMeal() -> Meal? {
        guard foodDetected, let mealName = mealName else {
            return nil
        }
        
        let meal = Meal(
            name: mealName,
            confidence: confidence?.numericValue ?? 0,
            notes: notes
        )
        
        if let items = items {
            meal.items = items.map { $0.toMealItem() }
        }
        
        return meal
    }
}
