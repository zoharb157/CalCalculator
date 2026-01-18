//
//  DietAlertManager.swift
//  playground
//
//  Manages nutrition alerts with threshold detection and debouncing
//

import Foundation

/// Configuration for alert thresholds
struct AlertThresholds {
    let closeToLimitPercentage: Double // Default: 0.8 (80%)
    let debounceInterval: TimeInterval // Default: 300 seconds (5 minutes)
    
    static let `default` = AlertThresholds(
        closeToLimitPercentage: 0.8,
        debounceInterval: 300
    )
}

/// Represents an alert that should be shown to the user
struct NutritionAlert: Identifiable, Equatable {
    let id = UUID()
    let metric: NutritionMetric
    let type: AlertType
    let message: String
    let timestamp: Date
    
    enum AlertType {
        case closeToLimit
        case exceededLimit
    }
    
    static func == (lhs: NutritionAlert, rhs: NutritionAlert) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages nutrition alerts with debouncing to prevent spam
@MainActor
final class DietAlertManager {
    static let shared = DietAlertManager()
    
    private var thresholds: AlertThresholds
    private var lastAlertTimes: [String: Date] = [:]
    private var shownAlertsToday: Set<String> = []
    
    private init(thresholds: AlertThresholds = .default) {
        self.thresholds = thresholds
    }
    
    /// Update alert thresholds
    func updateThresholds(_ newThresholds: AlertThresholds) {
        self.thresholds = newThresholds
    }
    
    /// Evaluate nutrition statuses and return alerts that should be shown
    func evaluateAlerts(for statuses: [NutritionStatus]) -> [NutritionAlert] {
        let calendar = Calendar.current
        
        // Reset shown alerts if it's a new day
        if let lastReset = UserDefaults.standard.object(forKey: "DietAlertManager.lastReset") as? Date,
           !calendar.isDate(lastReset, inSameDayAs: Date()) {
            shownAlertsToday.removeAll()
            UserDefaults.standard.set(Date(), forKey: "DietAlertManager.lastReset")
        }
        
        var alerts: [NutritionAlert] = []
        
        for status in statuses {
            let alertKey = "\(status.metric.rawValue)_\(status.isOverGoal ? "over" : "close")"
            
            // Check if we've already shown this alert today
            if shownAlertsToday.contains(alertKey) {
                continue
            }
            
            // Check debounce interval
            if let lastAlertTime = lastAlertTimes[alertKey],
               Date().timeIntervalSince(lastAlertTime) < thresholds.debounceInterval {
                continue
            }
            
            var alert: NutritionAlert?
            
            if status.isAtLimit {
                alert = NutritionAlert(
                    metric: status.metric,
                    type: .exceededLimit,
                    message: formatExceededMessage(for: status),
                    timestamp: Date()
                )
            } else if status.isCloseToLimit {
                alert = NutritionAlert(
                    metric: status.metric,
                    type: .closeToLimit,
                    message: formatCloseToLimitMessage(for: status),
                    timestamp: Date()
                )
            }
            
            if let alert = alert {
                alerts.append(alert)
                lastAlertTimes[alertKey] = Date()
                shownAlertsToday.insert(alertKey)
            }
        }
        
        return alerts
    }
    
    /// Mark an alert as dismissed (won't show again today)
    func dismissAlert(_ alert: NutritionAlert) {
        let alertKey = "\(alert.metric.rawValue)_\(alert.type == .exceededLimit ? "over" : "close")"
        shownAlertsToday.insert(alertKey)
    }
    
    /// Reset all alerts (useful for testing or manual reset)
    func reset() {
        lastAlertTimes.removeAll()
        shownAlertsToday.removeAll()
        UserDefaults.standard.set(Date(), forKey: "DietAlertManager.lastReset")
    }
    
    // MARK: - Private Helpers
    
    private func formatExceededMessage(for status: NutritionStatus) -> String {
        let overAmount = Int(status.over)
        return "You're \(overAmount) \(status.metric.unit) over your \(status.metric.displayName.lowercased()) goal today."
    }
    
    private func formatCloseToLimitMessage(for status: NutritionStatus) -> String {
        let remaining = Int(status.remaining)
        return "You have \(remaining) \(status.metric.unit) \(status.metric.displayName.lowercased()) remaining."
    }
}
