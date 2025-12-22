//
//  AppIntent.swift
//  CalCalculatorWidget
//
//  App Intents for widget configuration and actions
//

import WidgetKit
import AppIntents

// MARK: - Widget Configuration Intent

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Widget Configuration" }
    static var description: IntentDescription { "Configure your CalCalculator widget." }
    
    @Parameter(title: "Show Macros", default: true)
    var showMacros: Bool
    
    @Parameter(title: "Show Meal Count", default: true)
    var showMealCount: Bool
}

// MARK: - Quick Actions

struct ScanMealIntent: AppIntent {
    static var title: LocalizedStringResource { "Scan Meal" }
    static var description: IntentDescription { "Open camera to scan a meal" }
    static var openAppWhenRun: Bool { true }
    
    func perform() async throws -> some IntentResult {
        // Opens the app - the URL scheme will be handled by the app
        return .result()
    }
}

struct AddMealIntent: AppIntent {
    static var title: LocalizedStringResource { "Add Meal" }
    static var description: IntentDescription { "Manually add a meal" }
    static var openAppWhenRun: Bool { true }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct ViewHistoryIntent: AppIntent {
    static var title: LocalizedStringResource { "View History" }
    static var description: IntentDescription { "View your meal history" }
    static var openAppWhenRun: Bool { true }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct CalCalculatorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanMealIntent(),
            phrases: [
                "Scan meal with \(.applicationName)",
                "Log my food with \(.applicationName)",
                "Track my meal with \(.applicationName)"
            ],
            shortTitle: "Scan Meal",
            systemImageName: "camera.fill"
        )
        
        AppShortcut(
            intent: ViewHistoryIntent(),
            phrases: [
                "Show my food history in \(.applicationName)",
                "View my meals in \(.applicationName)"
            ],
            shortTitle: "View History",
            systemImageName: "chart.bar.fill"
        )
    }
}
