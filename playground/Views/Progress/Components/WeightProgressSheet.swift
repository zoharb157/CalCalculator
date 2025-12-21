//
//  WeightProgressSheet.swift
//  playground
//
//  Sheet displaying weight history chart with time filters
//

import SwiftUI
import Charts

struct WeightProgressSheet: View {
    let weightHistory: [WeightDataPoint]
    @Binding var selectedFilter: TimeFilter
    let useMetricUnits: Bool
    let onFilterChange: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var displayWeights: [WeightDataPoint] {
        if useMetricUnits {
            return weightHistory
        } else {
            return weightHistory.map { point in
                WeightDataPoint(date: point.date, weight: point.weight * 2.20462)
            }
        }
    }
    
    var weightUnit: String {
        useMetricUnits ? "kg" : "lbs"
    }
    
    var minWeight: Double {
        (displayWeights.map(\.weight).min() ?? 0) - 5
    }
    
    var maxWeight: Double {
        (displayWeights.map(\.weight).max() ?? 100) + 5
    }
    
    var weightChange: Double {
        guard let first = displayWeights.first?.weight,
              let last = displayWeights.last?.weight else { return 0 }
        return last - first
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Filter Pills
                    filterSection
                    
                    // Summary Card
                    summaryCard
                    
                    // Chart
                    chartSection
                    
                    // Weight List
                    weightListSection
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Weight Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        HStack(spacing: 8) {
            ForEach(TimeFilter.allCases) { filter in
                Button {
                    withAnimation {
                        selectedFilter = filter
                        onFilterChange()
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedFilter == filter ? .semibold : .regular)
                        .foregroundColor(selectedFilter == filter ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? Color.blue : Color(.secondarySystemGroupedBackground))
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("Start")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1f", displayWeights.first?.weight ?? 0))
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(weightUnit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text("Current")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1f", displayWeights.last?.weight ?? 0))
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(weightUnit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("Change")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: weightChange >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption)
                    
                    Text(String(format: "%.1f", abs(weightChange)))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .foregroundColor(weightChange >= 0 ? .red : .green)
                
                Text(weightUnit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Chart Section
    
    @ViewBuilder
    private var chartSection: some View {
        if displayWeights.isEmpty {
            emptyChartView
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weight Trend")
                    .font(.headline)
                
                Chart(displayWeights) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(Color.blue)
                    .symbolSize(30)
                }
                .chartYScale(domain: minWeight...maxWeight)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let weight = value.as(Double.self) {
                                Text("\(Int(weight))")
                            }
                        }
                    }
                }
                .frame(height: 250)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var emptyChartView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Weight Data")
                .font(.headline)
            
            Text("Log your weight to see progress over time")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Weight List Section
    
    private var weightListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)
            
            if displayWeights.isEmpty {
                Text("No entries yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(displayWeights.reversed()) { point in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(point.dateString)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Text("\(String(format: "%.1f", point.weight)) \(weightUnit)")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

#Preview {
    WeightProgressSheet(
        weightHistory: [
            WeightDataPoint(date: Date().addingTimeInterval(-86400 * 30), weight: 80),
            WeightDataPoint(date: Date().addingTimeInterval(-86400 * 20), weight: 78.5),
            WeightDataPoint(date: Date().addingTimeInterval(-86400 * 10), weight: 77),
            WeightDataPoint(date: Date(), weight: 75.5)
        ],
        selectedFilter: .constant(.threeMonths),
        useMetricUnits: true,
        onFilterChange: {}
    )
}
