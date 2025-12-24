//
//  Models.swift
//  playground
//
//  Created by Bassam-Hillo on 18/12/2025.
//

import Foundation

// MARK: - Scan Mode

/// API scan modes for analyzing food
/// - `food`: Analyze a photo of food to estimate calories and nutrition
/// - `barcode`: Scan a product barcode to look up nutritional data
/// - `label`: Read nutrition facts labels or ingredients lists
enum ScanMode: String, Encodable {
    case food = "food"
    case barcode = "barcode"
    case label = "label"
}

// MARK: - API Request Model

struct AnalyzeRequest: Encodable {
    let image: String
    let userId: String
    let mode: ScanMode
    let foodHint: String?

    enum CodingKeys: String, CodingKey {
        case image
        case userId = "user_id"
        case mode
        case foodHint = "food_hint"
    }

    init(
        image: String,
        userId: String,
        mode: ScanMode = .food,
        foodHint: String? = nil
    ) {
        self.image = image
        self.userId = userId
        self.mode = mode
        self.foodHint = foodHint
    }
}

// MARK: - API Response Models

struct AnalyzeResponse: Decodable {
    let ok: Bool
    let mode: String?
    let analysis: AnalysisData?
    let error: String?
    let exceptionType: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case mode
        case analysis
        case error
        case exceptionType = "exception_type"
    }
}

struct AnalysisData: Decodable {
    let foodDetected: Bool
    let foodName: String?
    let brand: String?
    let totalCalories: Int?
    let confidence: String?
    let breakdown: NutritionBreakdown?
    let servingSize: String?
    let items: [FoodItemData]?
    let source: String?
    let barcode: String?
    let ingredients: IngredientsList?
    let labelType: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case foodDetected = "food_detected"
        case foodName = "food_name"
        case brand
        case totalCalories = "total_calories"
        case confidence
        case breakdown
        case servingSize = "serving_size"
        case items
        case source
        case barcode
        case ingredients
        case labelType = "label_type"
        case notes
    }
}

/// Ingredients can be either a string or an array of strings
enum IngredientsList: Decodable {
    case string(String)
    case array([String])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([String].self) {
            self = .array(arrayValue)
        } else {
            throw DecodingError.typeMismatch(
                IngredientsList.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or [String]"
                )
            )
        }
    }
    
    var asString: String? {
        switch self {
        case .string(let value): return value
        case .array(let values): return values.joined(separator: ", ")
        }
    }
    
    var asArray: [String] {
        switch self {
        case .string(let value): return [value]
        case .array(let values): return values
        }
    }
}

struct NutritionBreakdown: Codable {
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let sugarG: Double?
    let sodiumMg: Double?
    let saturatedFatG: Double?

    enum CodingKeys: String, CodingKey {
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
        case saturatedFatG = "saturated_fat_g"
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
            let match = regex.firstMatch(
                in: portion, range: NSRange(portion.startIndex..., in: portion)),
            let range = Range(match.range(at: 1), in: portion)
        else {
            return (1.0, portion)
        }

        let numericPart = String(portion[range])
        let remainingPart = portion.replacingOccurrences(of: numericPart, with: "")
            .trimmingCharacters(in: .whitespaces)
        let unit = remainingPart.isEmpty ? "serving" : remainingPart

        // Handle fraction format (e.g., "1/2")
        if numericPart.contains("/") {
            let parts = numericPart.split(separator: "/")
            if parts.count == 2,
                let numerator = Double(parts[0]),
                let denominator = Double(parts[1]),
                denominator != 0
            {
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
    let brand: String?
    let totalCalories: Int?
    let confidence: ConfidenceLevel?
    let breakdown: NutritionBreakdown?
    let servingSize: String?
    let items: [FoodItemResult]?
    let source: String?
    let barcode: String?
    let ingredients: IngredientsList?
    let labelType: String?
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
