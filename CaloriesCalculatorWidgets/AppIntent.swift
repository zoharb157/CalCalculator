//
//  AppIntent.swift
//  CaloriesCalculatorWidgets
//
//  Widget configuration intent (simplified for static widget)
//

import WidgetKit
import AppIntents

/// Configuration intent for the Calories Widget
/// Currently uses static configuration with no user-customizable parameters
struct CaloriesWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Calories Tracker" }
    static var description: IntentDescription { "Track your daily calorie and macro intake." }
    
    // The widget is non-configurable, so no parameters are needed
    // Future enhancement: Add parameters for preferred macro display, theme, etc.
}
