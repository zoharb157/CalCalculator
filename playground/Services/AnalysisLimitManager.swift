//
//  AnalysisLimitManager.swift
//  playground
//
//  Manages free analysis limit for non-subscribed users
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
    
    /// Check if user can perform analysis (subscribed or has free analysis left)
    func canPerformAnalysis(isSubscribed: Bool) -> Bool {
        if isSubscribed {
            return true
        }
        return currentAnalysisCount < freeAnalysisLimit
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
    
    /// Reset analysis count (for testing or subscription upgrade)
    func resetAnalysisCount() {
        userDefaults.removeObject(forKey: analysisCountKey)
        // Note: UserDefaults auto-syncs, synchronize() is deprecated and not needed
    }
    
    /// Get remaining free analyses
    func remainingFreeAnalyses(isSubscribed: Bool) -> Int {
        if isSubscribed {
            return Int.max // Unlimited for subscribers
        }
        return max(0, freeAnalysisLimit - currentAnalysisCount)
    }
}

