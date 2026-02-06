//
//  ProgressViewModel.swift
//  playground
//
//  View model for Progress tracking view
//

import SwiftUI
import SwiftData
import WidgetKit

/// Time filter options for weight history charts
/// Used to filter weight data displayed in the progress view
enum TimeFilter: String, CaseIterable, Identifiable {
    case ninetyDays = "90D"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "ALL"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .ninetyDays: return "Last 90 Days"
        case .sixMonths: return "Last 6 Months"
        case .oneYear: return "Last Year"
        case .all: return "All Time"
        }
    }
    
    var months: Int? {
        switch self {
        case .ninetyDays: return nil // Special case: uses days instead of months (90 days)
        case .sixMonths: return 6
        case .oneYear: return 12
        case .all: return nil // All time has no month limit
        }
    }
    
    var days: Int? {
        switch self {
        case .ninetyDays: return 90
        default: return nil // Other filters use months instead
        }
    }
    
    var startDate: Date {
        switch self {
        case .ninetyDays:
            return Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        case .all:
            return Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
        default:
            guard let months = months else {
                return Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
            }
            return Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
        }
    }
}

/// Time filter options for calorie history charts
/// Used to filter daily calorie data displayed in the progress view
enum CaloriesTimeFilter: String, CaseIterable, Identifiable {
    case oneWeek = "1W"
    case twoWeeks = "2W"
    case threeWeeks = "3W"
    case oneMonth = "1M"
    
    var id: String { rawValue }
    
    var displayName: String {
        let localizationManager = LocalizationManager.shared
        switch self {
        case .oneWeek: return localizationManager.localizedString(for: AppStrings.Progress.last7Days)
        case .twoWeeks: return localizationManager.localizedString(for: AppStrings.Progress.last2Weeks)
        case .threeWeeks: return localizationManager.localizedString(for: AppStrings.Progress.last3Weeks)
        case .oneMonth: return localizationManager.localizedString(for: AppStrings.Progress.lastMonth)
        }
    }
    
    var days: Int {
        switch self {
        case .oneWeek: return 7
        case .twoWeeks: return 14
        case .threeWeeks: return 21
        case .oneMonth: return 30
        }
    }
    
    var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}

/// Data structure for daily calorie breakdown
/// Represents a single day's nutritional data for charting and display
struct DailyCalorieData: Identifiable {
    let id = UUID()
    let date: Date
    let totalCalories: Int
    let protein: Double // in grams
    let carbs: Double // in grams
    let fat: Double // in grams
    
    // Convert macronutrients to calories (protein and carbs: 4 cal/g, fat: 9 cal/g)
    var proteinCalories: Int { Int(protein * 4) }
    var carbsCalories: Int { Int(carbs * 4) }
    var fatCalories: Int { Int(fat * 9) }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter.string(from: date)
    }
    
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

/// Data structure for hourly calorie breakdown
/// Represents calories consumed in a specific hour of the day
struct HourlyCalorieData: Identifiable {
    // Use hour as stable identifier instead of UUID to prevent unnecessary view recreation
    var id: Int { hour }
    let hour: Int // 0-23
    let calories: Int
    let mealCount: Int // Number of meals in this hour
    
    var hourLabel: String {
        if hour == 0 {
            return "12 AM"
        } else if hour < 12 {
            return "\(hour) AM"
        } else if hour == 12 {
            return "12 PM"
        } else {
            return "\(hour - 12) PM"
        }
    }
    
    var shortHourLabel: String {
        "\(hour):00"
    }
}

/// Weight data point for charts and weight history display
/// Represents a single weight entry with optional note
struct WeightDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double // Weight in display units (kg or lbs based on user preference)
    let note: String? // Optional note associated with this weight entry
    
    init(date: Date, weight: Double, note: String? = nil) {
        self.date = date
        self.weight = weight
        self.note = note
    }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

/// View model managing progress screen state and actions
@MainActor
@Observable
final class ProgressViewModel {
    // MARK: - Dependencies
    private let repository: MealRepository
    private let healthKitManager = HealthKitManager.shared
    private var modelContext: ModelContext?
    
    // MARK: - State
    var isLoading = false
    var showWeightInputSheet = false
    var showWeightProgressSheet = false
    var showCaloriesSheet = false
    
    // MARK: - Error State
    var error: Error?
    var showError = false
    var errorMessage: String?
    
