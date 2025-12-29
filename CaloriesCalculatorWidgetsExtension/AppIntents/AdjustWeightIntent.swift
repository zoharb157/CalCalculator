//
//  AdjustWeightIntent.swift
//  CaloriesCalculatorWidgetsExtension
//
//  App Intent for adjusting weight from widget (+/- buttons)
//

import AppIntents
import Foundation
import WidgetKit

@available(iOS 16.0, *)
struct AdjustWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Adjust Weight"
    static var description = IntentDescription("Adjust your weight by a small amount")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Adjustment", description: "Amount to adjust weight (positive or negative)")
    var adjustment: Double
    
    @Parameter(title: "Current Weight", description: "Current weight value")
    var currentWeight: Double
    
    @Parameter(title: "Use Metric", description: "Whether to use metric units")
    var useMetric: Bool
    
    init() {}
    
    init(adjustment: Double, currentWeight: Double, useMetric: Bool) {
        self.adjustment = adjustment
        self.currentWeight = currentWeight
        self.useMetric = useMetric
    }
    
    func perform() async throws -> some IntentResult {
        // Calculate new weight
        let newWeight = max(0, currentWeight + adjustment)
        
        // Save to shared UserDefaults for the app to pick up
        let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return .result()
        }
        
        // Store the new weight and flag that it was updated from widget
        sharedDefaults.set(newWeight, forKey: "widget.currentWeight")
        sharedDefaults.set(useMetric, forKey: "widget.useMetricUnits")
        sharedDefaults.set(Date(), forKey: "widget.lastWeightDate")
        sharedDefaults.set(true, forKey: "widget.weightUpdatedFromWidget")
        sharedDefaults.set(newWeight, forKey: "widget.pendingWeightUpdate")
        
        // Post notification so app can pick it up immediately
        // Note: App Intents run in the widget extension process, not the app process
        // The app will detect the change via UserDefaults check on become active
        // For immediate sync, we rely on the UserDefaults flag which the app checks
        
        // Reload widget timeline
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
}

