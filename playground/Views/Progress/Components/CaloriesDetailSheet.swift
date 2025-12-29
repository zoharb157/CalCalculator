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
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDay: DailyCalorieData?
    @State private var animateChart = false
    
    // Computed stats
    private var totalCalories: Int {
        dailyData.reduce(0) { $0 + $1.totalCalories }
    }
    
    private var highestDay: DailyCalorieData? {
        dailyData.max(by: { $0.totalCalories < $1.totalCalories })
    }
    
    private var lowestDay: DailyCalorieData? {
        dailyData.min(by: { $0.totalCalories < $1.totalCalories })
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Filter Pills
                    filterSection
                    
                    // Average Summary
                    averageSummaryCard
                    
                    // Stats Grid
                    statsGridSection
                    
                    // Chart
                    chartSection
                    
                    // Daily Breakdown List
                    dailyBreakdownSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Progress.caloriesBreakdown))
                .id("calories-breakdown-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                        dismiss()
                    }
                    .id("done-calories-detail-\(localizationManager.currentLanguage)")
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    animateChart = true
                }
            }
        }
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CaloriesTimeFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                            animateChart = false
                        }
                        HapticManager.shared.impact(.light)
                        onFilterChange()
                        
                        // Re-animate chart immediately
                        withAnimation(.easeOut(duration: 0.5)) {
                            animateChart = true
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
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Average Summary Card
    
    private var averageSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.dailyAverage))
                        .id("daily-average-\(localizationManager.currentLanguage)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(averageCalories)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        
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
                        .contentTransition(.numericText())
                    
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
    
    // MARK: - Stats Grid Section
    
    private var statsGridSection: some View {
        HStack(spacing: 12) {
            CalorieStatCard(
                title: "Total",
                value: formatNumber(totalCalories),
                unit: "cal",
                icon: "flame.fill",
                color: .orange
            )
            
            if let highest = highestDay {
                CalorieStatCard(
                    title: "Highest",
                    value: "\(highest.totalCalories)",
                    unit: highest.shortDateString,
                    icon: "arrow.up.circle.fill",
                    color: .red
                )
            }
            
            if let lowest = lowestDay {
                CalorieStatCard(
                    title: "Lowest",
                    value: "\(lowest.totalCalories)",
                    unit: lowest.shortDateString,
                    icon: "arrow.down.circle.fill",
                    color: .green
                )
            }
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 10000 {
            return String(format: "%.1fk", Double(number) / 1000)
        }
        return "\(number)"
    }
    
    // MARK: - Chart Section
    
    @ViewBuilder
    private var chartSection: some View {
        if dailyData.isEmpty {
            emptyChartView
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.calorieTrend))
                        .id("calorie-trend-\(localizationManager.currentLanguage)")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(selectedFilter.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Chart(dailyData) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Calories", animateChart ? day.totalCalories : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                    
                    // Goal line
                    let goal = UserSettings.shared.calorieGoal
                    if goal > 0 {
                        RuleMark(y: .value("Goal", goal))
                            .foregroundStyle(.green.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("\(localizationManager.localizedString(for: AppStrings.Home.goalLabel)) \(goal)")
                                    .id("goal-label-\(localizationManager.currentLanguage)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                    }
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
                                        
                                        // Find closest day
                                        if let closest = dailyData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                            withAnimation(.easeInOut(duration: 0.1)) {
                                                selectedDay = closest
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedDay = nil
                                        }
                                    }
                            )
                    }
                }
                .frame(height: 200)
                
                // Selected day info
                if let selected = selectedDay {
                    HStack {
                        Text(selected.dateString)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(selected.totalCalories) cal")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .animation(.easeInOut(duration: 0.2), value: selectedDay?.id)
        }
    }
    
    private var emptyChartView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(localizationManager.localizedString(for: AppStrings.Progress.noCalorieData))
                .id("no-calorie-data-\(localizationManager.currentLanguage)")
                .font(.headline)
            
            Text(localizationManager.localizedString(for: AppStrings.Progress.startTrackingMeals))
                .id("start-tracking-\(localizationManager.currentLanguage)")
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
            HStack {
                Text(localizationManager.localizedString(for: AppStrings.Progress.dailyBreakdown))
                    .id("daily-breakdown-\(localizationManager.currentLanguage)")
                    .font(.headline)
                
                Spacer()
                
                Text("\(dailyData.count) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if dailyData.isEmpty {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.noDataAvailable))
                    .id("no-data-\(localizationManager.currentLanguage)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(Array(dailyData.reversed().enumerated()), id: \.element.id) { index, day in
                    DayCalorieRow(data: day, isHighest: day.id == highestDay?.id, isLowest: day.id == lowestDay?.id)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
    }
}

// MARK: - Calorie Stat Card

private struct CalorieStatCard: View {
    let title: String
    let value: String
    let unit: String
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
                
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
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
    var isHighest: Bool = false
    var isLowest: Bool = false
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(formattedDate)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if isHighest {
                            Text(localizationManager.localizedString(for: AppStrings.Progress.highest))
                                .id("highest-\(localizationManager.currentLanguage)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Capsule())
                        } else if isLowest {
                            Text(localizationManager.localizedString(for: AppStrings.Progress.lowest))
                                .id("lowest-\(localizationManager.currentLanguage)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
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
    
    private var formattedDate: String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(data.date) {
            return "Today"
        } else if calendar.isDateInYesterday(data.date) {
            return "Yesterday"
        } else {
            return data.dateString
        }
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