    // Weight Data
    var weightHistory: [WeightDataPoint] = []
    var weightTimeFilter: TimeFilter = .ninetyDays
    var weightEntries: [WeightEntry] = []
    
    // Weight Stats
    var totalWeightChange: Double = 0
    var averageWeight: Double = 0
    var minWeight: Double = 0
    var maxWeight: Double = 0
    
    // Calories Data
    var dailyCaloriesData: [DailyCalorieData] = []
    var caloriesTimeFilter: CaloriesTimeFilter = .oneWeek
    var averageCalories: Int = 0
    var hourlyCalories: [HourlyCalorieData] = [] // Today's calories by hour
    
    // HealthKit Data
    var steps: Int = 0
    var activeCalories: Int = 0
    var exerciseMinutes: Int = 0
    var heartRate: Int = 0
    var distance: Double = 0
    var sleepHours: Double = 0
    var healthKitAuthorizationDenied: Bool = false
    var healthKitAuthorizationNotRequested: Bool = false
    
    // CRITICAL: Don't store UserSettings reference or use computed properties that depend on it
    // This prevents ProgressViewModel from updating when UserSettings changes (like after saving weight)
    // Views should access UserSettings.shared directly instead
    
    // MARK: - Computed Properties
    
    /// Current weight in kilograms (internal storage unit)
    /// CRITICAL: Access UserSettings.shared directly to avoid triggering view updates
    var currentWeight: Double {
        UserSettings.shared.currentWeight
    }
    
    /// Target weight in kilograms (internal storage unit)
    var targetWeight: Double {
        UserSettings.shared.targetWeight
    }
    
    /// Difference between current and target weight (positive = above target, negative = below target)
    var weightDifference: Double {
        currentWeight - targetWeight
    }
    
    /// Progress toward weight goal (0.0 to 1.0)
    /// Calculated based on how close current weight is to target compared to starting weight
    var weightProgress: Double {
        guard targetWeight != currentWeight else { return 1.0 } // Already at goal
        let startWeight = weightHistory.first?.weight ?? currentWeight
        let totalChange = abs(startWeight - targetWeight)
        let currentChange = abs(currentWeight - targetWeight)
        guard totalChange > 0 else { return 1.0 } // No change needed
        return max(0, min(1, 1 - (currentChange / totalChange)))
    }
    
    var daysUntilNextWeightCheck: Int {
        UserSettings.shared.daysUntilNextWeightCheck
    }
    
    var bmi: Double? {
        UserSettings.shared.bmi
    }
    
    var bmiCategory: BMICategory? {
        UserSettings.shared.bmiCategory
    }
    
    var useMetricUnits: Bool {
        UserSettings.shared.useMetricUnits
    }
    
    var displayWeight: Double {
        UserSettings.shared.displayWeight
    }
    
    /// Most recent weight from history, or display weight if no history exists
    /// weightHistory is sorted ascending (oldest first, newest last), so last item is most recent
    var mostRecentWeight: Double {
        weightHistory.last?.weight ?? displayWeight
    }
    
    var displayTargetWeight: Double {
        useMetricUnits ? targetWeight : targetWeight * 2.20462
    }
    
    var weightUnit: String {
        UserSettings.shared.weightUnit
    }
    
    var shouldPromptForWeight: Bool {
        UserSettings.shared.shouldPromptForWeight
    }
    
    // MARK: - Initialization
    
