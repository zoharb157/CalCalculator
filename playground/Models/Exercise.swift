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
    var duration: Int // in minutes (for cardio exercises)
    var intensity: ExerciseIntensity?
    var notes: String?
    var date: Date
    
    // Weight lifting specific fields
    var reps: Int? // Number of repetitions per set
    var sets: Int? // Number of sets
    var weight: Double? // Weight in lbs (will be converted based on user settings)
    
    init(
        id: UUID = UUID(),
        type: ExerciseType,
        calories: Int,
        duration: Int = 0,
        intensity: ExerciseIntensity? = nil,
        notes: String? = nil,
        date: Date = Date(),
        reps: Int? = nil,
        sets: Int? = nil,
        weight: Double? = nil
    ) {
        self.id = id
        self.type = type
        self.calories = calories
        self.duration = duration
        self.intensity = intensity
        self.notes = notes
        self.reps = reps
        self.sets = sets
        self.weight = weight
        // Normalize date to start of day for consistent querying (like WeightEntry)
        self.date = Calendar.current.startOfDay(for: date)
    }
}

// MARK: - Sendable Conformance
// Note: SwiftData's @Model macro adds Sendable conformance, but explicit extension is needed
// for Swift 6.0 strict concurrency when returning from main actor-isolated methods.
// The redundant conformance warning from the macro can be safely ignored.
extension Exercise: @unchecked Sendable {}

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

