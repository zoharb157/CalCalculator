//
//  MacroLabelView.swift
//  CaloriesCalculatorWidgets
//
//  Component for displaying macro labels with icons
//

import SwiftUI

/// Displays a macro label with optional icon
struct MacroLabelView: View {
    let macroType: MacroType
    let style: LabelStyle
    
    enum LabelStyle {
        case full       // "Calories"
        case short      // "Cal"
        case withIcon   // Icon + "Cal"
        case iconOnly   // Just icon
    }
    
    init(macroType: MacroType, style: LabelStyle = .short) {
        self.macroType = macroType
        self.style = style
    }
    
    var body: some View {
        HStack(spacing: WidgetSpacing.extraSmall) {
            if style == .withIcon || style == .iconOnly {
                iconView
            }
            
            if style != .iconOnly {
                Text(style == .full ? macroType.displayName : macroType.shortName)
                    .font(WidgetTypography.smallLabel)
                    .foregroundStyle(WidgetColors.secondaryText)
            }
        }
    }
    
    @ViewBuilder
    private var iconView: some View {
        Image(systemName: iconName)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(WidgetColors.color(for: macroType))
    }
    
    private var iconName: String {
        switch macroType {
        case .calories: return "flame.fill"
        case .protein: return "figure.strengthtraining.traditional"
        case .carbs: return "leaf.fill"
        case .fats: return "drop.fill"
        }
    }
}

/// Macro label with value underneath
struct MacroLabelWithValueView: View {
    let macroType: MacroType
    let value: Int
    let showUnit: Bool
    let alignment: HorizontalAlignment
    
    init(
        macroType: MacroType,
        value: Int,
        showUnit: Bool = true,
        alignment: HorizontalAlignment = .center
    ) {
        self.macroType = macroType
        self.value = value
        self.showUnit = showUnit
        self.alignment = alignment
    }
    
    var body: some View {
        VStack(alignment: alignment, spacing: WidgetSpacing.extraSmall) {
            MacroLabelView(macroType: macroType, style: .short)
            
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text("\(value)")
                    .font(WidgetTypography.smallValue)
                    .fontWeight(.bold)
                    .foregroundStyle(WidgetColors.color(for: macroType))
                
                if showUnit {
                    Text(macroType.unit)
                        .font(WidgetTypography.smallUnit)
                        .foregroundStyle(WidgetColors.tertiaryText)
                }
            }
        }
    }
}

/// Horizontal macro info row
struct MacroInfoRowView: View {
    let macroType: MacroType
    let macros: MacroNutrients
    
    var body: some View {
        HStack {
            HStack(spacing: WidgetSpacing.small) {
                Circle()
                    .fill(WidgetColors.color(for: macroType))
                    .frame(width: 10, height: 10)
                
                Text(macroType.displayName)
                    .font(WidgetTypography.mediumLabel)
                    .foregroundStyle(WidgetColors.primaryText)
            }
            
            Spacer()
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(macroType.value(from: macros))")
                    .font(WidgetTypography.mediumValue)
                    .fontWeight(.bold)
                    .foregroundStyle(WidgetColors.color(for: macroType))
                
                Text("/ \(macroType.goal(from: macros))\(macroType.unit)")
                    .font(WidgetTypography.smallUnit)
                    .foregroundStyle(WidgetColors.tertiaryText)
            }
        }
    }
}

// MARK: - Preview

#Preview("Label Styles") {
    VStack(spacing: 16) {
        MacroLabelView(macroType: .calories, style: .full)
        MacroLabelView(macroType: .protein, style: .short)
        MacroLabelView(macroType: .carbs, style: .withIcon)
        MacroLabelView(macroType: .fats, style: .iconOnly)
    }
    .padding()
}

#Preview("Label with Value") {
    HStack(spacing: 24) {
        MacroLabelWithValueView(macroType: .calories, value: 1250)
        MacroLabelWithValueView(macroType: .protein, value: 85)
        MacroLabelWithValueView(macroType: .carbs, value: 140)
        MacroLabelWithValueView(macroType: .fats, value: 45)
    }
    .padding()
}

#Preview("Info Row") {
    VStack(spacing: 12) {
        MacroInfoRowView(macroType: .protein, macros: MockData.midDayProgress)
        MacroInfoRowView(macroType: .carbs, macros: MockData.midDayProgress)
        MacroInfoRowView(macroType: .fats, macros: MockData.midDayProgress)
    }
    .padding()
}
