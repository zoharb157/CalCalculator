//
//  ConfidenceLevel.swift
//  playground
//
//  Created by Bassam-Hillo on 18/12/2025.
//

import Foundation

enum ConfidenceLevel: String, Codable, CaseIterable {
    case high
    case medium
    case low
    
    var numericValue: Double {
        switch self {
        case .high: return 0.9
        case .medium: return 0.7
        case .low: return 0.5
        }
    }
    
    var displayText: String {
        switch self {
        case .high: return "High Confidence"
        case .medium: return "Medium Confidence"
        case .low: return "Low Confidence"
        }
    }
}
