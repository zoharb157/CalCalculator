//
//  CalCalculatorWidgetControl.swift
//  CalCalculatorWidget
//
//  Control Center widget for quick actions
//

import AppIntents
import SwiftUI
import WidgetKit

struct CalCalculatorWidgetControl: ControlWidget {
    static let kind: String = "CalCalculator.CalCalculatorWidgetControl"
    
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: CaloriesControlProvider()
        ) { value in
            ControlWidgetButton(action: ScanMealControlIntent()) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(value.caloriesConsumed)")
                            .font(.system(size: 16, weight: .bold))
                        Text("of \(value.caloriesGoal) kcal")
                            .font(.system(size: 10))
                    }
                } icon: {
                    Image(systemName: "camera.fill")
                }
            }
        }
        .displayName("Scan Meal")
        .description("Quick access to scan and log meals.")
    }
}

// MARK: - Control Value Provider

extension CalCalculatorWidgetControl {
    struct Value {
        var caloriesConsumed: Int
        var caloriesGoal: Int
        var progress: Double {
            guard caloriesGoal > 0 else { return 0 }
            return Double(caloriesConsumed) / Double(caloriesGoal)
        }
    }
    
    struct CaloriesControlProvider: AppIntentControlValueProvider {
        func previewValue(configuration: CaloriesControlConfiguration) -> Value {
            Value(caloriesConsumed: 1450, caloriesGoal: 2000)
        }
        
        func currentValue(configuration: CaloriesControlConfiguration) async throws -> Value {
            let defaults = UserDefaults(suiteName: "group.com.calcalculator.shared")
            let consumed = defaults?.integer(forKey: "widget_calories_consumed") ?? 0
            let goal = defaults?.integer(forKey: "widget_calories_goal") ?? 2000
            return Value(
                caloriesConsumed: consumed,
                caloriesGoal: goal > 0 ? goal : 2000
            )
        }
    }
}

// MARK: - Control Configuration

struct CaloriesControlConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Calories Control Configuration"
}

// MARK: - Control Intent

struct ScanMealControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan Meal"
    static var openAppWhenRun: Bool { true }
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        // This will open the app - deep linking to scan view
        return .result()
    }
}
