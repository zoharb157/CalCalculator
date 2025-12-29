//
//  Exercise.swift
//  playground
//
//  Exercise model for tracking workouts
//

import Foundation
import SwiftData

@Model
final class Exercise: Identifiable {
    var id: UUID
    var type: ExerciseType
    var calories: Int
    var duration: Int // in minutes
    var intensity: ExerciseIntensity?
    var notes: String?
    var date: Date
    
    init(
        id: UUID = UUID(),
        type: ExerciseType,
        calories: Int,
        duration: Int,
        intensity: ExerciseIntensity? = nil,
        notes: String? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.calories = calories
        self.duration = duration
        self.intensity = intensity
        self.notes = notes
        // Normalize date to start of day for consistent querying (like WeightEntry)
        self.date = Calendar.current.startOfDay(for: date)
    }
}

enum ExerciseType: String, Codable, CaseIterable {
    case run = "run"
    case weightLifting = "weight_lifting"
    case describe = "describe"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .run: return "Run"
        case .weightLifting: return "Weight lifting"
        case .describe: return "Describe"
        case .manual: return "Manual"
        }
    }
    
    var icon: String {
        switch self {
        case .run: return "figure.run"
        case .weightLifting: return "dumbbell.fill"
        case .describe: return "text.bubble"
        case .manual: return "flame.fill"
        }
    }
}

enum ExerciseIntensity: String, Codable, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

