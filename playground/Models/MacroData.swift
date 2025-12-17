//
//  MacroData.swift
//  playground
//
//  CalAI Clone - Macro nutritional data structure
//

import Foundation

/// Represents macronutrient data for a meal or food item
struct MacroData: Codable, Equatable, Hashable {
    var calories: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    
    enum CodingKeys: String, CodingKey {
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
    }
    
    init(calories: Int = 0, proteinG: Double = 0, carbsG: Double = 0, fatG: Double = 0) {
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }
    
    /// Returns a scaled version of the macro data based on portion ratio
    func scaled(by ratio: Double) -> MacroData {
        MacroData(
            calories: Int(Double(calories) * ratio),
            proteinG: proteinG * ratio,
            carbsG: carbsG * ratio,
            fatG: fatG * ratio
        )
    }
    
    /// Adds two MacroData instances together
    static func + (lhs: MacroData, rhs: MacroData) -> MacroData {
        MacroData(
            calories: lhs.calories + rhs.calories,
            proteinG: lhs.proteinG + rhs.proteinG,
            carbsG: lhs.carbsG + rhs.carbsG,
            fatG: lhs.fatG + rhs.fatG
        )
    }
    
    static let zero = MacroData()
}
