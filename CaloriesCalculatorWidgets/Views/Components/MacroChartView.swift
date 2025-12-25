//
//  MacroChartView.swift
//  CaloriesCalculatorWidgets
//
//  Chart visualization for macro nutrients using Swift Charts
//

import SwiftUI
import Charts

/// Chart data point for macro visualization
struct MacroChartData: Identifiable {
    let id = UUID()
    let type: MacroType
    let value: Int
    let goal: Int
    let percentage: Double
    
    var displayName: String { type.displayName }
    var shortName: String { type.shortName }
    
    init(type: MacroType, macros: MacroNutrients) {
        self.type = type
        self.value = type.value(from: macros)
        self.goal = type.goal(from: macros)
        self.percentage = type.progress(from: macros) * 100
    }
}

/// Bar chart showing macro progress
struct MacroBarChartView: View {
    let macros: MacroNutrients
    let showLegend: Bool
    
    init(macros: MacroNutrients, showLegend: Bool = true) {
        self.macros = macros
        self.showLegend = showLegend
    }
    
    private var chartData: [MacroChartData] {
        [
            MacroChartData(type: .protein, macros: macros),
            MacroChartData(type: .carbs, macros: macros),
            MacroChartData(type: .fats, macros: macros)
        ]
    }
    
    var body: some View {
        VStack(spacing: WidgetSpacing.small) {
            Chart(chartData) { data in
                BarMark(
                    x: .value("Macro", data.shortName),
                    y: .value("Progress", min(data.percentage, 100))
                )
                .foregroundStyle(WidgetColors.color(for: data.type))
                .cornerRadius(WidgetSpacing.smallRadius)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)%")
                                .font(WidgetTypography.chartLegend)
                                .foregroundStyle(WidgetColors.tertiaryText)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let name = value.as(String.self) {
                            Text(name)
                                .font(WidgetTypography.chartLabel)
                                .foregroundStyle(WidgetColors.secondaryText)
                        }
                    }
                }
            }
            
            if showLegend {
                HStack(spacing: WidgetSpacing.standard) {
                    ForEach(chartData) { data in
                        MacroLegendItem(
                            color: WidgetColors.color(for: data.type),
                            label: data.shortName,
                            value: "\(data.value)g"
                        )
                    }
                }
            }
        }
    }
}

/// Donut chart showing calorie breakdown
struct MacroDonutChartView: View {
    let macros: MacroNutrients
    let showCenter: Bool
    
    init(macros: MacroNutrients, showCenter: Bool = true) {
        self.macros = macros
        self.showCenter = showCenter
    }
    
    private var chartData: [MacroChartData] {
        [
            MacroChartData(type: .protein, macros: macros),
            MacroChartData(type: .carbs, macros: macros),
            MacroChartData(type: .fats, macros: macros)
        ]
    }
    
    var body: some View {
        Chart(chartData) { data in
            SectorMark(
                angle: .value("Grams", data.value),
                innerRadius: .ratio(0.6),
                angularInset: 2
            )
            .foregroundStyle(WidgetColors.color(for: data.type))
            .cornerRadius(4)
        }
        .chartBackground { chartProxy in
            if showCenter {
                GeometryReader { geometry in
                    let frame = geometry[chartProxy.plotFrame!]
                    VStack(spacing: 2) {
                        Text("\(macros.calories)")
                            .font(WidgetTypography.largeValue)
                            .fontWeight(.bold)
                            .foregroundStyle(WidgetColors.primaryText)
                        Text("kcal")
                            .font(WidgetTypography.chartLegend)
                            .foregroundStyle(WidgetColors.secondaryText)
                    }
                    .position(x: frame.midX, y: frame.midY)
                }
            }
        }
    }
}

/// Legend item for chart
struct MacroLegendItem: View {
    let color: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: WidgetSpacing.extraSmall) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(WidgetTypography.chartLegend)
                .foregroundStyle(WidgetColors.secondaryText)
            
            Text(value)
                .font(WidgetTypography.chartValue)
                .foregroundStyle(WidgetColors.primaryText)
        }
    }
}

// MARK: - Preview

#Preview("Bar Chart") {
    MacroBarChartView(macros: MockData.midDayProgress)
        .frame(height: 150)
        .padding()
}

#Preview("Donut Chart") {
    MacroDonutChartView(macros: MockData.midDayProgress)
        .frame(width: 150, height: 150)
        .padding()
}

#Preview("Donut Chart - Almost Complete") {
    MacroDonutChartView(macros: MockData.almostComplete)
        .frame(width: 150, height: 150)
        .padding()
}
