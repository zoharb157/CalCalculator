//
//  ProgressViewModel.swift
//  playground
//
//  View model for Progress tracking view
//

import SwiftUI
import SwiftData
import WidgetKit

/// Time filter options for charts
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
        case .ninetyDays: return nil // Special case for days (90 days)
        case .sixMonths: return 6
        case .oneYear: return 12
        case .all: return nil
        }
    }
    
    var days: Int? {
        switch self {
        case .ninetyDays: return 90
        default: return nil
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

/// Time filter for calories
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

/// Data for daily calorie breakdown
struct DailyCalorieData: Identifiable {
    let id = UUID()
    let date: Date
    let totalCalories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    
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

/// Weight data point for charts
struct WeightDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
    let note: String?
    
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
    
    // HealthKit Data
    var steps: Int = 0
    var activeCalories: Int = 0
    var exerciseMinutes: Int = 0
    var heartRate: Int = 0
    var distance: Double = 0
    var sleepHours: Double = 0
    var healthKitAuthorizationDenied: Bool = false
    
    // Settings Reference - observe changes
    @MainActor private var settings: UserSettings { UserSettings.shared }
    
    // MARK: - Computed Properties
    
    var currentWeight: Double {
        settings.currentWeight
    }
    
    var targetWeight: Double {
        settings.targetWeight
    }
    
    var weightDifference: Double {
        currentWeight - targetWeight
    }
    
    var weightProgress: Double {
        guard targetWeight != currentWeight else { return 1.0 }
        let startWeight = weightHistory.first?.weight ?? currentWeight
        let totalChange = abs(startWeight - targetWeight)
        let currentChange = abs(currentWeight - targetWeight)
        guard totalChange > 0 else { return 1.0 }
        return max(0, min(1, 1 - (currentChange / totalChange)))
    }
    
    var daysUntilNextWeightCheck: Int {
        settings.daysUntilNextWeightCheck
    }
    
    var bmi: Double? {
        settings.bmi
    }
    
    var bmiCategory: BMICategory? {
        settings.bmiCategory
    }
    
    var useMetricUnits: Bool {
        settings.useMetricUnits
    }
    
    var displayWeight: Double {
        settings.displayWeight
    }
    
    /// Most recent weight from history, or display weight if no history
    var mostRecentWeight: Double {
        // weightHistory is sorted ascending (oldest first, newest last)
        weightHistory.last?.weight ?? displayWeight
    }
    
    var displayTargetWeight: Double {
        useMetricUnits ? targetWeight : targetWeight * 2.20462
    }
    
    var weightUnit: String {
        settings.weightUnit
    }
    
    var shouldPromptForWeight: Bool {
        settings.shouldPromptForWeight
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
    
    func loadData() async {
        isLoading = true
        showError = false
        error = nil
        errorMessage = nil
        defer { isLoading = false }
        
        // Load data sequentially to avoid actor isolation issues
        await loadCaloriesData()
        await loadWeightHistory()
        await loadHealthKitData()
    }
    
    func loadWeightHistory() async {
        let startDate = weightTimeFilter.startDate
        
        // First try to load from SwiftData
        if let context = modelContext {
            do {
                let descriptor = FetchDescriptor<WeightEntry>(
                    predicate: #Predicate<WeightEntry> { entry in
                        entry.date >= startDate
                    },
                    sortBy: [SortDescriptor(\.date, order: .forward)]
                )
                
                let entries = try context.fetch(descriptor)
                weightEntries = entries
                
                // Convert to weight data points
                // Create new array to ensure SwiftUI detects the change
                let newHistory = entries.map { entry in
                    WeightDataPoint(
                        date: entry.date,
                        weight: useMetricUnits ? entry.weight : entry.weightInPounds,
                        note: entry.note
                    )
                }
                
                // Ensure consistent sorting: ascending by date (oldest first, newest last)
                // Assign sorted array to trigger SwiftUI update
                // Since ProgressViewModel is @MainActor, we're already on main thread
                let sortedHistory = newHistory.sorted { $0.date < $1.date }
                // Force SwiftUI update by creating a completely new array reference
                // This ensures views detect the change even if only values inside changed
                weightHistory = Array(sortedHistory)
                print("✅ [ProgressViewModel] Loaded weight history: \(sortedHistory.count) entries, most recent: \(sortedHistory.last?.weight ?? 0)")
                
                // Calculate stats after updating weightHistory
                calculateWeightStats()
                
                // If we have SwiftData entries, don't fall back to HealthKit
                if !weightHistory.isEmpty {
                    return
                }
            } catch {
                print("Failed to fetch weight entries from SwiftData: \(error)")
            }
        }
        
        // Fallback to HealthKit if no SwiftData entries
        if healthKitManager.isHealthDataAvailable {
            let history = await healthKitManager.fetchWeightHistory(from: startDate)
            // Create new array and assign sorted to trigger SwiftUI update
            let newHistory = history.map { WeightDataPoint(date: $0.date, weight: $0.weight) }
            weightHistory = newHistory.sorted { $0.date < $1.date }
            calculateWeightStats()
        }
        
        // If no HealthKit data either, use settings
        if weightHistory.isEmpty {
            if let lastDate = settings.lastWeightDate {
                weightHistory = [WeightDataPoint(date: lastDate, weight: displayWeight)]
            }
        }
        
        // Sync current weight to widget
        if currentWeight > 0 {
            let displayWeightValue = displayWeight
            syncWeightDataToWidget(weight: displayWeightValue, weightInKg: currentWeight)
        }
    }
    
    private func calculateWeightStats() {
        guard !weightHistory.isEmpty else {
            totalWeightChange = 0
            averageWeight = 0
            minWeight = 0
            maxWeight = 0
            return
        }
        
        // Ensure weightHistory is sorted (should already be, but double-check)
        let sortedHistory = weightHistory.sorted { $0.date < $1.date }
        let weights = sortedHistory.map { $0.weight }
        
        // Calculate total change: most recent (last) - oldest (first)
        if let firstWeight = sortedHistory.first?.weight,
           let lastWeight = sortedHistory.last?.weight {
            totalWeightChange = lastWeight - firstWeight
        }
        
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
    
    func loadHealthKitData() async {
        // Check if HealthKit is available on this device
        guard healthKitManager.isHealthDataAvailable else {
            return
        }
        
        // Check current status without auto-requesting
        healthKitManager.checkCurrentAuthorizationStatus()
        
        if healthKitManager.authorizationDenied {
            healthKitAuthorizationDenied = true
            return
        }
        
        // If authorized, fetch data
        if healthKitManager.isAuthorized {
            await healthKitManager.fetchTodayData()
            
            healthKitAuthorizationDenied = false
            steps = healthKitManager.steps
            activeCalories = healthKitManager.activeCalories
            exerciseMinutes = healthKitManager.exerciseMinutes
            heartRate = healthKitManager.heartRate
            distance = healthKitManager.distance
            sleepHours = healthKitManager.sleepHours
        }
    }
    
    // MARK: - Weight Actions
    
    func updateWeight(_ weight: Double) async {
        // Convert to kg if needed (weight parameter is in display units)
        let weightInKg = settings.useMetricUnits ? weight : weight / 2.20462
        
        // Update UserSettings (this also updates lastWeightDate)
        // Since UserSettings is @Observable, this will automatically trigger view updates
        settings.updateWeight(weightInKg)
        
        // Save to SwiftData - always create a new entry
        if let context = modelContext {
            do {
                // Always create a new entry with current timestamp
                let entry = WeightEntry(weight: weightInKg, date: Date())
                context.insert(entry)
                
                try context.save()
                HapticManager.shared.notification(.success)
                
                // Force SwiftData to process the save before fetching
                // This ensures the new entry is available when we reload
                try? context.processPendingChanges()
            } catch {
                print("Failed to save weight entry to SwiftData: \(error)")
            }
        }
        
        // Sync weight data to widget via shared UserDefaults
        // Use display weight (what user sees) for widget
        syncWeightDataToWidget(weight: weight, weightInKg: weightInKg)
        
        // Also save to HealthKit if available and authorized
        // Only attempt save if authorization has been determined (not .notDetermined)
        if healthKitManager.isHealthDataAvailable && healthKitManager.isAuthorized {
            do {
                try await healthKitManager.saveWeight(weightInKg)
                print("✅ [ProgressViewModel] Weight saved to HealthKit: \(weightInKg) kg")
            } catch {
                // Continue even if HealthKit save fails
                print("⚠️ [ProgressViewModel] Failed to save weight to HealthKit: \(error.localizedDescription)")
            }
        } else if healthKitManager.isHealthDataAvailable && !healthKitManager.isAuthorized {
            // Authorization not determined or denied - silently skip (user hasn't granted permission yet)
            print("ℹ️ [ProgressViewModel] Skipping HealthKit save - authorization not granted")
        }
        
        // Reload weight history to update all views
        // Since ProgressViewModel is @Observable, this will automatically trigger view updates
        // Add a small delay to ensure SwiftData has processed the save
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        await loadWeightHistory()
        
        print("✅ [ProgressViewModel] Weight updated: \(weight) (\(weightInKg) kg), history count: \(weightHistory.count), most recent: \(weightHistory.last?.weight ?? 0)")
    }
    
    /// Sync weight data to widget via shared UserDefaults
    private func syncWeightDataToWidget(weight: Double, weightInKg: Double) {
        let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ Failed to access shared UserDefaults for widget weight sync")
            return
        }
        
        // Store weight in display units (what user sees)
        sharedDefaults.set(weight, forKey: "widget.currentWeight")
        sharedDefaults.set(settings.useMetricUnits, forKey: "widget.useMetricUnits")
        sharedDefaults.set(Date(), forKey: "widget.lastWeightDate")
        
        print("📱 Widget weight data synced: \(weight) \(settings.useMetricUnits ? "kg" : "lbs")")
        
        // Reload widget timelines
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
            print("Failed to delete weight entry: \(error)")
        }
    }
    
    func markWeightPromptShown() {
        settings.markWeightPromptShown()
    }
    
    // MARK: - Filter Changes
    
    func onWeightFilterChange() async {
        await loadWeightHistory()
    }
    
    func onCaloriesFilterChange() async {
        await loadCaloriesData()
    }
}
