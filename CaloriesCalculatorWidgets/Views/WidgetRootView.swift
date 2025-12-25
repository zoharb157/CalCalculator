//
//  WidgetRootView.swift
//  CaloriesCalculatorWidgets
//
//  Root view that selects the appropriate widget view based on family
//

import SwiftUI
import WidgetKit

/// Root view that selects the appropriate widget layout based on widget family
struct WidgetRootView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    
    let entry: CaloriesEntry
    
    var body: some View {
        Group {
            switch widgetFamily {
            case .systemSmall:
                SmallWidgetView(macros: entry.macros)
            case .systemMedium:
                MediumWidgetView(macros: entry.macros)
            case .systemLarge:
                LargeWidgetView(macros: entry.macros)
            case .systemExtraLarge:
                LargeWidgetView(macros: entry.macros)
            case .accessoryCircular:
                AccessoryCircularView(macros: entry.macros)
            case .accessoryRectangular:
                AccessoryRectangularView(macros: entry.macros)
            case .accessoryInline:
                AccessoryInlineView(macros: entry.macros)
            @unknown default:
                SmallWidgetView(macros: entry.macros)
            }
        }
        .containerBackground(for: .widget) {
            WidgetBackgroundView(style: .subtle)
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }
}

// MARK: - Accessory Views (Lock Screen)

/// Circular accessory widget for lock screen
struct AccessoryCircularView: View {
    let macros: MacroNutrients
    
    var body: some View {
        Gauge(value: macros.calorieProgress) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12))
        } currentValueLabel: {
            Text("\(macros.caloriePercentage)")
                .font(.system(size: 14, weight: .bold))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(WidgetColors.calories)
    }
}

/// Rectangular accessory widget for lock screen
struct AccessoryRectangularView: View {
    let macros: MacroNutrients
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                
                Text("\(macros.calories) / \(macros.calorieGoal) kcal")
                    .font(.system(size: 12, weight: .semibold))
            }
            
            ProgressView(value: macros.calorieProgress)
                .tint(WidgetColors.calories)
            
            HStack(spacing: 8) {
                accessoryMacroLabel(.protein)
                accessoryMacroLabel(.carbs)
                accessoryMacroLabel(.fats)
            }
            .font(.system(size: 10))
        }
    }
    
    private func accessoryMacroLabel(_ type: MacroType) -> some View {
        HStack(spacing: 2) {
            Text(type.shortName)
                .foregroundStyle(.secondary)
            Text("\(type.value(from: macros))g")
        }
    }
}

/// Inline accessory widget for lock screen
struct AccessoryInlineView: View {
    let macros: MacroNutrients
    
    var body: some View {
        Label {
            Text("\(macros.calories) / \(macros.calorieGoal) kcal")
        } icon: {
            Image(systemName: "flame.fill")
        }
    }
}

// MARK: - Preview

#Preview("Widget Root - Small", as: .systemSmall) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: MockData.midDayProgress)
}

#Preview("Widget Root - Medium", as: .systemMedium) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: MockData.midDayProgress)
}

#Preview("Widget Root - Large", as: .systemLarge) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: MockData.midDayProgress)
}

#Preview("Accessory Circular", as: .accessoryCircular) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: MockData.midDayProgress)
}

#Preview("Accessory Rectangular", as: .accessoryRectangular) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: MockData.midDayProgress)
}
