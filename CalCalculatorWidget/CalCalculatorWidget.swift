//
//  CalCalculatorWidget.swift
//  CalCalculatorWidget
//
//  Main widget implementations for CalCalculator
//

import WidgetKit
import SwiftUI

// MARK: - Widget Data Entry

/// Main entry for widget timeline containing all nutrition data
struct NutritionEntry: TimelineEntry {
    let date: Date
    let caloriesConsumed: Int
    let caloriesGoal: Int
    let proteinConsumed: Double
    let proteinGoal: Double
    let carbsConsumed: Double
    let carbsGoal: Double
    let fatConsumed: Double
    let fatGoal: Double
    let mealCount: Int
    let lastMealName: String?
    let lastMealTime: Date?
    let weeklyData: [DailyData]
    
    // Computed properties
    var caloriesRemaining: Int {
        max(0, caloriesGoal - caloriesConsumed)
    }
    
    var caloriesProgress: Double {
        guard caloriesGoal > 0 else { return 0 }
        return Double(caloriesConsumed) / Double(caloriesGoal)
    }
    
    var proteinProgress: Double {
        guard proteinGoal > 0 else { return 0 }
        return proteinConsumed / proteinGoal
    }
    
    var carbsProgress: Double {
        guard carbsGoal > 0 else { return 0 }
        return carbsConsumed / carbsGoal
    }
    
    var fatProgress: Double {
        guard fatGoal > 0 else { return 0 }
        return fatConsumed / fatGoal
    }
    
    var isOverGoal: Bool {
        caloriesConsumed > caloriesGoal
    }
    
    var caloriesOverage: Int {
        max(0, caloriesConsumed - caloriesGoal)
    }
    
    // Static placeholder for preview
    static var placeholder: NutritionEntry {
        NutritionEntry(
            date: Date(),
            caloriesConsumed: 1450,
            caloriesGoal: 2000,
            proteinConsumed: 95,
            proteinGoal: 150,
            carbsConsumed: 180,
            carbsGoal: 250,
            fatConsumed: 45,
            fatGoal: 65,
            mealCount: 3,
            lastMealName: "Grilled Chicken Salad",
            lastMealTime: Calendar.current.date(byAdding: .hour, value: -2, to: Date()),
            weeklyData: DailyData.sampleWeek
        )
    }
    
    static var empty: NutritionEntry {
        NutritionEntry(
            date: Date(),
            caloriesConsumed: 0,
            caloriesGoal: 2000,
            proteinConsumed: 0,
            proteinGoal: 150,
            carbsConsumed: 0,
            carbsGoal: 250,
            fatConsumed: 0,
            fatGoal: 65,
            mealCount: 0,
            lastMealName: nil,
            lastMealTime: nil,
            weeklyData: []
        )
    }
}

// MARK: - Daily Data for Weekly View

struct DailyData: Identifiable {
    let id = UUID()
    let date: Date
    let caloriesConsumed: Int
    let caloriesGoal: Int
    
    var progress: Double {
        guard caloriesGoal > 0 else { return 0 }
        return min(Double(caloriesConsumed) / Double(caloriesGoal), 1.5)
    }
    
    var dayAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(1))
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    static var sampleWeek: [DailyData] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let consumed = daysAgo == 0 ? 1450 : Int.random(in: 1600...2200)
            return DailyData(
                date: date,
                caloriesConsumed: consumed,
                caloriesGoal: 2000
            )
        }
    }
}

// MARK: - Shared UserDefaults Keys for App Group

struct WidgetDataKeys {
    static let appGroupIdentifier = "group.com.calcalculator.shared"
    
    static let caloriesConsumed = "widget_calories_consumed"
    static let caloriesGoal = "widget_calories_goal"
    static let proteinConsumed = "widget_protein_consumed"
    static let proteinGoal = "widget_protein_goal"
    static let carbsConsumed = "widget_carbs_consumed"
    static let carbsGoal = "widget_carbs_goal"
    static let fatConsumed = "widget_fat_consumed"
    static let fatGoal = "widget_fat_goal"
    static let mealCount = "widget_meal_count"
    static let lastMealName = "widget_last_meal_name"
    static let lastMealTime = "widget_last_meal_time"
    static let lastUpdateDate = "widget_last_update_date"
}

// MARK: - Widget Data Provider

