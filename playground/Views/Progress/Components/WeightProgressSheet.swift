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
    @State private var selectedPoint: WeightDataPoint?
    
    var displayWeights: [WeightDataPoint] {
        if useMetricUnits {
            return weightHistory
        } else {
            return weightHistory.map { point in
                WeightDataPoint(date: point.date, weight: point.weight * 2.20462, note: point.note)
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
    
    var averageWeight: Double {
        guard !displayWeights.isEmpty else { return 0 }
        return displayWeights.map(\.weight).reduce(0, +) / Double(displayWeights.count)
    }
    
    var lowestWeight: Double {
        displayWeights.map(\.weight).min() ?? 0
    }
    
    var highestWeight: Double {
        displayWeights.map(\.weight).max() ?? 0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Filter Pills
                    filterSection
                    
                    // Summary Card
                    summaryCard
                    
                    // Stats Grid
                    statsGrid
                    
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimeFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                            onFilterChange()
                        }
                        HapticManager.shared.impact(.light)
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
            .padding(.horizontal, 4)
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
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Average",
                value: String(format: "%.1f", averageWeight),
                unit: weightUnit,
                icon: "chart.bar.fill",
                color: .blue
            )
            
            StatCard(
                title: "Lowest",
                value: String(format: "%.1f", lowestWeight),
                unit: weightUnit,
                icon: "arrow.down.circle.fill",
                color: .green
            )
            
            StatCard(
                title: "Highest",
                value: String(format: "%.1f", highestWeight),
                unit: weightUnit,
                icon: "arrow.up.circle.fill",
                color: .orange
            )
            
            StatCard(
                title: "Entries",
                value: "\(displayWeights.count)",
                unit: nil,
                icon: "list.bullet",
                color: .purple
            )
        }
    }
    
    // MARK: - Chart Section
    
    @ViewBuilder
    private var chartSection: some View {
        if displayWeights.isEmpty {
            emptyChartView
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Weight Trend")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(selectedFilter.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Chart(displayWeights) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
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
                    .foregroundStyle(selectedPoint?.id == point.id ? Color.orange : Color.blue)
                    .symbolSize(selectedPoint?.id == point.id ? 80 : 40)
                    .annotation(position: .top, spacing: 8) {
                        if selectedPoint?.id == point.id {
                            VStack(spacing: 2) {
                                Text(String(format: "%.1f %@", point.weight, weightUnit))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(point.dateString)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                    }
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
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let xPosition = value.location.x
                                        guard let date: Date = proxy.value(atX: xPosition) else { return }
                                        
                                        // Find closest point
                                        if let closest = displayWeights.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                            withAnimation(.easeInOut(duration: 0.1)) {
                                                selectedPoint = closest
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedPoint = nil
                                        }
                                    }
                            )
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
            HStack {
                Text("History")
                    .font(.headline)
                
                Spacer()
                
                Text("\(displayWeights.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if displayWeights.isEmpty {
                Text("No entries yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(displayWeights.reversed()) { point in
                    WeightHistoryRow(point: point, unit: weightUnit)
                }
            }
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let unit: String?
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                
                if let unit = unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Weight History Row

private struct WeightHistoryRow: View {
    let point: WeightDataPoint
    let unit: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let note = point.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text("\(String(format: "%.1f", point.weight)) \(unit)")
                .font(.headline)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var formattedDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(point.date) {
            return "Today"
        } else if calendar.isDateInYesterday(point.date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "E, MMM d"
            return formatter.string(from: point.date)
        }
    }
}

#Preview {
    WeightProgressSheet(
        weightHistory: [
            WeightDataPoint(date: Date().addingTimeInterval(-86400 * 30), weight: 80, note: "Started diet"),
            WeightDataPoint(date: Date().addingTimeInterval(-86400 * 20), weight: 78.5),
            WeightDataPoint(date: Date().addingTimeInterval(-86400 * 10), weight: 77, note: "Feeling good!"),
            WeightDataPoint(date: Date(), weight: 75.5)
        ],
        selectedFilter: .constant(.threeMonths),
        useMetricUnits: true,
        onFilterChange: {}
    )
}
