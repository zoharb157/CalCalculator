//
//  WidgetTypography.swift
//  CaloriesCalculatorWidgets
//
//  Typography definitions for widget styling
//

import SwiftUI

/// Typography styles for the calories widget
enum WidgetTypography {
    
    // MARK: - Small Widget
    
    static let smallTitle = Font.system(size: 12, weight: .semibold, design: .rounded)
    static let smallValue = Font.system(size: 14, weight: .bold, design: .rounded)
    static let smallLabel = Font.system(size: 9, weight: .medium, design: .rounded)
    static let smallUnit = Font.system(size: 8, weight: .regular, design: .rounded)
    
    // MARK: - Medium Widget
    
    static let mediumTitle = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let mediumValue = Font.system(size: 18, weight: .bold, design: .rounded)
    static let mediumLabel = Font.system(size: 11, weight: .medium, design: .rounded)
    static let mediumUnit = Font.system(size: 10, weight: .regular, design: .rounded)
    
    // MARK: - Large Widget
    
    static let largeTitle = Font.system(size: 18, weight: .bold, design: .rounded)
    static let largeValue = Font.system(size: 24, weight: .bold, design: .rounded)
    static let largeLabel = Font.system(size: 13, weight: .medium, design: .rounded)
    static let largeUnit = Font.system(size: 11, weight: .regular, design: .rounded)
    static let largeSectionHeader = Font.system(size: 15, weight: .semibold, design: .rounded)
    
    // MARK: - Chart
    
    static let chartLabel = Font.system(size: 10, weight: .medium, design: .rounded)
    static let chartValue = Font.system(size: 12, weight: .semibold, design: .rounded)
    static let chartLegend = Font.system(size: 9, weight: .regular, design: .rounded)
    
    // MARK: - Progress Ring
    
    static let ringValue = Font.system(size: 16, weight: .bold, design: .rounded)
    static let ringLabel = Font.system(size: 9, weight: .medium, design: .rounded)
    static let ringPercentage = Font.system(size: 11, weight: .semibold, design: .rounded)
    
    // MARK: - Compact
    
    static let compactValue = Font.system(size: 13, weight: .bold, design: .rounded)
    static let compactLabel = Font.system(size: 8, weight: .medium, design: .rounded)
}