struct WidgetDataProvider {
    private let userDefaults: UserDefaults?
    
    init() {
        self.userDefaults = UserDefaults(suiteName: WidgetDataKeys.appGroupIdentifier)
    }
    
    func loadData() -> NutritionEntry {
        guard let defaults = userDefaults else {
            return NutritionEntry.placeholder
        }
        
        // Check if data is from today
        if let lastUpdate = defaults.object(forKey: WidgetDataKeys.lastUpdateDate) as? Date,
           !Calendar.current.isDateInToday(lastUpdate) {
            return NutritionEntry.empty
        }
        
        let caloriesGoal = defaults.integer(forKey: WidgetDataKeys.caloriesGoal)
        let proteinGoal = defaults.double(forKey: WidgetDataKeys.proteinGoal)
        let carbsGoal = defaults.double(forKey: WidgetDataKeys.carbsGoal)
        let fatGoal = defaults.double(forKey: WidgetDataKeys.fatGoal)
        
        return NutritionEntry(
            date: Date(),
            caloriesConsumed: defaults.integer(forKey: WidgetDataKeys.caloriesConsumed),
            caloriesGoal: caloriesGoal > 0 ? caloriesGoal : 2000,
            proteinConsumed: defaults.double(forKey: WidgetDataKeys.proteinConsumed),
            proteinGoal: proteinGoal > 0 ? proteinGoal : 150,
            carbsConsumed: defaults.double(forKey: WidgetDataKeys.carbsConsumed),
            carbsGoal: carbsGoal > 0 ? carbsGoal : 250,
            fatConsumed: defaults.double(forKey: WidgetDataKeys.fatConsumed),
            fatGoal: fatGoal > 0 ? fatGoal : 65,
            mealCount: defaults.integer(forKey: WidgetDataKeys.mealCount),
            lastMealName: defaults.string(forKey: WidgetDataKeys.lastMealName),
            lastMealTime: defaults.object(forKey: WidgetDataKeys.lastMealTime) as? Date,
            weeklyData: DailyData.sampleWeek
        )
    }
}

// MARK: - Timeline Provider

struct NutritionTimelineProvider: TimelineProvider {
    typealias Entry = NutritionEntry
    
    let dataProvider = WidgetDataProvider()
    
