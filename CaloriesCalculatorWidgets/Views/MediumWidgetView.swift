//
//  MediumWidgetView.swift
//  CaloriesCalculatorWidgets
//
//  Modern medium widget view with detailed macro breakdown
//

import SwiftUI
import WidgetKit

/// Medium widget showing calorie progress with modern macro breakdown
struct MediumWidgetView: View {
    let macros: MacroNutrients
    
    private var calorieProgress: Double {
        guard macros.calorieGoal > 0 else { return 0 }
        return min(Double(macros.calories) / Double(macros.calorieGoal), 1.0)
    }
    
    private var isEmptyState: Bool {
        macros.calories == 0 && macros.protein == 0 && macros.carbs == 0 && macros.fats == 0
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - Calorie ring
            calorieSection
            
            // Divider
            Rectangle()
                .fill(WidgetColors.ringBackground)
                .frame(width: 1)
                .padding(.vertical, 8)
            
            // Right side - Macro progress
            macroSection
        }
        .padding(14)
    }
    
    // MARK: - Calorie Section
    
    private var calorieSection: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(WidgetColors.ringBackground, lineWidth: 8)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: calorieProgress)
                    .stroke(
                        WidgetColors.caloriesGradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                // Center content
                VStack(spacing: 2) {
                    if isEmptyState {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(WidgetColors.calories)
                    } else {
                        Text("\(macros.calories)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetColors.calories)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        
                        Text("kcal")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(WidgetColors.secondaryText)
                    }
                }
            }
            .frame(width: 90, height: 90)
            
            // Remaining
            if !isEmptyState {
                VStack(spacing: 1) {
                    Text("\(macros.remainingCalories)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetColors.primaryText)
                    
                    Text("remaining")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(WidgetColors.tertiaryText)
                }
            }
        }
        .frame(minWidth: 100)
    }
    
    // MARK: - Macro Section
    
    private var macroSection: some View {
        VStack(spacing: 10) {
            MacroRowView(
                type: .protein,
                value: macros.protein,
                goal: macros.proteinGoal
            )
            
            MacroRowView(
                type: .carbs,
                value: macros.carbs,
                goal: macros.carbsGoal
            )
            
            MacroRowView(
                type: .fats,
                value: macros.fats,
                goal: macros.fatsGoal
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Macro Row View

private struct MacroRowView: View {
    let type: MacroType
    let value: Int
    let goal: Int
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(value) / Double(goal), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header row
            HStack {
                // Colored dot and name
                HStack(spacing: 5) {
                    Circle()
                        .fill(WidgetColors.color(for: type))
                        .frame(width: 8, height: 8)
                    
                    Text(type.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WidgetColors.primaryText)
                }
                
                Spacer()
                
                // Values
                HStack(spacing: 2) {
                    Text("\(value)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetColors.color(for: type))
                    
                    Text("/\(goal)g")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WidgetColors.tertiaryText)
                }
            }
            
            // Progress bar
            ProgressBarView(
                progress: progress,
                color: WidgetColors.color(for: type),
                height: 6
            )
        }
    }
}

// MARK: - Preview

#Preview("Medium Widget", as: .systemMedium) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: MockData.midDayProgress)
    CaloriesEntry(macros: MockData.almostComplete)
}

#Preview("Medium Widget - Empty", as: .systemMedium) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: .empty)
}

#Preview("Medium Widget View") {
    MediumWidgetView(macros: MockData.midDayProgress)
        .frame(width: 360, height: 170)
        .background(WidgetColors.widgetBackground)
}

#Preview("Medium Widget View - Dark") {
    MediumWidgetView(macros: MockData.midDayProgress)
        .frame(width: 360, height: 170)
        .background(WidgetColors.widgetBackground)
        .preferredColorScheme(.dark)
}
