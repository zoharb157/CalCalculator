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
    
    private var weightUnit: String {
        useMetricUnits ? "kg" : "lbs"
    }
    
    private var displayWeights: [WeightDataPoint] {
        // Convert units if needed
        let convertedHistory: [WeightDataPoint] = useMetricUnits ? weightHistory : weightHistory.map { point in
            WeightDataPoint(date: point.date, weight: point.weight * 2.20462, note: point.note)
        }
        
        guard !convertedHistory.isEmpty else { return [] }
        
        // Sort by date
        let sortedHistory = convertedHistory.sorted { $0.date < $1.date }
        
        // Get date range: from first entry to today
        guard let firstDate = sortedHistory.first?.date else { return [] }
        let lastDate = Date()
        
        // Create a dictionary for quick lookup
        var weightByDate: [Date: Double] = [:]
        for point in sortedHistory {
            let dayStart = Calendar.current.startOfDay(for: point.date)
            weightByDate[dayStart] = point.weight
        }
        
        // Fill in missing days with last known weight
        var filledData: [WeightDataPoint] = []
        var currentDate = Calendar.current.startOfDay(for: firstDate)
        var lastKnownWeight = sortedHistory.first?.weight ?? 0
        
        while currentDate <= lastDate {
            // Check if we have a weight for this day
            if let weight = weightByDate[currentDate] {
                lastKnownWeight = weight
                // Add the actual data point (with note if available)
                if let originalPoint = sortedHistory.first(where: { Calendar.current.isDate($0.date, inSameDayAs: currentDate) }) {
                    filledData.append(WeightDataPoint(date: currentDate, weight: weight, note: originalPoint.note))
                } else {
                    filledData.append(WeightDataPoint(date: currentDate, weight: weight, note: nil))
                }
            } else {
                // Use last known weight for this day
                filledData.append(WeightDataPoint(date: currentDate, weight: lastKnownWeight, note: nil))
            }
            
            // Move to next day
            guard let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return filledData
    }
    
    private var minWeight: Double {
        let weights = displayWeights.map(\.weight)
        guard let minValue = weights.min(), let maxValue = weights.max() else { return 0 }
        // Add padding below minimum
        return Swift.max(0, minValue - (maxValue - minValue) * 0.1)
    }
    
    private var maxWeight: Double {
        let weights = displayWeights.map(\.weight)
        guard let minValue = weights.min(), let maxValue = weights.max() else { return 100 }
        // Add padding above maximum
        return maxValue + (maxValue - minValue) * 0.1
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        VStack(alignment: .leading, spacing: 16) {
            Text(localizationManager.localizedString(for: AppStrings.Progress.weightChart))
                .font(.headline)
                .foregroundColor(.primary)
            
            if displayWeights.isEmpty {
                emptyStateView
            } else {
                chartView
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text(localizationManager.localizedString(for: AppStrings.Progress.noWeightData))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(localizationManager.localizedString(for: AppStrings.Progress.saveWeightToSeeProgress))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    @ViewBuilder
    private var chartView: some View {
        // Separate actual logged weights from filled-in weights
        let actualWeights = weightHistory.sorted { $0.date < $1.date }
        let actualWeightDates = Set(actualWeights.map { Calendar.current.startOfDay(for: $0.date) })
        
        Chart(displayWeights) { point in
            let dayStart = Calendar.current.startOfDay(for: point.date)
            let isActualData = actualWeightDates.contains(dayStart)
            
            // Blue line (shows for all days - continuous line)
            LineMark(
                x: .value("Date", point.date),
                y: .value("Weight", point.weight)
            )
            .foregroundStyle(Color.blue)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            
            // Blue circles only for days with actual logged weights
            if isActualData {
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(Color.blue)
                .symbolSize(45)
            }
        }
        .chartYScale(domain: minWeight...maxWeight)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.1))
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .foregroundStyle(.secondary)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.1))
                AxisValueLabel {
                    if let weight = value.as(Double.self) {
                        // Show as integer only (matching design image)
                        Text("\(Int(round(weight)))")
                            .foregroundStyle(.secondary)
                            .font(.caption2)
                    } else {
                        Text("")
                    }
                }
            }
        }
        .frame(height: 200)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.clear)
        }
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
    
    WeightChartCard(
        weightHistory: sampleData,
        useMetricUnits: true
    )
    .padding()
}

