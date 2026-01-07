//
//  WeightChangesCard.swift
//  playground
//
//  Weight Changes Chart Card showing changes over different timeframes with bar chart
//

import SwiftUI
import Charts

// MARK: - Weight Change Data Model
struct WeightChangeData: Identifiable {
    let id = UUID()
    let period: String
    let days: Int?
    let change: Double
    let hasData: Bool
    
    var color: Color {
        if !hasData { return .gray.opacity(0.3) }
        if abs(change) < 0.01 { return .blue }
        return change > 0 ? .orange : .green
    }
    
    var icon: String {
        if !hasData || abs(change) < 0.01 { return "minus" }
        return change > 0 ? "arrow.up" : "arrow.down"
    }
}

// MARK: - Weight Changes Chart Card
struct WeightChangesChartCard: View {
    let weightHistory: [WeightDataPoint]
    let currentWeight: Double
    let useMetricUnits: Bool
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    // Force view updates when weight history changes
    private var weightHistoryId: String {
        let count = weightHistory.count
        let mostRecent = weightHistory.last?.weight ?? currentWeight
        let mostRecentDate = weightHistory.last?.date.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        return "\(count)-\(String(format: "%.2f", mostRecent))-\(String(format: "%.2f", currentWeight))-\(Int(mostRecentDate))"
    }
    
    private var weightUnit: String {
        useMetricUnits ? "kg" : "lbs"
    }
    
    // Periods to display
    private var periods: [(label: String, days: Int?)] {
        [
            (localizationManager.localizedString(for: AppStrings.Progress.sevenDay), 7),
            (localizationManager.localizedString(for: AppStrings.Progress.fourteenDay), 14),
            (localizationManager.localizedString(for: AppStrings.Progress.thirtyDay), 30),
            (localizationManager.localizedString(for: AppStrings.Progress.ninetyDay), 90),
            (localizationManager.localizedString(for: AppStrings.Progress.allTime), nil)
        ]
    }
    
    private var chartData: [WeightChangeData] {
        periods.map { period in
            let result = weightChange(for: period.days)
            return WeightChangeData(
                period: period.label,
                days: period.days,
                change: result.change,
                hasData: result.hasChange
            )
        }
    }
    
    private var maxAbsChange: Double {
        let maxChange = chartData.filter { $0.hasData }.map { abs($0.change) }.max() ?? 1.0
        return max(maxChange, 0.5) // Minimum scale of 0.5 kg
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.weightChanges))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Progress.overDifferentPeriods))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Summary badge
                if let totalChange = chartData.last, totalChange.hasData {
                    HStack(spacing: 4) {
                        Image(systemName: totalChange.icon)
                            .font(.caption2)
                        Text(String(format: "%.1f %@", abs(totalChange.change), weightUnit))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(totalChange.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(totalChange.color.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            // Chart
            Chart(chartData) { data in
                BarMark(
                    x: .value("Period", data.period),
                    y: .value("Change", data.hasData ? data.change : 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: data.hasData ? 
                            (data.change > 0 ? [.orange, .red.opacity(0.8)] : [.green, .teal.opacity(0.8)]) :
                            [.gray.opacity(0.2), .gray.opacity(0.1)],
                        startPoint: data.change > 0 ? .bottom : .top,
                        endPoint: data.change > 0 ? .top : .bottom
                    )
                )
                .cornerRadius(6)
                .annotation(position: data.change >= 0 ? .top : .bottom, spacing: 4) {
                    if data.hasData && abs(data.change) > 0.01 {
                        Text(String(format: "%@%.1f", data.change > 0 ? "+" : "", data.change))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(data.color)
                    }
                }
            }
            .chartYScale(domain: -maxAbsChange * 1.3 ... maxAbsChange * 1.3)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let period = value.as(String.self) {
                            Text(period)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text(String(format: "%.1f", val))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartPlotStyle { plotContent in
                plotContent
                    .background(Color.clear)
            }
            .frame(height: 180)
            
            // Zero line indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text(localizationManager.localizedString(for: AppStrings.Progress.lost_))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                Text(localizationManager.localizedString(for: AppStrings.Progress.gained_))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .id(weightHistoryId)
    }
    
    // MARK: - Weight Change Calculation
    private func weightChange(for days: Int?) -> (change: Double, hasChange: Bool) {
        guard !weightHistory.isEmpty else {
            return (0, false)
        }
        
        // Sort history by date (most recent first)
        let sortedHistory = weightHistory.sorted { 
            if $0.date != $1.date {
                return $0.date > $1.date
            }
            return $0.weight > $1.weight
        }
        
        // Get the most recent weight
        guard let mostRecentWeight = sortedHistory.first?.weight else {
            return (0, false)
        }
        
        guard let days = days else {
            // All Time - compare most recent with oldest weight
            let oldestHistory = weightHistory.sorted { 
                if $0.date != $1.date {
                    return $0.date < $1.date
                }
                return $0.weight < $1.weight
            }
            guard let oldestWeight = oldestHistory.first?.weight else {
                return (0, false)
            }
            
            let change = mostRecentWeight - oldestWeight
            return (change, abs(change) > 0.01)
        }
        
        // For specific days, find weight at that point in time
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffDayStart = Calendar.current.startOfDay(for: cutoffDate)
        let todayStart = Calendar.current.startOfDay(for: Date())
        
        // Find entries before today (historical entries)
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
        
        // If no weight found at that date, but we have historical entries, use the oldest historical entry
        if let oldestHistorical = historicalEntries.sorted(by: { $0.date < $1.date }).first?.weight {
            let change = mostRecentWeight - oldestHistorical
            return (change, abs(change) > 0.01)
        }
        
        // If we only have today's entries, but there are multiple entries with different weights,
        // compare the most recent with the oldest entry in history (even if same day)
        if sortedHistory.count > 1 {
            let oldestEntry = sortedHistory.last!
            let change = mostRecentWeight - oldestEntry.weight
            return (change, abs(change) > 0.01)
        }
        
        return (0, false)
    }
}

// MARK: - Legacy Weight Changes Card (keeping for compatibility)
struct WeightChangesCard: View {
    let weightHistory: [WeightDataPoint]
    let currentWeight: Double
    let useMetricUnits: Bool
    
    var body: some View {
        WeightChangesChartCard(
            weightHistory: weightHistory,
            currentWeight: currentWeight,
            useMetricUnits: useMetricUnits
        )
    }
}

#Preview {
    VStack {
        WeightChangesChartCard(
            weightHistory: [
                WeightDataPoint(date: Calendar.current.date(byAdding: .day, value: -100, to: Date())!, weight: 80.0),
                WeightDataPoint(date: Calendar.current.date(byAdding: .day, value: -60, to: Date())!, weight: 78.0),
                WeightDataPoint(date: Calendar.current.date(byAdding: .day, value: -30, to: Date())!, weight: 76.5),
                WeightDataPoint(date: Calendar.current.date(byAdding: .day, value: -14, to: Date())!, weight: 75.0),
                WeightDataPoint(date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!, weight: 74.5),
                WeightDataPoint(date: Date(), weight: 74.0)
            ],
            currentWeight: 74.0,
            useMetricUnits: true
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
