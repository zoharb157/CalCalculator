//
//  AnalysisLimitManager.swift
//  playground
//
//  Manages analysis tracking
//

import Foundation

/// Manager for tracking free analysis usage
@MainActor
final class AnalysisLimitManager {
    static let shared = AnalysisLimitManager()
    
    private let userDefaults = UserDefaults.standard
    private let analysisCountKey = "free_analysis_count"
    private let freeAnalysisLimit = 1 // One free analysis allowed
    
    private init() {}
    
    /// Get current analysis count
    var currentAnalysisCount: Int {
        userDefaults.integer(forKey: analysisCountKey)
    }
    
    /// Check if user can perform analysis - always true (app is free)
    func canPerformAnalysis() -> Bool {
        return true
    }
    
    /// Record that an analysis was performed
    /// Returns true if successfully recorded, false if limit already reached
    func recordAnalysis() -> Bool {
        let current = currentAnalysisCount
        guard current < freeAnalysisLimit else {
            return false // Limit already reached
        }
        userDefaults.set(current + 1, forKey: analysisCountKey)
        // Note: UserDefaults auto-syncs, synchronize() is deprecated and not needed
        return true
    }
    
    /// Reset analysis count (for testing)
    func resetAnalysisCount() {
        userDefaults.removeObject(forKey: analysisCountKey)
        // Note: UserDefaults auto-syncs, synchronize() is deprecated and not needed
    }
    
    /// Get remaining free analyses - unlimited (app is free)
    func remainingFreeAnalyses() -> Int {
        return Int.max
    }
}

