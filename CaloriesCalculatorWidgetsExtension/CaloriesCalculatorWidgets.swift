//
//  CaloriesCalculatorWidgets.swift
//  CaloriesCalculatorWidgets
//
//  Main widget definition for the Calories Calculator app
//

import WidgetKit
import SwiftUI

/// Main calories widget using static configuration
struct CaloriesWidget: Widget {
    let kind: String = "CaloriesWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CaloriesTimelineProvider()) { entry in
            WidgetRootView(entry: entry)
        }
        .configurationDisplayName("Calories Tracker")
        .description("Track your daily calorie and macro intake at a glance. Premium feature.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview

#Preview("Small Widget", as: .systemSmall) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: MockData.midDayProgress)
    CaloriesEntry(macros: MockData.almostComplete)
}

#Preview("Medium Widget", as: .systemMedium) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: MockData.midDayProgress)
    CaloriesEntry(macros: MockData.almostComplete)
}

#Preview("Large Widget", as: .systemLarge) {
    CaloriesWidget()
} timeline: {
    CaloriesEntry(macros: MockData.midDayProgress)
    CaloriesEntry(macros: MockData.almostComplete)
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
