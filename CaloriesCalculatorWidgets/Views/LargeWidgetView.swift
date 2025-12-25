//
//  LargeWidgetView.swift
//  CaloriesCalculatorWidgets
//
//  Modern large widget view with comprehensive macro visualization
//

import SwiftUI
import WidgetKit
import Charts

/// Large widget showing comprehensive macro visualization with modern design
struct LargeWidgetView: View {
    let macros: MacroNutrients
    
    private var isEmptyState: Bool {
        macros.calories == 0 && macros.protein == 0 && macros.carbs == 0 && macros.fats == 0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection
            
            if isEmptyState {
                emptyStateView
            } else {
                // Main content
                HStack(spacing: 16) {
                    // Calorie ring
                    calorieRingSection
                    
                    // Macro cards
                    macroCardsSection
                }
                
                // Bottom progress bars
                macroProgressSection
            }
        }
        .padding(14)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Nutrition")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WidgetColors.primaryText)
                
                if !isEmptyState {
                    Text("\(macros.caloriePercentage)% of daily goal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WidgetColors.secondaryText)
                }
            }
            
            Spacer()
            
            // App icon / Today badge
            if !isEmptyState {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WidgetColors.calories)
                    
                    Text("Today")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WidgetColors.calories)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(WidgetColors.calories.opacity(0.15))
                .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(WidgetColors.calories.opacity(0.6))
            
            VStack(spacing: 4) {
                Text("No meals logged yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WidgetColors.primaryText)
                
                Text("Tap to start tracking your nutrition")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetColors.secondaryText)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Calorie Ring Section
    
    private var calorieRingSection: some View {
        VStack(spacing: 016) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(WidgetColors.ringBackground, lineWidth: 9)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: macros.calorieProgress)
                    .stroke(
                        WidgetColors.caloriesGradient,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                // Center content
                VStack(spacing: 2) {
                    Text("\(macros.calories)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetColors.calories)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    Text("of \(macros.calorieGoal)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WidgetColors.secondaryText)
                }
            }
            .frame(width: 110, height: 110)
            
            // Remaining badge
            VStack(spacing: 1) {
                Text("\(macros.remainingCalories)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.primaryText)
                
                Text("remaining")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WidgetColors.tertiaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(WidgetColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    // MARK: - Macro Cards Section
    
    private var macroCardsSection: some View {
        VStack(spacing: 10) {
            MacroCardView(type: .protein, value: macros.protein, goal: macros.proteinGoal)
            MacroCardView(type: .carbs, value: macros.carbs, goal: macros.carbsGoal)
            MacroCardView(type: .fats, value: macros.fats, goal: macros.fatsGoal)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Macro Progress Section
    
    private var macroProgressSection: some View {
        HStack(spacing: 12) {
            MacroProgressPill(type: .protein, progress: macros.proteinProgress)
            MacroProgressPill(type: .carbs, progress: macros.carbsProgress)
            MacroProgressPill(type: .fats, progress: macros.fatsProgress)
        }
    }
}

// MARK: - Macro Card View

private struct MacroCardView: View {
    let type: MacroType
    let value: Int
    let goal: Int
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(value) / Double(goal), 1.0)
    }
    
    private var percentage: Int {
        Int(progress * 100)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon ring
            ZStack {
                Circle()
                    .fill(WidgetColors.color(for: type).opacity(0.15))
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        WidgetColors.color(for: type),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                Text("\(percentage)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.color(for: type))
            }
            .frame(width: 32, height: 32)
            
            // Info
            VStack(alignment: .leading, spacing: 1) {
                Text(type.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetColors.primaryText)
                
                HStack(spacing: 2) {
                    Text("\(value)g")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetColors.color(for: type))
                    
                    Text("/ \(goal)g")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WidgetColors.tertiaryText)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WidgetColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Macro Progress Pill

private struct MacroProgressPill: View {
    let type: MacroType
    let progress: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(WidgetColors.color(for: type))
                .frame(width: 6, height: 6)
            
            Text(type.shortName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(WidgetColors.secondaryText)
            
            // Mini progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(WidgetColors.ringBackground)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(WidgetColors.color(for: type))
                        .frame(width: max(4, geometry.size.width * progress))
                }
            }
            .frame(width: 40, height: 4)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetColors.color(for: type))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(WidgetColors.cardBackground)
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview("Large Widget", as: .systemLarge) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: MockData.midDayProgress)
    CaloriesEntry(macros: MockData.almostComplete)
}

#Preview("Large Widget - Empty", as: .systemLarge) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: .empty)
}

#Preview("Large Widget View") {
    LargeWidgetView(macros: MockData.midDayProgress)
        .frame(width: 360, height: 380)
        .background(WidgetColors.widgetBackground)
}

#Preview("Large Widget View - Dark") {
    LargeWidgetView(macros: MockData.almostComplete)
        .frame(width: 360, height: 380)
        .background(WidgetColors.widgetBackground)
        .preferredColorScheme(.dark)
}
