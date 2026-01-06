//
//  WeightChangesCard.swift
//  playground
//
//  Weight Changes card showing changes over different timeframes
//

import SwiftUI

/// Card displaying weight changes over different timeframes (3 days, 7 days, 14 days, etc.)
/// Shows weight gain/loss for each timeframe with visual indicators
struct WeightChangesCard: View {
    let weightHistory: [WeightDataPoint]
    let currentWeight: Double
    let useMetricUnits: Bool
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    /// Computed ID that forces view updates when weight history or current weight changes
    /// Uses a combination of count, most recent weight, current weight, and date to detect changes
    /// Including currentWeight ensures updates when weight changes but history hasn't reloaded yet
    private var weightHistoryId: String {
        let count = weightHistory.count
        let mostRecent = weightHistory.last?.weight ?? currentWeight
        let mostRecentDate = weightHistory.last?.date.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        // Include currentWeight in the ID to force update when it changes
        // Format with 2 decimal places for precision
        return "\(count)-\(String(format: "%.2f", mostRecent))-\(String(format: "%.2f", currentWeight))-\(Int(mostRecentDate))"
    }
    
    private var weightUnit: String {
        useMetricUnits ? "kg" : "lbs"
    }
    
    private var weightChangesTitle: String {
        localizationManager.localizedString(for: AppStrings.Progress.weightChanges)
    }
    
    /// Calculates weight change for a specific timeframe
    /// - Parameter days: Number of days to look back, or nil for "All Time"
    /// - Returns: Tuple containing the weight change amount and whether a change exists
    /// Positive change = weight gain, negative change = weight loss
    private func weightChange(for days: Int?) -> (change: Double, hasChange: Bool) {
        // Ensure we have history to work with
        guard !weightHistory.isEmpty else {
            return (0, false)
        }
        
        // Sort history by date (most recent first), then by weight descending if same date
        // This ensures we get the latest weight for today if there are multiple entries on the same day
        let sortedHistory = weightHistory.sorted { 
            if $0.date != $1.date {
                return $0.date > $1.date // Most recent first
            }
            // If same date, prefer the entry with the later timestamp or higher weight
            // This handles cases where user updates weight multiple times in one day
            return $0.weight > $1.weight
        }
        
        // Get the most recent weight (first in sorted descending order)
        guard let mostRecentWeight = sortedHistory.first?.weight else {
            return (0, false)
        }
        
        guard let days = days else {
            // All Time - compare most recent with oldest weight
            let oldestHistory = weightHistory.sorted { 
                if $0.date != $1.date {
                    return $0.date < $1.date // Oldest first
                }
                return $0.weight < $1.weight // If same date, prefer lower weight (older entry)
            }
            guard let oldestWeight = oldestHistory.first?.weight else {
                return (0, false)
            }
            
            // Show change if weights are different (even if same day - user might have updated weight)
            // Threshold of 0.01 to account for floating point precision
            let change = mostRecentWeight - oldestWeight
            return (change, abs(change) > 0.01)
        }
        
        // For specific day ranges, find weight at that point in time
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffDayStart = Calendar.current.startOfDay(for: cutoffDate)
        let todayStart = Calendar.current.startOfDay(for: Date())
        
        // Find entries before today (historical entries, excluding today's entries)
        let historicalEntries = sortedHistory.filter { 
            Calendar.current.startOfDay(for: $0.date) < todayStart 
        }
        
        // Look for a weight entry on or before the cutoff date
        if let weightAtDate = historicalEntries.first(where: { 
            Calendar.current.startOfDay(for: $0.date) <= cutoffDayStart 
        })?.weight {
            let change = mostRecentWeight - weightAtDate
            return (change, abs(change) > 0.01)
        }
        
        // If no weight found at that exact date, but we have historical entries, use the oldest historical entry
        // This provides a fallback when the timeframe doesn't have an exact match
        if let oldestHistorical = historicalEntries.sorted(by: { $0.date < $1.date }).first?.weight {
            let change = mostRecentWeight - oldestHistorical
            return (change, abs(change) > 0.01)
        }
        
        // If we only have today's entries, but there are multiple entries with different weights,
        // compare the most recent with the oldest entry in history (even if same day)
        // This handles the case where user updates weight multiple times today
        if sortedHistory.count > 1 {
            let oldestEntry = sortedHistory.last!
            let change = mostRecentWeight - oldestEntry.weight
            return (change, abs(change) > 0.01)
        }
        
        // If we only have one entry, no change to show (need at least 2 entries for comparison)
        return (0, false)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(weightChangesTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                WeightChangeRow(
                    timeframe: localizationManager.localizedString(for: AppStrings.Progress.threeDay),
                    change: weightChange(for: 3),
                    unit: weightUnit,
                    localizationManager: localizationManager
                )
                
                WeightChangeRow(
                    timeframe: localizationManager.localizedString(for: AppStrings.Progress.sevenDay),
                    change: weightChange(for: 7),
                    unit: weightUnit,
                    localizationManager: localizationManager
                )
                
                WeightChangeRow(
                    timeframe: localizationManager.localizedString(for: AppStrings.Progress.fourteenDay),
                    change: weightChange(for: 14),
                    unit: weightUnit,
                    localizationManager: localizationManager
                )
                
                WeightChangeRow(
                    timeframe: localizationManager.localizedString(for: AppStrings.Progress.thirtyDay),
                    change: weightChange(for: 30),
                    unit: weightUnit,
                    localizationManager: localizationManager
                )
                
                WeightChangeRow(
                    timeframe: localizationManager.localizedString(for: AppStrings.Progress.ninetyDay),
                    change: weightChange(for: 90),
                    unit: weightUnit,
                    localizationManager: localizationManager
                )
                
                WeightChangeRow(
                    timeframe: localizationManager.localizedString(for: AppStrings.Progress.allTime),
                    change: weightChange(for: nil),
                    unit: weightUnit,
                    localizationManager: localizationManager
                )
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .id(weightHistoryId) // Force view refresh when history or current weight changes
    }
}

/// Individual row displaying weight change for a specific timeframe
/// Shows the timeframe label, change amount, and gain/loss/no change indicator
struct WeightChangeRow: View {
    let timeframe: String
    let change: (change: Double, hasChange: Bool)
    let unit: String
    @ObservedObject var localizationManager: LocalizationManager
    
    var body: some View {
        HStack {
            Text(timeframe)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                // Small visual progress bar indicator
                // Provides a subtle visual element to the row
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 40, height: 4)
                
                // Display change amount if change exists, otherwise show 0.0
                if change.hasChange {
                    Text(String(format: "%.1f %@", abs(change.change), unit))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                } else {
                    Text(String(format: "0.0 %@", unit))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Display localized gain/loss/no change text
                Text(change.hasChange ? (change.change >= 0 ? localizationManager.localizedString(for: AppStrings.Progress.gained_) : localizationManager.localizedString(for: AppStrings.Progress.lost_)) : localizationManager.localizedString(for: AppStrings.Progress.noChange))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    WeightChangesCard(
        weightHistory: [],
        currentWeight: 119,
        useMetricUnits: false
    )
    .padding()
}

