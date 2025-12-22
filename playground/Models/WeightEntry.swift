//
//  WeightEntry.swift
//  playground
//
//  Weight entry model for tracking weight history
//

import Foundation
import SwiftData

@Model
final class WeightEntry: Identifiable {
    var id: UUID
    var weight: Double // in lbs
    var date: Date
    
    init(id: UUID = UUID(), weight: Double, date: Date = Date()) {
        self.id = id
        self.weight = weight
        self.date = date
    }
}

