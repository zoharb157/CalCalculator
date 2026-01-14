//
//  WeightChangesCard.swift
//  playground
//
//  Weight Changes Chart Card showing all weight entries over time with a line chart
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

// MARK: - Weight Changes Chart Card (Linear Chart)
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
    
    // Convert and sort weight history for display
    private var displayWeights: [WeightDataPoint] {
        let convertedHistory: [WeightDataPoint] = useMetricUnits ? weightHistory : weightHistory.map { point in
            WeightDataPoint(date: point.date, weight: point.weight * 2.20462, note: point.note)
        }
        
        guard !convertedHistory.isEmpty else { return [] }
        
        // Sort by date
        return convertedHistory.sorted { $0.date < $1.date }
    }
    
    // Calculate min weight for Y-axis
    private var minWeight: Double {
        let weights = displayWeights.map(\.weight)
        guard let minValue = weights.min(), let maxValue = weights.max() else { return 0 }
        let range = maxValue - minValue
        
        if range == 0 || range < 0.1 {
            return Swift.max(0, minValue - 2.0)
        } else {
            let padding = min(range * 0.15, 3.0)
            return Swift.max(0, minValue - padding)
        }
    }
    
    // Calculate max weight for Y-axis
    private var maxWeight: Double {
        let weights = displayWeights.map(\.weight)
        guard let minValue = weights.min(), let maxValue = weights.max() else { return 100 }
        let range = maxValue - minValue
        
        if range == 0 || range < 0.1 {
            return maxValue + 0.5
        } else {
            let padding = min(range * 0.15, 3.0)
            return maxValue + padding
        }
    }
    
    // Calculate total weight change
    private var totalWeightChange: (change: Double, hasChange: Bool) {
        guard let first = displayWeights.first?.weight,
              let last = displayWeights.last?.weight else {
            return (0, false)
        }
        let change = last - first
        return (change, abs(change) > 0.01)
    }
    
    // Determine trend color
    private var trendColor: Color {
        let change = totalWeightChange.change
        if abs(change) < 0.01 { return .blue }
        return change > 0 ? .orange : .green
    }
    
    // Determine trend icon
    private var trendIcon: String {
        let change = totalWeightChange.change
        if abs(change) < 0.01 { return "minus" }
        return change > 0 ? "arrow.up" : "arrow.down"
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
                
                // Total change badge
                if totalWeightChange.hasChange {
                    HStack(spacing: 4) {
                        Image(systemName: trendIcon)
                            .font(.caption2)
                        Text(String(format: "%.1f %@", abs(totalWeightChange.change), weightUnit))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(trendColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(trendColor.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            // Line Chart
            if displayWeights.isEmpty || displayWeights.count < 2 {
                // Empty/insufficient data state
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text(localizationManager.localizedString(for: AppStrings.Progress.noWeightData))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Progress.saveWeightToSeeProgress))
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            } else {
                // Line chart showing all weight entries
                Chart(displayWeights) { point in
                    // Main line
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(
                        LinearGradient(
                            colors: totalWeightChange.change > 0 ? [.orange, .red.opacity(0.8)] : [.green, .teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    
                    // Data points
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(trendColor)
                    .symbolSize(30)
                }
                .chartYScale(domain: minWeight...maxWeight)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
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
            }
            
            // Legend
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
