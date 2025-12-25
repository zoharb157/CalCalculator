//
//  CaloriesEntry.swift
//  CaloriesCalculatorWidgets
//
//  Timeline entry for the calories widget
//

import WidgetKit

/// Timeline entry containing macro nutrients data for widget display
struct CaloriesEntry: TimelineEntry {
    let date: Date
    let macros: MacroNutrients
    let isPlaceholder: Bool
    
    init(date: Date = .now, macros: MacroNutrients = .placeholder, isPlaceholder: Bool = false) {
        self.date = date
        self.macros = macros
        self.isPlaceholder = isPlaceholder
    }
    
    // MARK: - Static Properties
    
    static let placeholder = CaloriesEntry(
        date: .now,
        macros: .placeholder,
        isPlaceholder: true
    )
    
    static let empty = CaloriesEntry(
        date: .now,
        macros: .empty,
        isPlaceholder: false
    )
}
