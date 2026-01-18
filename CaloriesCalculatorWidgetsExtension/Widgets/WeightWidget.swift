//
//  WeightWidget.swift
//  CaloriesCalculatorWidgetsExtension
//
//  Interactive widget for logging weight
//

import WidgetKit
import SwiftUI
import AppIntents

struct WeightWidget: Widget {
    let kind: String = "WeightWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeightTimelineProvider()) { entry in
            WeightWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weight Tracker")
        .description("Quickly log your weight and track your progress")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - Widget Entry

struct WeightEntry: TimelineEntry {
    let date: Date
    let currentWeight: Double?
    let unit: String
    let lastWeightDate: Date?
    let isSubscribed: Bool
}

// MARK: - Widget View

struct WeightWidgetView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: WeightEntry
    
    /// URL scheme for deep linking - opens paywall if not subscribed, otherwise opens main app
    private var widgetDeepLinkURL: URL {
        if entry.isSubscribed {
            return URL(string: "calcalculator://weight")!
        } else {
            return URL(string: "calcalculator://paywall")!
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "scalemass.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Weight")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Current Weight Display with +/- Controls
            if let weight = entry.currentWeight {
                VStack(spacing: 8) {
                    // Weight value with +/- buttons
                    HStack(spacing: widgetFamily == .systemSmall ? 8 : 16) {
                        // Minus button
                        Button(intent: AdjustWeightIntent(
                            adjustment: entry.unit == "kg" ? -0.1 : -0.2,
                            currentWeight: weight,
                            useMetric: entry.unit == "kg"
                        )) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: widgetFamily == .systemSmall ? 20 : 28))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        // Weight value (centered) - prevent truncation
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", weight))
                                .font(.system(size: widgetFamily == .systemSmall ? 24 : 36, weight: .bold))
                                .foregroundColor(.primary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            Text(entry.unit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)
                        
                        // Plus button
                        Button(intent: AdjustWeightIntent(
                            adjustment: entry.unit == "kg" ? 0.1 : 0.2,
                            currentWeight: weight,
                            useMetric: entry.unit == "kg"
                        )) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: widgetFamily == .systemSmall ? 20 : 28))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Last logged date (if available)
                    if let lastDate = entry.lastWeightDate {
                        Text("Last: \(formatDate(lastDate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("No weight logged")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Log Weight Button (when no weight)
                    Button(intent: LogWeightIntent()) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Log Weight")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
        }
        .padding()
        .widgetURL(widgetDeepLinkURL)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Timeline Provider

struct WeightTimelineProvider: TimelineProvider {
    typealias Entry = WeightEntry
    
    func placeholder(in context: Context) -> WeightEntry {
        WeightEntry(
            date: Date(),
            currentWeight: 75.5,
            unit: "kg",
            lastWeightDate: Date(),
            isSubscribed: true
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WeightEntry) -> Void) {
        let (weight, unit, lastDate, isSubscribed) = loadWeightData()
        let entry = WeightEntry(
            date: Date(),
            currentWeight: weight,
            unit: unit,
            lastWeightDate: lastDate,
            isSubscribed: isSubscribed
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeightEntry>) -> Void) {
        let (weight, unit, lastDate, isSubscribed) = loadWeightData()
        let entry = WeightEntry(
            date: Date(),
            currentWeight: weight,
            unit: unit,
            lastWeightDate: lastDate,
            isSubscribed: isSubscribed
        )
        
        // Update every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadWeightData() -> (weight: Double?, unit: String, lastDate: Date?, isSubscribed: Bool) {
        let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return (nil, "kg", nil, false)
        }
        
        // Load weight data from shared UserDefaults
        let weight = sharedDefaults.double(forKey: "widget.currentWeight")
        let useMetric = sharedDefaults.bool(forKey: "widget.useMetricUnits")
        let unit = useMetric ? "kg" : "lbs"
        
        // Load last weight date
        let lastDate = sharedDefaults.object(forKey: "widget.lastWeightDate") as? Date
        
        // Load subscription status
        let isSubscribed = sharedDefaults.bool(forKey: "widget.isSubscribed")
        
        return (weight > 0 ? weight : nil, unit, lastDate, isSubscribed)
    }
}

// MARK: - Preview

#Preview("Small Widget", as: .systemSmall) {
    WeightWidget()
} timeline: {
    WeightEntry(
        date: Date(),
        currentWeight: 75.5,
        unit: "kg",
        lastWeightDate: Date(),
        isSubscribed: true
    )
}

#Preview("Medium Widget", as: .systemMedium) {
    WeightWidget()
} timeline: {
    WeightEntry(
        date: Date(),
        currentWeight: 75.5,
        unit: "kg",
        lastWeightDate: Date(),
        isSubscribed: true
    )
}

