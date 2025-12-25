//
//  SmallWidgetView.swift
//  CaloriesCalculatorWidgets
//
//  Modern small widget view with clean calorie display
//

import SwiftUI
import WidgetKit

/// Small widget showing compact, modern calorie progress
struct SmallWidgetView: View {
    let macros: MacroNutrients
    
    private var calorieProgress: Double {
        guard macros.calorieGoal > 0 else { return 0 }
        return min(Double(macros.calories) / Double(macros.calorieGoal), 1.0)
    }
    
    private var isEmptyState: Bool {
        macros.calories == 0 && macros.protein == 0 && macros.carbs == 0 && macros.fats == 0
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Main calorie ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(WidgetColors.ringBackground, lineWidth: 6)
                
                // Progress ring with gradient
                Circle()
                    .trim(from: 0, to: calorieProgress)
                    .stroke(
                        WidgetColors.caloriesGradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                // Center content
                VStack(spacing: 2) {
                    if isEmptyState {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(WidgetColors.calories)
                        
                        Text("Log food")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(WidgetColors.secondaryText)
                    } else {
                        Text("\(macros.calories)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetColors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        Text("of \(macros.calorieGoal)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(WidgetColors.secondaryText)
                    }
                }
            }
            .frame(width: 80, height: 80)
            
            // Macro mini indicators
            HStack(spacing: 12) {
                MacroMiniView(type: .protein, value: macros.protein, goal: macros.proteinGoal)
                MacroMiniView(type: .carbs, value: macros.carbs, goal: macros.carbsGoal)
                MacroMiniView(type: .fats, value: macros.fats, goal: macros.fatsGoal)
            }
        }
        .padding(12)
    }
}

// MARK: - Macro Mini View

private struct MacroMiniView: View {
    let type: MacroType
    let value: Int
    let goal: Int
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(value) / Double(goal), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 3) {
            // Mini progress ring
            ZStack {
                Circle()
                    .stroke(WidgetColors.ringBackground, lineWidth: 3)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        WidgetColors.color(for: type),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                Text("\(value)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.color(for: type))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: 26, height: 26)
            
            // Label
            Text(type.shortName)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(WidgetColors.tertiaryText)
        }
    }
}

// MARK: - Preview

#Preview("Small Widget", as: .systemSmall) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: MockData.midDayProgress)
    CaloriesEntry(macros: MockData.almostComplete)
    CaloriesEntry(macros: MockData.morningStart)
}

#Preview("Small Widget - Empty", as: .systemSmall) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: .empty)
}

#Preview("Small Widget View") {
    SmallWidgetView(macros: MockData.midDayProgress)
        .frame(width: 170, height: 170)
        .background(WidgetColors.widgetBackground)
}

#Preview("Small Widget View - Dark") {
    SmallWidgetView(macros: MockData.midDayProgress)
        .frame(width: 170, height: 170)
        .background(WidgetColors.widgetBackground)
        .preferredColorScheme(.dark)
}
