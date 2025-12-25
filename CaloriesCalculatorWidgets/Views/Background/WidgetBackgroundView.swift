//
//  WidgetBackgroundView.swift
//  CaloriesCalculatorWidgets
//
//  Background view for widget with gradient support
//

import SwiftUI

/// Widget background with optional gradient
struct WidgetBackgroundView: View {
    let style: BackgroundStyle
    
    enum BackgroundStyle {
        case solid
        case gradient
        case subtle
    }
    
    init(style: BackgroundStyle = .subtle) {
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .solid:
            WidgetColors.widgetBackground
        case .gradient:
            LinearGradient(
                colors: [
                    WidgetColors.widgetBackground,
                    WidgetColors.secondaryBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .subtle:
            WidgetColors.widgetBackground
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.03),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

/// Container view modifier for widget cards
struct WidgetCardModifier: ViewModifier {
    let padding: CGFloat
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(WidgetColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func widgetCard(
        padding: CGFloat = WidgetSpacing.medium,
        cornerRadius: CGFloat = WidgetSpacing.mediumRadius
    ) -> some View {
        modifier(WidgetCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}

// MARK: - Preview

#Preview("Solid Background") {
    WidgetBackgroundView(style: .solid)
        .frame(width: 200, height: 200)
}

#Preview("Gradient Background") {
    WidgetBackgroundView(style: .gradient)
        .frame(width: 200, height: 200)
}

#Preview("Subtle Background") {
    WidgetBackgroundView(style: .subtle)
        .frame(width: 200, height: 200)
}

#Preview("Card Modifier") {
    VStack {
        Text("Card Content")
            .widgetCard()
    }
    .padding()
    .background(WidgetColors.widgetBackground)
}
