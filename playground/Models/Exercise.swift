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
    
    // Weight lifting specific fields (legacy - single set)
    var reps: Int? // Number of repetitions per set
    var sets: Int? // Number of sets
    var weight: Double? // Weight in lbs (will be converted based on user settings)
    
    // Weight lifting - multiple sets support (stored as JSON)
    var exerciseSetsData: Data? // JSON encoded [ExerciseSet]
    
    // Running specific fields
    var distance: Double? // Distance in km or miles
    var distanceUnit: DistanceUnit? // km or miles
    
    /// Computed property to get/set exercise sets
    var exerciseSets: [ExerciseSet] {
        get {
            guard let data = exerciseSetsData else { return [] }
            return (try? JSONDecoder().decode([ExerciseSet].self, from: data)) ?? []
        }
        set {
            exerciseSetsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    /// Calculate total volume for weight lifting (sets x reps x weight)
    var totalVolume: Double {
        if !exerciseSets.isEmpty {
            return exerciseSets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
        } else if let reps = reps, let sets = sets, let weight = weight {
            return Double(reps * sets) * weight
        }
        return 0
    }
    
    /// Calculate pace for running (min/km or min/mile)
    var pace: Double? {
        guard let distance = distance, distance > 0, duration > 0 else { return nil }
        return Double(duration) / distance
    }
    
    /// Formatted pace string
    var formattedPace: String? {
        guard let pace = pace, let unit = distanceUnit else { return nil }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        let unitStr = unit == .kilometers ? "km" : "miles"
        return String(format: "%d:%02d /%@", minutes, seconds, unitStr)
    }
    
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
        weight: Double? = nil,
        exerciseSets: [ExerciseSet]? = nil,
        distance: Double? = nil,
        distanceUnit: DistanceUnit? = nil
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
        self.distance = distance
        self.distanceUnit = distanceUnit
        // Normalize date to start of day for consistent querying (like WeightEntry)
        self.date = Calendar.current.startOfDay(for: date)
        
        // Encode exercise sets if provided
        if let sets = exerciseSets {
            self.exerciseSetsData = try? JSONEncoder().encode(sets)
        }
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

// MARK: - Distance Unit Enum

enum DistanceUnit: String, Codable, CaseIterable {
    case kilometers = "km"
    case miles = "mi"
    
    var displayName: String {
        switch self {
        case .kilometers: return "km"
        case .miles: return "miles"
        }
    }
    
    var longName: String {
        switch self {
        case .kilometers: return "Kilometers"
        case .miles: return "Miles"
        }
    }
}

// MARK: - Exercise Set Model

/// Represents a single set in a weight lifting exercise
struct ExerciseSet: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var reps: Int
    var weight: Double // in kg or lbs based on user preference
    
    init(id: UUID = UUID(), reps: Int = 10, weight: Double = 20.0) {
        self.id = id
        self.reps = reps
        self.weight = weight
    }
}

