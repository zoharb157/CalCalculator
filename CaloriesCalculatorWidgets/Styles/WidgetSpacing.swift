//
//  WidgetSpacing.swift
//  CaloriesCalculatorWidgets
//
//  Spacing definitions for widget styling
//

import SwiftUI

/// Spacing constants for the calories widget
enum WidgetSpacing {
    
    // MARK: - Padding
    
    static let extraSmall: CGFloat = 2
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let standard: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 24
    
    // MARK: - Ring Sizes (Enhanced for better visibility)
    
    enum RingSize {
        case tiny
        case small
        case medium
        case large
        case extraLarge
        
        var diameter: CGFloat {
            switch self {
            case .tiny: return 28
            case .small: return 40
            case .medium: return 56
            case .large: return 80
            case .extraLarge: return 100
            }
        }
        
        var lineWidth: CGFloat {
            switch self {
            case .tiny: return 3
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            case .extraLarge: return 10
            }
        }
    }
    
    // MARK: - Corner Radius
    
    static let smallRadius: CGFloat = 8
    static let mediumRadius: CGFloat = 12
    static let largeRadius: CGFloat = 16
    static let cardRadius: CGFloat = 20
    
    // MARK: - Icon Sizes
    
    static let smallIcon: CGFloat = 12
    static let mediumIcon: CGFloat = 16
    static let largeIcon: CGFloat = 24
    
    // MARK: - Bar Sizes
    
    static let progressBarHeight: CGFloat = 8
    static let progressBarHeightSmall: CGFloat = 5
    static let progressBarHeightLarge: CGFloat = 10
}
