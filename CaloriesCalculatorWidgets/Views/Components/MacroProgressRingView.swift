//
//  MacroProgressRingView.swift
//  CaloriesCalculatorWidgets
//
//  Modern circular progress ring component with gradient styling
//

import SwiftUI

/// A modern circular progress ring for displaying macro nutrient progress
struct MacroProgressRingView: View {
    let macroType: MacroType
    let progress: Double
    let value: Int
    let goal: Int
    let size: WidgetSpacing.RingSize
    let showLabel: Bool
    let showValue: Bool
    let useGradient: Bool
    
    init(
        macroType: MacroType,
        progress: Double,
        value: Int,
        goal: Int,
        size: WidgetSpacing.RingSize = .medium,
        showLabel: Bool = true,
        showValue: Bool = true,
        useGradient: Bool = true
    ) {
        self.macroType = macroType
        self.progress = min(max(progress, 0), 1.0)
        self.value = value
        self.goal = goal
        self.size = size
        self.showLabel = showLabel
        self.showValue = showValue
        self.useGradient = useGradient
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    WidgetColors.ringBackground,
                    lineWidth: size.lineWidth
                )
            
            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    useGradient ? AnyShapeStyle(WidgetColors.gradient(for: macroType)) : AnyShapeStyle(WidgetColors.color(for: macroType)),
                    style: StrokeStyle(
                        lineWidth: size.lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
            
            // Center content
            if showValue || showLabel {
                VStack(spacing: 0) {
                    if showValue {
                        Text("\(value)")
                            .font(valueFont)
                            .fontWeight(.bold)
                            .foregroundStyle(WidgetColors.color(for: macroType))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    
                    if showLabel {
                        Text(macroType.shortName)
                            .font(labelFont)
                            .fontWeight(.medium)
                            .foregroundStyle(WidgetColors.secondaryText)
                    }
                }
                .padding(2)
            }
        }
        .frame(width: size.diameter, height: size.diameter)
    }
    
    // MARK: - Private Helpers
    
    private var valueFont: Font {
        switch size {
        case .tiny: return .system(size: 9, weight: .bold, design: .rounded)
        case .small: return .system(size: 11, weight: .bold, design: .rounded)
        case .medium: return .system(size: 14, weight: .bold, design: .rounded)
        case .large: return .system(size: 20, weight: .bold, design: .rounded)
        case .extraLarge: return .system(size: 26, weight: .bold, design: .rounded)
        }
    }
    
    private var labelFont: Font {
        switch size {
        case .tiny: return .system(size: 7, weight: .medium)
        case .small: return .system(size: 8, weight: .medium)
        case .medium: return .system(size: 9, weight: .medium)
        case .large: return .system(size: 11, weight: .medium)
        case .extraLarge: return .system(size: 13, weight: .medium)
        }
    }
}

// MARK: - Convenience Initializer

extension MacroProgressRingView {
    init(
        macroType: MacroType,
        macros: MacroNutrients,
        size: WidgetSpacing.RingSize = .medium,
        showLabel: Bool = true,
        showValue: Bool = true,
        useGradient: Bool = true
    ) {
        self.macroType = macroType
        self.progress = min(max(macroType.progress(from: macros), 0), 1.0)
        self.value = macroType.value(from: macros)
        self.goal = macroType.goal(from: macros)
        self.size = size
        self.showLabel = showLabel
        self.showValue = showValue
        self.useGradient = useGradient
    }
}

// MARK: - Modern Progress Bar

struct ProgressBarView: View {
    let progress: Double
    let color: Color
    let height: CGFloat
    let showGradient: Bool
    
    init(progress: Double, color: Color, height: CGFloat = 8, showGradient: Bool = true) {
        self.progress = min(max(progress, 0), 1.0)
        self.color = color
        self.height = height
        self.showGradient = showGradient
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(WidgetColors.progressBarBackground)
                
                // Progress
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        showGradient
                            ? AnyShapeStyle(LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            : AnyShapeStyle(color)
                    )
                    .frame(width: max(height, geometry.size.width * progress))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Preview

#Preview("Ring Sizes") {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            MacroProgressRingView(
                macroType: .calories,
                macros: MockData.midDayProgress,
                size: .tiny
            )
            MacroProgressRingView(
                macroType: .protein,
                macros: MockData.midDayProgress,
                size: .small
            )
            MacroProgressRingView(
                macroType: .carbs,
                macros: MockData.midDayProgress,
                size: .medium
            )
        }
        
        HStack(spacing: 20) {
            MacroProgressRingView(
                macroType: .fats,
                macros: MockData.midDayProgress,
                size: .large
            )
            MacroProgressRingView(
                macroType: .calories,
                macros: MockData.almostComplete,
                size: .extraLarge
            )
        }
    }
    .padding()
}

#Preview("Progress Bars") {
    VStack(spacing: 16) {
        ProgressBarView(progress: 0.6, color: WidgetColors.protein)
        ProgressBarView(progress: 0.8, color: WidgetColors.carbs)
        ProgressBarView(progress: 0.4, color: WidgetColors.fats)
    }
    .padding()
}
