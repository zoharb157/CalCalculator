//
//  CaloriesTimelineProvider.swift
//  CaloriesCalculatorWidgets
//
//  Timeline provider for the calories widget
//

import WidgetKit
import SwiftUI

/// Provides timeline entries for the calories widget
struct CaloriesTimelineProvider: TimelineProvider {
    
    typealias Entry = CaloriesEntry
    
    // MARK: - TimelineProvider Protocol
    
    func placeholder(in context: Context) -> CaloriesEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CaloriesEntry) -> Void) {
        let entry: CaloriesEntry
        
        if context.isPreview {
            // Use placeholder data for widget gallery preview
            entry = .placeholder
        } else {
            // Load subscription status first
            let isSubscribed = WidgetDataManager.shared.loadIsSubscribed()
            
            // Only load actual data if user is subscribed
            // Non-premium users should see empty data
            let macros = isSubscribed 
                ? WidgetDataManager.shared.loadMacroNutrients()
                : .empty
            
            entry = CaloriesEntry(date: .now, macros: macros, isSubscribed: isSubscribed)
        }
        
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CaloriesEntry>) -> Void) {
        // Load subscription status first
        let isSubscribed = WidgetDataManager.shared.loadIsSubscribed()
        
        // Only load actual data if user is subscribed
        // Non-premium users should see empty data with premium lock
        let macros = isSubscribed 
            ? WidgetDataManager.shared.loadMacroNutrients()
            : .empty
        
        let entry = CaloriesEntry(date: .now, macros: macros, isSubscribed: isSubscribed)
        
        // Use .never policy - widget refreshes only via WidgetCenter.shared.reloadAllTimelines()
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}
