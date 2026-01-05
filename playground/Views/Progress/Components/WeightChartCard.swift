//
//  WeightChartCard.swift
//  playground
//
//  Weight Chart card displaying weight trend over time
//

import SwiftUI
import Charts

struct WeightChartCard: View {
    let weightHistory: [WeightDataPoint]
    let useMetricUnits: Bool
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var displayWeights: [WeightDataPoint] {
        let convertedHistory: [WeightDataPoint] = useMetricUnits ? weightHistory : weightHistory.map { point in
            WeightDataPoint(date: point.date, weight: point.weight * 2.20462, note: point.note)
        }
        
        guard !convertedHistory.isEmpty else { return [] }
        
        let sortedHistory = convertedHistory.sorted { $0.date < $1.date }
        
        var weightByDay: [Date: WeightDataPoint] = [:]
        for point in sortedHistory {
            let dayStart = Calendar.current.startOfDay(for: point.date)
            if let existing = weightByDay[dayStart] {
                if point.date > existing.date {
                    weightByDay[dayStart] = point
                }
            } else {
                weightByDay[dayStart] = point
            }
        }
        
        var changeEvents = weightByDay.values.sorted { $0.date < $1.date }
        
        if changeEvents.count == 1 {
            let singlePoint = changeEvents[0]
            let today = Calendar.current.startOfDay(for: Date())
            let singlePointDay = Calendar.current.startOfDay(for: singlePoint.date)
            
            if singlePointDay < today {
                changeEvents.append(WeightDataPoint(date: today, weight: singlePoint.weight, note: nil))
            } else if singlePointDay == today {
                if let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today) {
                    changeEvents.insert(WeightDataPoint(date: weekAgo, weight: singlePoint.weight, note: nil), at: 0)
                }
            }
        }
        
        return changeEvents.sorted { $0.date < $1.date }
    }
    
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
    
    private var isStable: Bool {
        let weights = displayWeights.map(\.weight)
        guard !weights.isEmpty, let firstWeight = weights.first else { return false }
        return weights.allSatisfy { abs($0 - firstWeight) < 0.1 }
    }
    
    private var stableWeight: Double {
        displayWeights.first?.weight ?? 0
    }
    
    private var weightTrend: (change: Double, isPositive: Bool) {
        guard let first = displayWeights.first?.weight,
              let last = displayWeights.last?.weight else { return (0, true) }
        let change = last - first
        return (change, change <= 0) // Negative change (weight loss) is typically positive
    }
    
    private var weightUnit: String {
        useMetricUnits ? "kg" : "lbs"
    }
    
    private var titleText: String {
        localizationManager.localizedString(for: AppStrings.Progress.weightChart)
    }
    
    private var noWeightDataText: String {
        localizationManager.localizedString(for: AppStrings.Progress.noWeightData)
    }
    
    private var saveWeightToSeeProgressText: String {
        localizationManager.localizedString(for: AppStrings.Progress.saveWeightToSeeProgress)
    }
    
    var body: some View {
        let weights = displayWeights
        let isEmpty = weights.isEmpty || weights.allSatisfy({ $0.weight == 0 })
        
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if !isEmpty && !isStable {
                        HStack(spacing: 4) {
                            Image(systemName: weightTrend.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption)
                            Text(String(format: "%@%.1f %@", weightTrend.change >= 0 ? "+" : "", weightTrend.change, weightUnit))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(weightTrend.isPositive ? .green : .orange)
                    }
                }
                
                Spacer()
                
                // Current weight badge
                if let currentWeight = weights.last?.weight {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f", currentWeight))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text(weightUnit)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text(noWeightDataText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(saveWeightToSeeProgressText)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else if isStable {
                // Stable state
                StableWeightView(
                    value: stableWeight,
                    unit: weightUnit
                )
            } else {
                // Trend chart
                TrendChartView(
                    weights: weights,
                    useMetricUnits: useMetricUnits,
                    minWeight: minWeight,
                    maxWeight: maxWeight
                )
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Stable State View
struct StableWeightView: View {
    let value: Double
    let unit: String
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var stableText: String {
        String(format: "%.1f %@ · %@", value, unit, localizationManager.localizedString(for: AppStrings.Progress.stableThisPeriod))
    }
    
    private var startText: String {
        localizationManager.localizedString(for: AppStrings.Progress.start)
    }
    
    private var nowText: String {
        localizationManager.localizedString(for: AppStrings.Progress.now)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status indicator
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(stableText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Mini chart line (visual representation)
            ZStack(alignment: .center) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 4)
                
                // Glow effect
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .cyan.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 8)
                    .blur(radius: 4)
                
                // Main line
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 4)
                
                // Endpoints
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                        .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 0)
                    Spacer()
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 10, height: 10)
                        .shadow(color: .cyan.opacity(0.3), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 8)
            
            // Time labels
            HStack {
                Text(startText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(nowText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Trend Chart View
struct TrendChartView: View {
    let weights: [WeightDataPoint]
    let useMetricUnits: Bool
    let minWeight: Double
    let maxWeight: Double
    
    var body: some View {
        let sortedWeights = weights.sorted { $0.date < $1.date }
        let firstPoint = sortedWeights.first
        let lastPoint = sortedWeights.last
        
        Chart(sortedWeights) { point in
            // Area fill
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Weight", point.weight)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Glow line (behind)
            LineMark(
                x: .value("Date", point.date),
                y: .value("Weight", point.weight)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            .foregroundStyle(Color.blue.opacity(0.15))
            
            // Main line
            LineMark(
                x: .value("Date", point.date),
                y: .value("Weight", point.weight)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .foregroundStyle(
                LinearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            // Dots at first and last points
            if point.date == firstPoint?.date || point.date == lastPoint?.date {
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(point.date == lastPoint?.date ? Color.cyan : Color.blue)
                .symbolSize(50)
                .annotation(position: .top, spacing: 6) {
                    if point.date == lastPoint?.date {
                        Text(String(format: "%.1f", point.weight))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                }
            }
        }
        .chartYScale(domain: minWeight...maxWeight)
        .chartPlotStyle { plotContent in
            plotContent
                .padding(.top, 30)
                .padding(.bottom, 8)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel {
                    if let weight = value.as(Double.self) {
                        Text(String(format: "%.0f", weight))
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .frame(height: 180)
    }
}

#Preview {
    let sampleData = [
        WeightDataPoint(date: Calendar.current.date(byAdding: .month, value: -8, to: Date())!, weight: 70.0),
        WeightDataPoint(date: Calendar.current.date(byAdding: .month, value: -6, to: Date())!, weight: 65.0),
        WeightDataPoint(date: Calendar.current.date(byAdding: .month, value: -4, to: Date())!, weight: 57.5),
        WeightDataPoint(date: Calendar.current.date(byAdding: .month, value: -2, to: Date())!, weight: 55.0),
        WeightDataPoint(date: Date(), weight: 54.7)
    ]
    
    VStack {
        WeightChartCard(
            weightHistory: sampleData,
            useMetricUnits: true
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