    init(repository: MealRepository, modelContext: ModelContext? = nil) {
        self.repository = repository
        self.modelContext = modelContext
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Data Loading
    
    /// Loads all progress data (calories, weight history, HealthKit data)
    /// Data is loaded sequentially to avoid actor isolation issues with SwiftData
    func loadData() async {
        isLoading = true
        showError = false
        error = nil
        errorMessage = nil
        defer { isLoading = false }
        
        // Load data sequentially to avoid actor isolation issues with SwiftData context
        // Each load operation may modify the model context, so parallel loading could cause conflicts
        await loadCaloriesData()
        await loadHourlyCalories() // Load today's hourly breakdown for trend chart
        await loadWeightHistory()
        await loadHealthKitData()
    }
    
    /// Loads weight history from SwiftData, with fallback to HealthKit if no entries exist
    /// Results are sorted ascending by date (oldest first, newest last)
    func loadWeightHistory() async {
        let startDate = weightTimeFilter.startDate
        
        // First try to load from SwiftData (primary data source)
        if let context = modelContext {
            do {
                let descriptor = FetchDescriptor<WeightEntry>(
                    predicate: #Predicate<WeightEntry> { entry in
                        entry.date >= startDate
                    },
                    sortBy: [SortDescriptor(\.date, order: .forward)]
                )
                
                let entries = try context.fetch(descriptor)
                
                // Immediately extract all property values from SwiftData models
                // This prevents InvalidFutureBackingData errors by accessing properties
                // while the model context is still valid and the entries are materialized
                // Extract values into plain structs immediately after fetch
                let extractedData: [(date: Date, weight: Double, note: String?)] = entries.map { entry in
                    // Access all properties immediately while the entry is guaranteed to be valid
                    // This creates local copies that are safe to use later
                    (date: entry.date, weight: entry.weight, note: entry.note)
                }
                
                // Store the SwiftData entries for reference (but don't access their properties later)
                weightEntries = entries
                
                // Now convert extracted data to weight data points (using local copies, not SwiftData models)
                // This is safe because we're working with plain values, not SwiftData models
                let newHistory = extractedData.map { data in
                    WeightDataPoint(
                        date: data.date,
                        weight: useMetricUnits ? data.weight : data.weight * 2.20462,
                        note: data.note
                    )
                }
                
                // Ensure consistent sorting: ascending by date (oldest first, newest last)
                // Assign sorted array to trigger SwiftUI update
                // Since ProgressViewModel is @MainActor, we're already on main thread
                let sortedHistory = newHistory.sorted { $0.date < $1.date }
                // Force SwiftUI update by creating a completely new array reference
                // This ensures views detect the change even if only values inside changed
                weightHistory = Array(sortedHistory)
                AppLogger.forClass("ProgressViewModel").success("Loaded weight history: \(sortedHistory.count) entries, most recent: \(sortedHistory.last?.weight ?? 0)")
                
                // Calculate statistics after updating weightHistory
                calculateWeightStats()
                
                // If we have SwiftData entries, don't fall back to HealthKit
                // SwiftData is the primary source of truth
                if !weightHistory.isEmpty {
                    return
                }
            } catch {
                AppLogger.forClass("ProgressViewModel").warning("Failed to fetch weight entries from SwiftData", error: error)
                // If the error is due to missing tables, the ModelContainer initialization
                // should have already fixed it. Just continue with empty data.
                weightHistory = []
            }
        }
        
        // If no weight history exists, create initial entry from UserSettings (onboarding data)
        // This ensures ProgressView can display the starting weight even if no weight history exists
        // Only create if currentWeight is valid (greater than 0)
        if weightHistory.isEmpty, let context = modelContext, currentWeight > 0 && currentWeight < 1000 {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            
            // Check if an entry for today already exists
            let descriptor = FetchDescriptor<WeightEntry>(
                predicate: #Predicate<WeightEntry> { entry in
                    entry.date >= today && entry.date < tomorrow
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            do {
                let existingEntries = try context.fetch(descriptor)
                if existingEntries.isEmpty {
                    // Create initial entry from UserSettings (onboarding weight)
                    let entry = WeightEntry(weight: currentWeight, date: Date())
                    context.insert(entry)
                    try context.save()
                    
                    // Reload weight history to include the new entry
                    let reloadDescriptor = FetchDescriptor<WeightEntry>(
                        predicate: #Predicate<WeightEntry> { entry in
                            entry.date >= startDate
                        },
                        sortBy: [SortDescriptor(\.date, order: .forward)]
                    )
                    let entries = try context.fetch(reloadDescriptor)
                    let extractedData: [(date: Date, weight: Double, note: String?)] = entries.map { entry in
                        (date: entry.date, weight: entry.weight, note: entry.note)
                    }
                    weightEntries = entries
                    let newHistory = extractedData.map { data in
                        WeightDataPoint(
                            date: data.date,
                            weight: useMetricUnits ? data.weight : data.weight * 2.20462,
                            note: data.note
                        )
                    }
                    weightHistory = newHistory.sorted { $0.date < $1.date }
                    calculateWeightStats()
                    return
                }
            } catch {
                // Silently fail - if we can't create the entry, the user can still add it manually
            }
        }
        
        // Fallback to HealthKit if no SwiftData entries exist
        // This handles migration from HealthKit-only storage to SwiftData
        // IMPORTANT: We only use HealthKit as fallback - our data always takes precedence
        if healthKitManager.isHealthDataAvailable && weightHistory.isEmpty {
            let history = await healthKitManager.fetchWeightHistory(from: startDate)
            // Create new array and assign sorted to trigger SwiftUI update
            let newHistory = history.map { WeightDataPoint(date: $0.date, weight: $0.weight) }
            weightHistory = newHistory.sorted { $0.date < $1.date }
            calculateWeightStats()
            
            // If we loaded from HealthKit, try to copy it to our SwiftData storage
            // This ensures our data is the source of truth going forward
            if let context = modelContext, !history.isEmpty {
                do {
                    for (date, weight) in history {
                        let calendar = Calendar.current
                        let normalizedDate = calendar.startOfDay(for: date)
                        let tomorrow = calendar.date(byAdding: .day, value: 1, to: normalizedDate) ?? normalizedDate
                        
                        // Check if entry already exists for this date
                        let descriptor = FetchDescriptor<WeightEntry>(
                            predicate: #Predicate<WeightEntry> { entry in
                                entry.date >= normalizedDate && entry.date < tomorrow
                            }
                        )
                        
                        let existingEntries = try context.fetch(descriptor)
                        if existingEntries.isEmpty {
                            // Create new entry from HealthKit data
                            let entry = WeightEntry(weight: weight, date: date)
                            context.insert(entry)
                        }
                    }
                    try context.save()
                    AppLogger.forClass("ProgressViewModel").success("Copied HealthKit weight data to SwiftData")
                } catch {
                    AppLogger.forClass("ProgressViewModel").warning("Failed to copy HealthKit data to SwiftData", error: error)
                    // Continue - HealthKit data copy is not critical, SwiftData is primary source
                }
            }
        }
        
