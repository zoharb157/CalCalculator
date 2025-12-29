//
//  WeightChangesCard.swift
//  playground
//
//  Weight Changes card showing changes over different timeframes
//

import SwiftUI

struct WeightChangesCard: View {
    let weightHistory: [WeightDataPoint]
    let currentWeight: Double
    let useMetricUnits: Bool
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var weightUnit: String {
        useMetricUnits ? "kg" : "lbs"
    }
    
    private func weightChange(for days: Int?) -> (change: Double, hasChange: Bool) {
        guard let days = days else {
            // All Time - compare with first weight in history
            if let firstWeight = weightHistory.first?.weight {
                let change = currentWeight - firstWeight
                return (change, abs(change) > 0.01)
            }
            return (0, false)
        }
        
        // For specific days, find weight at that point in time
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        // Find the weight entry closest to (but before or at) the cutoff date
        // Sort by date descending to find the most recent entry before cutoff
        let sortedHistory = weightHistory.sorted { $0.date > $1.date }
        if let weightAtDate = sortedHistory.first(where: { $0.date <= cutoffDate })?.weight {
            let change = currentWeight - weightAtDate
            return (change, abs(change) > 0.01)
        }
        
        // If no weight found at that date, check if we have any history
        // If we have history but nothing at that date, show 0 change
        if !weightHistory.isEmpty {
            // Use first weight as baseline if no weight at specific date
            if let firstWeight = weightHistory.first?.weight {
                let change = currentWeight - firstWeight
                return (change, abs(change) > 0.01)
            }
        }
        
        return (0, false)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizationManager.localizedString(for: AppStrings.Progress.weightChanges))
                .font(.headline)
                .foregroundColor(.primary)
                .id("weight-changes-\(localizationManager.currentLanguage)")
            
            VStack(spacing: 12) {
                WeightChangeRow(
                    timeframe: "3 day",
                    change: weightChange(for: 3),
                    unit: weightUnit
                )
                
                WeightChangeRow(
                    timeframe: "7 day",
                    change: weightChange(for: 7),
                    unit: weightUnit
                )
                
                WeightChangeRow(
                    timeframe: "14 day",
                    change: weightChange(for: 14),
                    unit: weightUnit
                )
                
                WeightChangeRow(
                    timeframe: "30 day",
                    change: weightChange(for: 30),
                    unit: weightUnit
                )
                
                WeightChangeRow(
                    timeframe: "90 day",
                    change: weightChange(for: 90),
                    unit: weightUnit
                )
                
                WeightChangeRow(
                    timeframe: "All Time",
                    change: weightChange(for: nil),
                    unit: weightUnit
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

struct WeightChangeRow: View {
    let timeframe: String
    let change: (change: Double, hasChange: Bool)
    let unit: String
    
    var body: some View {
        Button {
            // Could navigate to detailed view
        } label: {
            HStack {
                Text(timeframe)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Small progress bar indicator
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 40, height: 4)
                    
                    if change.hasChange {
                        Text(String(format: "%.1f %@", abs(change.change), unit))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    } else {
                        Text("0.0 \(unit)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(change.hasChange ? (change.change >= 0 ? "Gained" : "Lost") : "No change")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

