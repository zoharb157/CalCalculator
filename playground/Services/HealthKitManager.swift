//
//  HealthKitManager.swift
//  playground
//
//  Service for integrating with Apple HealthKit
//

import Foundation
import HealthKit

/// Manager for HealthKit data access and synchronization
@MainActor
@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()
    
    private var healthStore: HKHealthStore?
    
    var isAuthorized = false
    var authorizationDenied = false
    var steps: Int = 0
    var activeCalories: Int = 0
    var exerciseMinutes: Int = 0
    var standHours: Int = 0
    var heartRate: Int = 0
    var sleepHours: Double = 0
    var waterIntake: Double = 0 // in liters
    var distance: Double = 0 // in km
    
    private init() {
        // Only create health store if HealthKit is available
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        }
    }
    
    // MARK: - HealthKit Availability
    
    var isHealthDataAvailable: Bool {
        healthStore != nil
    }
    
    // MARK: - Authorization
    
    /// Request HealthKit authorization - this shows the system permission dialog
    func requestAuthorization() async throws {
        guard let store = healthStore else {
            throw HealthKitError.notAvailable
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.appleStandTime),
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.dietaryWater),
            HKCategoryType(.sleepAnalysis)
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKQuantityType(.bodyMass),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.activeEnergyBurned)
            // Note: HKQuantityType(.appleExerciseTime) is read-only and cannot be written to
        ]
        
        try await store.requestAuthorization(toShare: typesToWrite, read: typesToRead)
    }
    
    /// Check current authorization status without requesting
    /// Call this on app launch to determine which UI to show
    func checkCurrentAuthorizationStatus() {
        guard let store = healthStore else {
            isAuthorized = false
            authorizationDenied = true
            return
        }
        
        // Check write permission as proxy for whether user has seen the dialog
        let bodyMassType = HKQuantityType(.bodyMass)
        let writeStatus = store.authorizationStatus(for: bodyMassType)
        
        switch writeStatus {
        case .sharingAuthorized:
            isAuthorized = true
            authorizationDenied = false
        case .sharingDenied:
            isAuthorized = false
            authorizationDenied = true
        case .notDetermined:
            // User hasn't seen the permission dialog yet
            isAuthorized = false
            authorizationDenied = false
        @unknown default:
            isAuthorized = false
            authorizationDenied = false
        }
    }
    
    /// Request authorization and then verify access by fetching data
    func requestAndVerifyAuthorization() async {
        guard let store = healthStore else {
            isAuthorized = false
            authorizationDenied = true
            return
        }
        
        // Request authorization - this shows the system dialog
        do {
            try await requestAuthorization()
        } catch {
            isAuthorized = false
            authorizationDenied = true
            return
        }
        
        // After user responds, check the status and fetch data
        await verifyAuthorizationWithData(store: store)
    }
    
    /// Verify authorization by checking status and fetching data
    private func verifyAuthorizationWithData(store: HKHealthStore) async {
        // Fetch data to verify read access
        await fetchTodayData()
        
        // If we got any data, we definitely have read access
        if steps > 0 || activeCalories > 0 || exerciseMinutes > 0 || heartRate > 0 || distance > 0 || sleepHours > 0 {
            isAuthorized = true
            authorizationDenied = false
            return
        }
        
        // No data - check write permission as proxy
        let bodyMassType = HKQuantityType(.bodyMass)
        let writeStatus = store.authorizationStatus(for: bodyMassType)
        
        switch writeStatus {
        case .sharingAuthorized:
            // User granted write, likely granted read too - just no activity yet
            isAuthorized = true
            authorizationDenied = false
        case .sharingDenied:
            // User denied - show settings prompt
            isAuthorized = false
            authorizationDenied = true
        case .notDetermined:
            // Shouldn't happen after requesting, but treat as denied
            isAuthorized = false
            authorizationDenied = true
        @unknown default:
            isAuthorized = false
            authorizationDenied = true
        }
    }
    
    /// Refresh data and authorization status (call when returning from settings)
    func refreshAuthorizationAndData() async {
        guard let store = healthStore else {
            isAuthorized = false
            authorizationDenied = true
            return
        }
        
        await verifyAuthorizationWithData(store: store)
    }
    
    // MARK: - Fetch Today's Data
    
    func fetchTodayData() async {
        await fetchData(for: Date())
    }
    
    /// Fetches HealthKit data for a specific date
    /// - Parameter date: The date to fetch data for
    func fetchData(for date: Date) async {
        guard healthStore != nil else { return }
        
        async let stepsResult = fetchStepsValue(for: date)
        async let caloriesResult = fetchActiveCaloriesValue(for: date)
        async let exerciseResult = fetchExerciseMinutesValue(for: date)
        async let standResult = fetchStandHoursValue(for: date)
        async let heartRateResult = fetchHeartRateValue(for: date)
        async let distanceResult = fetchDistanceValue(for: date)
        async let sleepResult = fetchSleepValue(for: date)
        async let waterResult = fetchWaterIntakeValue(for: date)
        
        let results = await (stepsResult, caloriesResult, exerciseResult, standResult, heartRateResult, distanceResult, sleepResult, waterResult)
        
        steps = results.0
        activeCalories = results.1
        exerciseMinutes = results.2
        standHours = results.3
        heartRate = results.4
        distance = results.5
        sleepHours = results.6
        waterIntake = results.7
    }
    
    // MARK: - Steps
    
    private func fetchStepsValue(for date: Date = Date()) async -> Int {
        let stepType = HKQuantityType(.stepCount)
        let value = await fetchDaySum(for: stepType, unit: .count(), date: date)
        return Int(value)
    }
    
    // MARK: - Active Calories
    
    private func fetchActiveCaloriesValue(for date: Date = Date()) async -> Int {
        let calorieType = HKQuantityType(.activeEnergyBurned)
        let value = await fetchDaySum(for: calorieType, unit: .kilocalorie(), date: date)
        return Int(value)
    }
    
    // MARK: - Exercise Minutes
    
    private func fetchExerciseMinutesValue(for date: Date = Date()) async -> Int {
        let exerciseType = HKQuantityType(.appleExerciseTime)
        let value = await fetchDaySum(for: exerciseType, unit: .minute(), date: date)
        return Int(value)
    }
    
    // MARK: - Stand Hours
    
    private func fetchStandHoursValue(for date: Date = Date()) async -> Int {
        let standType = HKQuantityType(.appleStandTime)
        let value = await fetchDaySum(for: standType, unit: .minute(), date: date)
        return Int(value / 60)
    }
    
    // MARK: - Heart Rate
    
    private func fetchHeartRateValue(for date: Date = Date()) async -> Int {
        guard let store = healthStore else { return 0 }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.isDateInToday(date) ? Date() : calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, _ in
                let avg = result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
                continuation.resume(returning: Int(avg))
            }
            store.execute(query)
        }
    }
    
    // MARK: - Distance
    
    private func fetchDistanceValue(for date: Date = Date()) async -> Double {
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        return await fetchDaySum(for: distanceType, unit: .meterUnit(with: .kilo), date: date)
    }
    
    // MARK: - Sleep
    
    private func fetchSleepValue(for date: Date = Date()) async -> Double {
        guard let store = healthStore else { return 0 }
        
        let sleepType = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay) else {
            return 0
        }
        
        let endOfDay = calendar.isDateInToday(date) ? Date() : calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: endOfDay)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                var totalSleep: TimeInterval = 0
                
                if let sleepSamples = samples as? [HKCategorySample] {
                    for sample in sleepSamples {
                        if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                            totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                        }
                    }
                }
                
                continuation.resume(returning: totalSleep / 3600)
            }
            store.execute(query)
        }
    }
    
    // MARK: - Water Intake
    
    private func fetchWaterIntakeValue(for date: Date = Date()) async -> Double {
        let waterType = HKQuantityType(.dietaryWater)
        return await fetchDaySum(for: waterType, unit: .liter(), date: date)
    }
    
    // MARK: - Helper Methods
    
    private func fetchDaySum(for quantityType: HKQuantityType, unit: HKUnit, date: Date) async -> Double {
        guard let store = healthStore else { return 0 }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.isDateInToday(date) ? Date() : calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let sum = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: sum)
            }
            store.execute(query)
        }
    }
    
    // MARK: - Write Weight to HealthKit
    
    func saveWeight(_ weight: Double) async throws {
        guard let store = healthStore else {
            throw HealthKitError.notAvailable
        }
        
        let weightType = HKQuantityType(.bodyMass)
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weight)
        let sample = HKQuantitySample(type: weightType, quantity: quantity, start: Date(), end: Date())
        
        try await store.save(sample)
    }
    
    // MARK: - Write Exercise to HealthKit
    
    /// Saves exercise data to HealthKit (active calories and exercise time)
    /// This ensures our exercise data overwrites HealthKit data (our data is the source of truth)
    /// - Parameters:
    ///   - calories: Calories burned during the exercise
    ///   - durationMinutes: Duration of exercise in minutes
    ///   - startDate: Start date of the exercise (defaults to now)
    func saveExercise(calories: Int, durationMinutes: Int, startDate: Date = Date()) async throws {
        guard let store = healthStore else {
            throw HealthKitError.notAvailable
        }
        
        let endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        
        // Save active energy burned (calories)
        let caloriesType = HKQuantityType(.activeEnergyBurned)
        let caloriesQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories))
        let caloriesSample = HKQuantitySample(
            type: caloriesType,
            quantity: caloriesQuantity,
            start: startDate,
            end: endDate
        )
        
        // Note: HKQuantityType(.appleExerciseTime) is read-only and cannot be written to
        // Apple automatically calculates exercise time from active energy burned
        // So we only save the active calories, and HealthKit will calculate exercise time automatically
        try await store.save(caloriesSample)
    }
    
    // MARK: - Fetch Weight History
    
    func fetchWeightHistory(from startDate: Date, to endDate: Date = Date()) async -> [(date: Date, weight: Double)] {
        guard let store = healthStore else { return [] }
        
        let weightType = HKQuantityType(.bodyMass)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                var results: [(Date, Double)] = []
                
                if let weightSamples = samples as? [HKQuantitySample] {
                    for sample in weightSamples {
                        let weight = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                        results.append((sample.startDate, weight))
                    }
                }
                
                continuation.resume(returning: results)
            }
            store.execute(query)
        }
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationFailed
    case dataNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationFailed:
            return "Failed to authorize HealthKit access"
        case .dataNotAvailable:
            return "Health data is not available"
        }
    }
}
