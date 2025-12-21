//
//  WeightEntry.swift
//  playground
//
//  Model for tracking weight history
//

import Foundation
import SwiftData

/// Represents a single weight entry for tracking progress
@Model
final class WeightEntry {
    var id: UUID
    var weight: Double // in kg
    var date: Date
    var note: String?
    
    init(
        id: UUID = UUID(),
        weight: Double,
        date: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.weight = weight
        self.date = Calendar.current.startOfDay(for: date)
        self.note = note
    }
    
    /// Weight in pounds
    var weightInPounds: Double {
        weight * 2.20462
    }
    
    /// Formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Short date string
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
