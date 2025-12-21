//
//  ProgressViewModel.swift
//  playground
//
//  View model for Progress tracking view
//

import SwiftUI
import SwiftData

/// Time filter options for charts
enum TimeFilter: String, CaseIterable, Identifiable {
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "All"
    
    var id: String { rawValue }
    
    var months: Int? {
        switch self {
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .oneYear: return 12
        case .all: return nil
        }
    }
    
    var startDate: Date {
        guard let months = months else {
            return Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
        }
        return Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
    }
}

/// Time filter for calories
enum CaloriesTimeFilter: String, CaseIterable, Identifiable {
    case oneWeek = "1W"
    case twoWeeks = "2W"
    case threeWeeks = "3W"
    
    var id: String { rawValue }
    
    var days: Int {
        switch self {
        case .oneWeek: return 7
        case .twoWeeks: return 14
        case .threeWeeks: return 21
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
    
    // MARK: - State
    var isLoading = false
    var showWeightInputSheet = false
    var showWeightProgressSheet = false
    var showCaloriesSheet = false
    
    // Weight Data
    var weightHistory: [WeightDataPoint] = []
    var weightTimeFilter: TimeFilter = .threeMonths
    
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
    
    // Settings Reference
    private var settings: UserSettings { UserSettings.shared }
    
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
    
    var weightUnit: String {
        settings.weightUnit
    }
    
    var shouldPromptForWeight: Bool {
        settings.shouldPromptForWeight
    }
    
    // MARK: - Initialization
    
    init(repository: MealRepository) {
        self.repository = repository
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load data sequentially to avoid actor isolation issues
        await loadCaloriesData()
        await loadWeightHistory()
        await loadHealthKitData()
    }
    
    func loadWeightHistory() async {
        let startDate = weightTimeFilter.startDate
        
        // Only fetch from HealthKit if available
        if healthKitManager.isHealthDataAvailable {
            let history = await healthKitManager.fetchWeightHistory(from: startDate)
            weightHistory = history.map { WeightDataPoint(date: $0.date, weight: $0.weight) }
        }
        
        // If no HealthKit data, use settings
        if weightHistory.isEmpty {
            if let lastDate = settings.lastWeightDate {
                weightHistory = [WeightDataPoint(date: lastDate, weight: settings.currentWeight)]
            }
        }
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
        
        do {
            try await healthKitManager.requestAuthorization()
            await healthKitManager.fetchTodayData()
            
            steps = healthKitManager.steps
            activeCalories = healthKitManager.activeCalories
            exerciseMinutes = healthKitManager.exerciseMinutes
            heartRate = healthKitManager.heartRate
            distance = healthKitManager.distance
            sleepHours = healthKitManager.sleepHours
        } catch {
            // HealthKit not available or not authorized - silently fail
            print("HealthKit error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Weight Actions
    
    func updateWeight(_ weight: Double) async {
        let weightInKg = settings.useMetricUnits ? weight : weight / 2.20462
        settings.updateWeight(weightInKg)
        
        // Save to HealthKit if available
        if healthKitManager.isHealthDataAvailable {
            do {
                try await healthKitManager.saveWeight(weightInKg)
            } catch {
                // Continue even if HealthKit save fails
                print("Failed to save weight to HealthKit: \(error.localizedDescription)")
            }
        }
        
        await loadWeightHistory()
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