        // If no HealthKit data either, use settings as last resort
        // This ensures the view always has at least one data point to display
        if weightHistory.isEmpty {
            if let lastDate = UserSettings.shared.lastWeightDate {
                weightHistory = [WeightDataPoint(date: lastDate, weight: displayWeight)]
            }
        }
        
        // Sync current weight to widget via shared UserDefaults
        // This keeps the widget up to date with the latest weight
        if currentWeight > 0 {
            let displayWeightValue = displayWeight
            syncWeightDataToWidget(weight: displayWeightValue, weightInKg: currentWeight)
        }
    }
    
    /// Calculates weight statistics from the current weight history
    /// Computes total change, average, min, and max weights
    private func calculateWeightStats() {
        guard !weightHistory.isEmpty else {
            // No history - reset all stats to zero
            totalWeightChange = 0
            averageWeight = 0
            minWeight = 0
            maxWeight = 0
            return
        }
        
        // Ensure weightHistory is sorted (should already be, but double-check for safety)
        let sortedHistory = weightHistory.sorted { $0.date < $1.date }
        let weights = sortedHistory.map { $0.weight }
        
        // Calculate total change: most recent (last) - oldest (first)
        // Positive value = weight gain, negative value = weight loss
        if let firstWeight = sortedHistory.first?.weight,
           let lastWeight = sortedHistory.last?.weight {
            totalWeightChange = lastWeight - firstWeight
        }
        
        // Calculate average, min, and max weights
        averageWeight = weights.reduce(0, +) / Double(weights.count)
        minWeight = weights.min() ?? 0
        maxWeight = weights.max() ?? 0
    }
    
    func loadCaloriesData() async {
        let startDate = caloriesTimeFilter.startDate
        let calendar = Calendar.current
        
        var data: [DailyCalorieData] = []
        var currentDate = startDate
        
        while currentDate <= Date() {
            do {
                if let summary = try repository.fetchDaySummary(for: currentDate) {
                    data.append(DailyCalorieData(
                        date: summary.date,
                        totalCalories: summary.totalCalories,
                        protein: summary.totalProteinG,
                        carbs: summary.totalCarbsG,
                        fat: summary.totalFatG
                    ))
                }
            } catch {
                // Skip days with errors
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? Date()
        }
        
        dailyCaloriesData = data.sorted { $0.date < $1.date }
        
        // Calculate average
        if !dailyCaloriesData.isEmpty {
            let total = dailyCaloriesData.reduce(0) { $0 + $1.totalCalories }
            averageCalories = total / dailyCaloriesData.count
        } else {
            averageCalories = 0
        }
    }
    
    /// Load today's calories broken down by hour for the trend chart
    func loadHourlyCalories() async {
        let calendar = Calendar.current
        let today = Date()
        
        do {
            // Fetch all meals from today
            let meals = try repository.fetchMeals(for: today)
            
            // Initialize hourly data (0-23 hours)
            var hourlyData: [Int: (calories: Int, count: Int)] = [:]
            for hour in 0..<24 {
                hourlyData[hour] = (calories: 0, count: 0)
            }
            
            // Group meals by hour
            // Note: meal.totalCalories safely accesses meal.items relationship
            // The totalCalories property in Meal.swift creates a local copy of items
            // before accessing, preventing InvalidFutureBackingData errors
            for meal in meals {
                let hour = calendar.component(.hour, from: meal.timestamp)
                // Ensure hour is valid (0-23) - defensive programming
                guard hour >= 0, hour < 24 else {
                    AppLogger.forClass("ProgressViewModel").warning("Invalid hour \(hour) for meal at \(meal.timestamp)")
                    continue
                }
                
                // Ensure calories are non-negative - defensive programming
                let mealCalories = max(0, meal.totalCalories)
                
                if let current = hourlyData[hour] {
                    hourlyData[hour] = (
                        calories: current.calories + mealCalories,
                        count: current.count + 1
                    )
                }
            }
            
            // Convert to array of HourlyCalorieData
            hourlyCalories = (0..<24).map { hour in
                let data = hourlyData[hour] ?? (calories: 0, count: 0)
                return HourlyCalorieData(
                    hour: hour,
                    calories: data.calories,
                    mealCount: data.count
                )
            }
        } catch {
            // On error, initialize with empty data
            hourlyCalories = (0..<24).map { hour in
                HourlyCalorieData(hour: hour, calories: 0, mealCount: 0)
            }
        }
    }
    
    func loadHealthKitData() async {
        // Check if HealthKit is available on this device
        guard healthKitManager.isHealthDataAvailable else {
            return
        }
        
        // Check current status without auto-requesting
        healthKitManager.checkCurrentAuthorizationStatus()
        
        if healthKitManager.authorizationDenied {
            healthKitAuthorizationDenied = true
            healthKitAuthorizationNotRequested = false
            return
        }
        
        // Check if authorization has not been requested yet
        if !healthKitManager.isAuthorized && !healthKitManager.authorizationDenied {
            healthKitAuthorizationNotRequested = true
            healthKitAuthorizationDenied = false
            return
        }
        
        // If authorized, fetch data
        if healthKitManager.isAuthorized {
            await healthKitManager.fetchTodayData()
            
            healthKitAuthorizationDenied = false
            healthKitAuthorizationNotRequested = false
            steps = healthKitManager.steps
            activeCalories = healthKitManager.activeCalories
            exerciseMinutes = healthKitManager.exerciseMinutes
            heartRate = healthKitManager.heartRate
            distance = healthKitManager.distance
            sleepHours = healthKitManager.sleepHours
        }
    }
    
    // MARK: - Weight Actions
    
    /// Updates the user's weight and saves it to SwiftData, HealthKit, and widget
    /// - Parameter weight: Weight in display units (kg or lbs based on user preference)
    /// This method handles the complete weight update flow including data persistence
    func updateWeight(_ weight: Double) async {
        AppLogger.forClass("ProgressViewModel").info("updateWeight called: \(weight)")
        
        // Convert to kg if needed (weight parameter is in display units)
        // Internal storage always uses kilograms for consistency
        let weightInKg = UserSettings.shared.useMetricUnits ? weight : weight / 2.20462
        
        // Update UserSettings (this also updates lastWeightDate)
        // Since UserSettings is @Observable, this will automatically trigger view updates
        AppLogger.forClass("ProgressViewModel").info("About to update UserSettings.weight to: \(weightInKg) kg")
        UserSettings.shared.updateWeight(weightInKg)
        AppLogger.forClass("ProgressViewModel").info("UserSettings.weight updated")
        
        if let context = modelContext {
            do {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
                
                let descriptor = FetchDescriptor<WeightEntry>(
                    predicate: #Predicate<WeightEntry> { entry in
                        entry.date >= today && entry.date < tomorrow
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                
                let existingEntries = try context.fetch(descriptor)
                if let existingEntry = existingEntries.first {
                    existingEntry.weight = weightInKg
                    existingEntry.date = Date()
                    AppLogger.forClass("ProgressViewModel").info("Updated existing weight entry for today")
                } else {
                    let entry = WeightEntry(weight: weightInKg, date: Date())
                    context.insert(entry)
                    AppLogger.forClass("ProgressViewModel").info("Created new weight entry for today")
                }
                
                try context.save()
                HapticManager.shared.notification(.success)
                
                // Force SwiftData to process the save before fetching
                // This ensures the new entry is available when we reload
                context.processPendingChanges()
            } catch {
                AppLogger.forClass("ProgressViewModel").warning("Failed to save weight entry to SwiftData", error: error)
                // If save fails, try to reload the context and retry once
                // This handles cases where the store was just recreated
                if let context = modelContext {
                    context.processPendingChanges()
                    do {
                        let entry = WeightEntry(weight: weightInKg, date: Date())
                        context.insert(entry)
                        try context.save()
                        AppLogger.forClass("ProgressViewModel").success("Successfully saved weight entry on retry")
                        } catch {
                        AppLogger.forClass("ProgressViewModel").error("Failed to save weight entry even on retry", error: error)
                    }
                }
            }
        }
        
        // Sync weight data to widget via shared UserDefaults
        // Use display weight (what user sees) for widget display
        syncWeightDataToWidget(weight: weight, weightInKg: weightInKg)
        
        // Also save to HealthKit if available and authorized
        // This ensures our data overwrites HealthKit data (our data is the source of truth)
        // Only attempt save if authorization has been determined (not .notDetermined)
        if healthKitManager.isHealthDataAvailable {
            if healthKitManager.isAuthorized {
                do {
                    try await healthKitManager.saveWeight(weightInKg)
                    AppLogger.forClass("ProgressViewModel").success("Weight saved to HealthKit (overwriting HealthKit data): \(weightInKg) kg")
                } catch {
                    // Continue even if HealthKit save fails - SwiftData is primary source
                    AppLogger.forClass("ProgressViewModel").warning("Failed to save weight to HealthKit", error: error)
                }
            } else {
                // Authorization not determined or denied - silently skip (user hasn't granted permission yet)
                AppLogger.forClass("ProgressViewModel").info("Skipping HealthKit save - authorization not granted")
            }
        }
        
        // Reload weight history to update all views
        // Since ProgressViewModel is @Observable, this will automatically trigger view updates
        // Add a small delay to ensure SwiftData has processed the save completely
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        await loadWeightHistory()
        
        AppLogger.forClass("ProgressViewModel").success("Weight updated: \(weight) (\(weightInKg) kg), history count: \(weightHistory.count), most recent: \(weightHistory.last?.weight ?? 0)")
    }
    
    /// Syncs weight data to widget via shared UserDefaults
    /// This allows the widget extension to display the latest weight without direct database access
    /// - Parameters:
    ///   - weight: Weight in display units (what the user sees)
    ///   - weightInKg: Weight in kilograms (internal storage unit)
    private func syncWeightDataToWidget(weight: Double, weightInKg: Double) {
        let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            AppLogger.forClass("ProgressViewModel").warning("Failed to access shared UserDefaults for widget weight sync")
            return
        }
        
        // Store weight in display units (what user sees in the app)
        // Widget will use this value directly for display
        sharedDefaults.set(weight, forKey: "widget.currentWeight")
        sharedDefaults.set(UserSettings.shared.useMetricUnits, forKey: "widget.useMetricUnits")
        sharedDefaults.set(Date(), forKey: "widget.lastWeightDate")
        
        AppLogger.forClass("ProgressViewModel").data("Widget weight data synced: \(weight) \(UserSettings.shared.useMetricUnits ? "kg" : "lbs")")
        
        // Reload widget timelines to update widget display immediately
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func deleteWeightEntry(_ entry: WeightEntry) {
        guard let context = modelContext else { return }
        
        context.delete(entry)
        
        do {
            try context.save()
            HapticManager.shared.notification(.success)
            
            // Reload data
            Task {
                await loadWeightHistory()
            }
        } catch {
            AppLogger.forClass("ProgressViewModel").warning("Failed to delete weight entry", error: error)
            // Reload weight history even if delete failed to ensure UI is up to date
            Task {
                await loadWeightHistory()
            }
        }
    }
    
    func markWeightPromptShown() {
        UserSettings.shared.markWeightPromptShown()
    }
    
    // MARK: - Filter Changes
    
    func onWeightFilterChange() async {
        await loadWeightHistory()
    }
    
    func onCaloriesFilterChange() async {
        await loadCaloriesData()
    }
}
