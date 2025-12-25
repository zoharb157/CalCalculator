//
//  Meal.swift
//  playground
//
//  CalAI Clone - Meal entity for storing analyzed meals
//

import Foundation
import SwiftData
import SwiftUI

enum MealCategory: String, Codable, CaseIterable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "leaf.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch: return .blue
        case .dinner: return .purple
        case .snack: return .green
        }
    }
}

/// Represents a complete meal with all its food items
@Model
final class Meal: Identifiable {
    var id: UUID
    var name: String
    var timestamp: Date
    var photoURL: String?
    var confidence: Double
    var notes: String?
    var category: MealCategory?
    
    @Relationship(deleteRule: .cascade)
    var items: [MealItem]
    
    init(
        id: UUID = UUID(),
        name: String,
        timestamp: Date = Date(),
        photoURL: String? = nil,
        confidence: Double = 0,
        notes: String? = nil,
        category: MealCategory? = nil,
        items: [MealItem] = []
    ) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.photoURL = photoURL
        self.confidence = confidence
        self.notes = notes
        self.category = category ?? Self.inferCategory(from: timestamp)
        self.items = items
    }
    
    /// Infer meal category from timestamp
    private static func inferCategory(from date: Date) -> MealCategory {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<21: return .dinner
        default: return .snack
        }
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
        timestamp.timeString
    }
    
    /// Formatted date string
    var formattedDate: String {
        timestamp.mediumDateString
    }
}

// Note: MealAnalysisResponse moved to FoodAnalysisService.swift for API integration
