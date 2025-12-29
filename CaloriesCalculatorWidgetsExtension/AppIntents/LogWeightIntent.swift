//
//  LogWeightIntent.swift
//  CaloriesCalculatorWidgetsExtension
//
//  App Intent for logging weight from widget
//

import AppIntents
import Foundation
import WidgetKit

@available(iOS 16.0, *)
struct LogWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Weight"
    static var description = IntentDescription("Open the app to log your weight")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        // Open the app with a deep link to weight logging
        // The app will handle showing the weight input sheet
        let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
        let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
        sharedDefaults?.set(true, forKey: "openWeightInput")
        sharedDefaults?.synchronize()
        
        // Reload widget timeline
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
}

