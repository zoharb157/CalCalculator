//
//  MacroValueView.swift
//  CaloriesCalculatorWidgets
//
//  Component for displaying a macro value with its unit
//

import SwiftUI

/// Displays a macro value with optional unit and styling
struct MacroValueView: View {
    let value: Int
    let unit: String
    let color: Color
    let size: ValueSize
    
    enum ValueSize {
        case small
        case medium
        case large
        
        var valueFont: Font {
            switch self {
            case .small: return WidgetTypography.smallValue
            case .medium: return WidgetTypography.mediumValue
            case .large: return WidgetTypography.largeValue
            }
        }
        
        var unitFont: Font {
            switch self {
            case .small: return WidgetTypography.smallUnit
            case .medium: return WidgetTypography.mediumUnit
            case .large: return WidgetTypography.largeUnit
            }
        }
    }
    
    init(
        value: Int,
        unit: String = "",
        color: Color = WidgetColors.primaryText,
        size: ValueSize = .medium
    ) {
        self.value = value
        self.unit = unit
        self.color = color
        self.size = size
    }
    
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text("\(value)")
                .font(size.valueFont)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            if !unit.isEmpty {
                Text(unit)
                    .font(size.unitFont)
                    .foregroundStyle(WidgetColors.secondaryText)
            }
        }
    }
}

/// Extended macro value view with progress indicator
struct MacroValueWithProgressView: View {
    let macroType: MacroType
    let macros: MacroNutrients
    let size: MacroValueView.ValueSize
    let showProgress: Bool
    
    init(
        macroType: MacroType,
        macros: MacroNutrients,
        size: MacroValueView.ValueSize = .medium,
        showProgress: Bool = true
    ) {
        self.macroType = macroType
        self.macros = macros
        self.size = size
        self.showProgress = showProgress
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: WidgetSpacing.extraSmall) {
            HStack {
                MacroValueView(
                    value: macroType.value(from: macros),
                    unit: macroType.unit,
                    color: WidgetColors.color(for: macroType),
                    size: size
                )
                
                Spacer()
                
                Text("/ \(macroType.goal(from: macros))")
                    .font(size == .small ? WidgetTypography.smallUnit : WidgetTypography.mediumUnit)
                    .foregroundStyle(WidgetColors.tertiaryText)
            }
            
            if showProgress {
                ProgressBarView(
                    progress: macroType.progress(from: macros),
                    color: WidgetColors.color(for: macroType),
                    height: size == .small ? WidgetSpacing.progressBarHeightSmall : WidgetSpacing.progressBarHeight
                )
            }
        }
    }
}

// Note: ProgressBarView is defined in MacroProgressRingView.swift

// MARK: - Preview

#Preview("Value Views") {
    VStack(spacing: 20) {
        MacroValueView(value: 1250, unit: "kcal", color: .orange, size: .large)
        MacroValueView(value: 85, unit: "g", color: .blue, size: .medium)
        MacroValueView(value: 45, unit: "g", color: .purple, size: .small)
    }
    .padding()
}

#Preview("Value with Progress") {
    VStack(spacing: 16) {
        MacroValueWithProgressView(
            macroType: .calories,
            macros: MockData.midDayProgress,
            size: .medium
        )
        MacroValueWithProgressView(
            macroType: .protein,
            macros: MockData.midDayProgress,
            size: .small
        )
    }
    .padding()
}

#Preview("Progress Bar") {
    VStack(spacing: 12) {
        ProgressBarView(progress: 0.65, color: .orange, height: 8)
        ProgressBarView(progress: 0.85, color: .blue, height: 6)
        ProgressBarView(progress: 0.45, color: .green, height: 4)
    }
    .padding()
}
