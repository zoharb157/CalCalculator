//
//  Meal.swift
//  playground
//
//  CalAI Clone - Meal entity for storing analyzed meals
//

import Foundation
import SwiftData

/// Represents a complete meal with all its food items
@Model
final class Meal: Identifiable {
    var id: UUID
    var name: String
    var timestamp: Date
    var photoURL: String?
    var confidence: Double
    var notes: String?
    
    @Relationship(deleteRule: .cascade)
    var items: [MealItem]
    
    init(
        id: UUID = UUID(),
        name: String,
        timestamp: Date = Date(),
        photoURL: String? = nil,
        confidence: Double = 0,
        notes: String? = nil,
        items: [MealItem] = []
    ) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.photoURL = photoURL
        self.confidence = confidence
        self.notes = notes
        self.items = items
    }
    
    /// Computed total macros from all items
    var totalMacros: MacroData {
        items.reduce(MacroData.zero) { result, item in
            result + item.macros
        }
    }
    
    /// Total calories from all items
    var totalCalories: Int {
        totalMacros.calories
    }
    
    /// Formatted time string
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// Note: MealAnalysisResponse moved to FoodAnalysisService.swift for API integration