    func placeholder(in context: Context) -> NutritionEntry {
        NutritionEntry.placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (NutritionEntry) -> Void) {
        let entry = context.isPreview ? NutritionEntry.placeholder : dataProvider.loadData()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NutritionEntry>) -> Void) {
        let entry = dataProvider.loadData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Small Widget View (Calories Progress Ring)

struct SmallCaloriesWidgetView: View {
    let entry: NutritionEntry
    
    private var progressColor: Color {
        if entry.isOverGoal {
            return .red
        } else if entry.caloriesProgress >= 0.8 {
            return .green
        } else if entry.caloriesProgress >= 0.5 {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: size * 0.08)
                    
                    Circle()
                        .trim(from: 0, to: min(entry.caloriesProgress, 1.0))
                        .stroke(
                            progressColor,
                            style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(entry.caloriesConsumed)")
                            .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("/ \(entry.caloriesGoal)")
                            .font(.system(size: size * 0.08, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: size * 0.65, height: size * 0.65)
                
                if entry.isOverGoal {
                    Text("+\(entry.caloriesOverage) over")
                        .font(.system(size: size * 0.08, weight: .semibold, design: .rounded))
                        .foregroundColor(.red)
                } else {
                    Text("\(entry.caloriesRemaining) left")
                        .font(.system(size: size * 0.08, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Medium Widget View (Macros Overview)

struct MediumMacrosWidgetView: View {
    let entry: NutritionEntry
    
    private var caloriesColor: Color {
        if entry.isOverGoal { return .red }
        else if entry.caloriesProgress >= 0.8 { return .green }
        else if entry.caloriesProgress >= 0.5 { return .orange }
        else { return .blue }
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        
                        Circle()
                            .trim(from: 0, to: min(entry.caloriesProgress, 1.0))
                            .stroke(caloriesColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 0) {
                            Text("\(entry.caloriesConsumed)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("kcal")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 80, height: 80)
                    
                    Text("\(entry.caloriesRemaining) left")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(width: geometry.size.width * 0.35)
                
                VStack(spacing: 8) {
                    MacroProgressBar(title: "Protein", value: entry.proteinConsumed, goal: entry.proteinGoal, unit: "g", color: .orange)
                    MacroProgressBar(title: "Carbs", value: entry.carbsConsumed, goal: entry.carbsGoal, unit: "g", color: .blue)
                    MacroProgressBar(title: "Fat", value: entry.fatConsumed, goal: entry.fatGoal, unit: "g", color: .purple)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

struct MacroProgressBar: View {
    let title: String
    let value: Double
    let goal: Double
    let unit: String
    let color: Color
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value))/\(Int(goal))\(unit)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Large Widget View (Weekly Summary)

struct LargeWeeklyWidgetView: View {
    let entry: NutritionEntry
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Overview")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Track your daily progress")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.caloriesConsumed)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(entry.isOverGoal ? .red : .green)
                    Text("today")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            HStack(spacing: 8) {
                ForEach(entry.weeklyData) { day in
                    WeeklyDayBar(data: day)
                }
            }
            .padding(.horizontal)
            
            Divider()
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                MacroCircleSmall(title: "Protein", value: entry.proteinConsumed, goal: entry.proteinGoal, color: .orange)
                MacroCircleSmall(title: "Carbs", value: entry.carbsConsumed, goal: entry.carbsGoal, color: .blue)
                MacroCircleSmall(title: "Fat", value: entry.fatConsumed, goal: entry.fatGoal, color: .purple)
                MacroCircleSmall(title: "Calories", value: Double(entry.caloriesConsumed), goal: Double(entry.caloriesGoal), color: entry.isOverGoal ? .red : .green)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            if let mealName = entry.lastMealName, let mealTime = entry.lastMealTime {
                HStack {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Last: \(mealName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(mealTime, style: .time)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
}

struct WeeklyDayBar: View {
    let data: DailyData
    
    private var barColor: Color {
        if data.progress > 1.0 { return .red }
        else if data.progress >= 0.8 { return .green }
        else if data.progress >= 0.5 { return .orange }
        else { return .blue.opacity(0.6) }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(data.isToday ? barColor : barColor.opacity(0.7))
                        .frame(height: geometry.size.height * min(data.progress, 1.0))
                }
            }
            .frame(height: 60)
            
            Text(data.dayAbbreviation)
                .font(.system(size: 10, weight: data.isToday ? .bold : .medium))
                .foregroundColor(data.isToday ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MacroCircleSmall: View {
    let title: String
    let value: Double
    let goal: Double
    let color: Color
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .frame(width: 40, height: 40)
            
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Quick Log Widget View

struct QuickLogWidgetView: View {
    let entry: NutritionEntry
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.caloriesConsumed)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("of \(entry.caloriesGoal) kcal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: min(entry.caloriesProgress, 1.0))
                        .stroke(entry.isOverGoal ? Color.red : Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(min(entry.caloriesProgress, 1.0) * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .frame(width: 50, height: 50)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                QuickActionButton(icon: "camera.fill", title: "Scan", color: .blue)
                QuickActionButton(icon: "plus.circle.fill", title: "Add", color: .green)
                QuickActionButton(icon: "chart.bar.fill", title: "History", color: .purple)
            }
        }
        .padding()
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        Link(destination: URL(string: "calcalculator://action/\(title.lowercased())")!) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Compact Macros Widget (Extra Large)

struct CompactMacrosWidgetView: View {
    let entry: NutritionEntry
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Nutrition")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(entry.caloriesConsumed)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                        Text("/ \(entry.caloriesGoal) kcal")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    if entry.isOverGoal {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text("\(entry.caloriesOverage) over goal")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                            Text("\(entry.caloriesRemaining) remaining")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: min(entry.caloriesProgress, 1.0))
                        .stroke(entry.isOverGoal ? Color.red : Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int(min(entry.caloriesProgress, 1.0) * 100))")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 80, height: 80)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            VStack(spacing: 6) {
                MacroBarLarge(title: "Protein", value: entry.proteinConsumed, goal: entry.proteinGoal, color: .orange)
                MacroBarLarge(title: "Carbs", value: entry.carbsConsumed, goal: entry.carbsGoal, color: .blue)
                MacroBarLarge(title: "Fat", value: entry.fatConsumed, goal: entry.fatGoal, color: .purple)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }
}

struct MacroBarLarge: View {
    let title: String
    let value: Double
    let goal: Double
    let color: Color
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value))g / \(Int(goal))g")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.8), color]), startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Accessory Widgets (Lock Screen) - iOS 16+

#if os(iOS)
@available(iOSApplicationExtension 16.0, *)
struct AccessoryCircularView: View {
    let entry: NutritionEntry
    
    var body: some View {
        Gauge(value: min(entry.caloriesProgress, 1.0)) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text("\(entry.caloriesConsumed)")
                .font(.system(size: 12, weight: .bold))
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}

@available(iOSApplicationExtension 16.0, *)
struct AccessoryRectangularView: View {
    let entry: NutritionEntry
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(entry.caloriesProgress, 1.0))
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
            }
            .frame(width: 30, height: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.caloriesConsumed) / \(entry.caloriesGoal) kcal")
                    .font(.system(size: 12, weight: .semibold))
                HStack(spacing: 8) {
                    Label("\(Int(entry.proteinConsumed))g", systemImage: "p.circle")
                    Label("\(Int(entry.carbsConsumed))g", systemImage: "c.circle")
                    Label("\(Int(entry.fatConsumed))g", systemImage: "f.circle")
                }
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            }
        }
    }
}

@available(iOSApplicationExtension 16.0, *)
struct AccessoryInlineView: View {
    let entry: NutritionEntry
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            Text("\(entry.caloriesConsumed)/\(entry.caloriesGoal) kcal")
        }
    }
}
#endif

// MARK: - Main Widgets

struct CaloriesSmallWidget: Widget {
    let kind: String = "CaloriesSmallWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionTimelineProvider()) { entry in
            SmallCaloriesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Calories Progress")
        .description("Track your daily calorie intake with a beautiful progress ring.")
        .supportedFamilies([.systemSmall])
    }
}

struct MacrosMediumWidget: Widget {
    let kind: String = "MacrosMediumWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionTimelineProvider()) { entry in
            MediumMacrosWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Macros")
        .description("View your calories and macronutrient progress at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct WeeklyLargeWidget: Widget {
    let kind: String = "WeeklyLargeWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionTimelineProvider()) { entry in
            LargeWeeklyWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weekly Summary")
        .description("Track your weekly calorie trends and today's macros.")
        .supportedFamilies([.systemLarge])
    }
}

struct QuickLogWidget: Widget {
    let kind: String = "QuickLogWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionTimelineProvider()) { entry in
            QuickLogWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Log")
        .description("Quickly log meals and view your progress.")
        .supportedFamilies([.systemMedium])
    }
}

struct CompactMacrosWidget: Widget {
    let kind: String = "CompactMacrosWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionTimelineProvider()) { entry in
            CompactMacrosWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Full Nutrition")
        .description("Comprehensive view of your daily nutrition progress.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

#if os(iOS)
@available(iOSApplicationExtension 16.0, *)
struct CaloriesAccessoryWidget: Widget {
    let kind: String = "CaloriesAccessoryWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionTimelineProvider()) { entry in
            AccessoryCircularView(entry: entry)
        }
        .configurationDisplayName("Calories Ring")
        .description("Quick calorie progress for your Lock Screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

@available(iOSApplicationExtension 16.0, *)
struct MacrosAccessoryWidget: Widget {
    let kind: String = "MacrosAccessoryWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionTimelineProvider()) { entry in
            AccessoryRectangularView(entry: entry)
        }
        .configurationDisplayName("Macros Overview")
        .description("Compact view of your daily macros for Lock Screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

@available(iOSApplicationExtension 16.0, *)
struct CaloriesInlineWidget: Widget {
    let kind: String = "CaloriesInlineWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionTimelineProvider()) { entry in
            AccessoryInlineView(entry: entry)
        }
        .configurationDisplayName("Calories Inline")
        .description("Inline calorie counter for Lock Screen.")
        .supportedFamilies([.accessoryInline])
    }
}
#endif

// MARK: - Legacy Widget (backward compatibility)

struct CalCalculatorWidget: Widget {
    let kind: String = "CalCalculatorWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionTimelineProvider()) { entry in
            SmallCaloriesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("CalCalculator")
        .description("Track your daily calorie intake.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
