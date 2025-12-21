//
//  CaloriesDetailSheet.swift
//  playground
//
//  Sheet displaying daily calorie breakdown with macro colors
//

import SwiftUI
import Charts

struct CaloriesDetailSheet: View {
    let dailyData: [DailyCalorieData]
    let averageCalories: Int
    @Binding var selectedFilter: CaloriesTimeFilter
    let onFilterChange: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDay: DailyCalorieData?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Filter Pills
                    filterSection
                    
                    // Average Summary
                    averageSummaryCard
                    
                    // Chart
                    chartSection
                    
                    // Daily Breakdown List
                    dailyBreakdownSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calories Breakdown")
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
            ForEach(CaloriesTimeFilter.allCases) { filter in
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
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? Color.orange : Color(.secondarySystemGroupedBackground))
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - Average Summary Card
    
    private var averageSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Average")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(averageCalories)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        
                        Text("cal")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(dailyData.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("days tracked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Average macro breakdown
            if !dailyData.isEmpty {
                let avgProtein = dailyData.reduce(0) { $0 + $1.protein } / Double(dailyData.count)
                let avgCarbs = dailyData.reduce(0) { $0 + $1.carbs } / Double(dailyData.count)
                let avgFat = dailyData.reduce(0) { $0 + $1.fat } / Double(dailyData.count)
                
                HStack(spacing: 16) {
                    MacroAverageView(
                        value: avgProtein,
                        label: "Protein",
                        color: .proteinColor
                    )
                    
                    MacroAverageView(
                        value: avgCarbs,
                        label: "Carbs",
                        color: .carbsColor
                    )
                    
                    MacroAverageView(
                        value: avgFat,
                        label: "Fat",
                        color: .fatColor
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Chart Section
    
    @ViewBuilder
    private var chartSection: some View {
        if dailyData.isEmpty {
            emptyChartView
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Calorie Trend")
                    .font(.headline)
                
                Chart(dailyData) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Calories", day.totalCalories)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let cal = value.as(Int.self) {
                                Text("\(cal)")
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var emptyChartView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Calorie Data")
                .font(.headline)
            
            Text("Start tracking meals to see your calorie trends")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Daily Breakdown Section
    
    private var dailyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Breakdown")
                .font(.headline)
            
            if dailyData.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(dailyData.reversed()) { day in
                    DayCalorieRow(data: day)
                }
            }
        }
    }
}

// MARK: - Macro Average View

struct MacroAverageView: View {
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(value))g")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text("avg \(label.lowercased())")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Day Calorie Row

struct DayCalorieRow: View {
    let data: DailyCalorieData
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.dateString)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Text("\(data.totalCalories) cal")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            // Stacked bar for macro breakdown
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    let total = Double(data.proteinCalories + data.carbsCalories + data.fatCalories)
                    
                    if total > 0 {
                        // Protein
                        let proteinWidth = (Double(data.proteinCalories) / total) * geometry.size.width
                        Rectangle()
                            .fill(Color.proteinColor)
                            .frame(width: max(proteinWidth - 1, 0))
                        
                        // Carbs
                        let carbsWidth = (Double(data.carbsCalories) / total) * geometry.size.width
                        Rectangle()
                            .fill(Color.carbsColor)
                            .frame(width: max(carbsWidth - 1, 0))
                        
                        // Fat
                        let fatWidth = (Double(data.fatCalories) / total) * geometry.size.width
                        Rectangle()
                            .fill(Color.fatColor)
                            .frame(width: max(fatWidth - 1, 0))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 8)
            
            // Legend
            HStack(spacing: 16) {
                MacroLegendItem(color: .proteinColor, label: "Protein", value: "\(Int(data.protein))g")
                MacroLegendItem(color: .carbsColor, label: "Carbs", value: "\(Int(data.carbs))g")
                MacroLegendItem(color: .fatColor, label: "Fat", value: "\(Int(data.fat))g")
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Macro Legend Item

struct MacroLegendItem: View {
    let color: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

#Preview {
    CaloriesDetailSheet(
        dailyData: [
            DailyCalorieData(date: Date().addingTimeInterval(-86400 * 6), totalCalories: 1850, protein: 120, carbs: 200, fat: 60),
            DailyCalorieData(date: Date().addingTimeInterval(-86400 * 5), totalCalories: 2100, protein: 130, carbs: 220, fat: 70),
            DailyCalorieData(date: Date().addingTimeInterval(-86400 * 4), totalCalories: 1950, protein: 125, carbs: 210, fat: 65),
            DailyCalorieData(date: Date().addingTimeInterval(-86400 * 3), totalCalories: 2200, protein: 140, carbs: 240, fat: 75),
            DailyCalorieData(date: Date().addingTimeInterval(-86400 * 2), totalCalories: 1800, protein: 110, carbs: 190, fat: 55),
            DailyCalorieData(date: Date().addingTimeInterval(-86400), totalCalories: 2000, protein: 130, carbs: 220, fat: 65),
            DailyCalorieData(date: Date(), totalCalories: 1900, protein: 125, carbs: 200, fat: 60)
        ],
        averageCalories: 1971,
        selectedFilter: .constant(.oneWeek),
        onFilterChange: {}
    )
}
