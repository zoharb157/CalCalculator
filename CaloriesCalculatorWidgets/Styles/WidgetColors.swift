//
//  WidgetColors.swift
//  CaloriesCalculatorWidgets
//
//  Modern color definitions for widget styling with vibrant gradients
//

import SwiftUI

/// Semantic colors for the calories widget with modern, vibrant design
enum WidgetColors {
    
    // MARK: - Primary Macro Colors (Vibrant & Modern)
    
    /// Calories - Warm Orange to Red gradient
    static let calories = Color(red: 1.0, green: 0.45, blue: 0.25)
    static let caloriesSecondary = Color(red: 1.0, green: 0.3, blue: 0.15)
    
    /// Protein - Deep Blue to Cyan
    static let protein = Color(red: 0.25, green: 0.55, blue: 1.0)
    static let proteinSecondary = Color(red: 0.15, green: 0.4, blue: 0.9)
    
    /// Carbs - Fresh Green to Teal
    static let carbs = Color(red: 0.2, green: 0.85, blue: 0.55)
    static let carbsSecondary = Color(red: 0.1, green: 0.7, blue: 0.45)
    
    /// Fats - Rich Purple to Pink
    static let fats = Color(red: 0.7, green: 0.35, blue: 0.95)
    static let fatsSecondary = Color(red: 0.55, green: 0.25, blue: 0.85)
    
    // MARK: - Gradient Definitions
    
    static let caloriesGradient = LinearGradient(
        colors: [calories, caloriesSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let proteinGradient = LinearGradient(
        colors: [protein, proteinSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let carbsGradient = LinearGradient(
        colors: [carbs, carbsSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let fatsGradient = LinearGradient(
        colors: [fats, fatsSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Angular Gradients for Rings
    
    static func angularGradient(for macroType: MacroType, progress: Double) -> AngularGradient {
        let colors: [Color]
        switch macroType {
        case .calories:
            colors = [caloriesSecondary, calories, calories]
        case .protein:
            colors = [proteinSecondary, protein, protein]
        case .carbs:
            colors = [carbsSecondary, carbs, carbs]
        case .fats:
            colors = [fatsSecondary, fats, fats]
        }
        
        return AngularGradient(
            colors: colors,
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * progress)
        )
    }
    
    // MARK: - Background Colors (Adaptive for Light/Dark mode)
    
    static let widgetBackground = Color(
        light: Color.white,
        dark: Color(red: 0.08, green: 0.08, blue: 0.10)
    )
    
    static let cardBackground = Color(
        light: Color(red: 0.97, green: 0.97, blue: 0.98),
        dark: Color(red: 0.14, green: 0.14, blue: 0.16)
    )
    
    static let secondaryBackground = Color(
        light: Color(red: 0.94, green: 0.94, blue: 0.96),
        dark: Color(red: 0.18, green: 0.18, blue: 0.20)
    )
    
    // MARK: - Text Colors
    
    static let primaryText = Color(
        light: Color(red: 0.1, green: 0.1, blue: 0.12),
        dark: Color.white
    )
    
    static let secondaryText = Color(
        light: Color(red: 0.45, green: 0.45, blue: 0.5),
        dark: Color(red: 0.65, green: 0.65, blue: 0.7)
    )
    
    static let tertiaryText = Color(
        light: Color(red: 0.6, green: 0.6, blue: 0.65),
        dark: Color(red: 0.5, green: 0.5, blue: 0.55)
    )
    
    // MARK: - Ring Background
    
    static let ringBackground = Color(
        light: Color(red: 0.92, green: 0.92, blue: 0.94),
        dark: Color(red: 0.22, green: 0.22, blue: 0.25)
    )
    
    static let progressBarBackground = Color(
        light: Color(red: 0.90, green: 0.90, blue: 0.92),
        dark: Color(red: 0.25, green: 0.25, blue: 0.28)
    )
    
    // MARK: - Helper Methods
    
    static func color(for macroType: MacroType) -> Color {
        switch macroType {
        case .calories: return calories
        case .protein: return protein
        case .carbs: return carbs
        case .fats: return fats
        }
    }
    
    static func gradient(for macroType: MacroType) -> LinearGradient {
        switch macroType {
        case .calories: return caloriesGradient
        case .protein: return proteinGradient
        case .carbs: return carbsGradient
        case .fats: return fatsGradient
        }
    }
    
    static func colorPair(for macroType: MacroType) -> (primary: Color, secondary: Color) {
        switch macroType {
        case .calories: return (calories, caloriesSecondary)
        case .protein: return (protein, proteinSecondary)
        case .carbs: return (carbs, carbsSecondary)
        case .fats: return (fats, fatsSecondary)
        }
    }
}

// MARK: - Color Extension for Light/Dark Mode

extension Color {
    init(light: Color, dark: Color) {
        #if os(iOS)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self = light
        #endif
    }
}

// MARK: - Glow Effect Modifier

extension View {
    func glow(color: Color, radius: CGFloat = 8) -> some View {
        self
            .shadow(color: color.opacity(0.5), radius: radius / 2, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 0)
    }
}
