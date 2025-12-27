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
            HKQuantityType(.dietaryWater)
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
        guard healthStore != nil else { return }
        
        async let stepsResult = fetchStepsValue()
        async let caloriesResult = fetchActiveCaloriesValue()
        async let exerciseResult = fetchExerciseMinutesValue()
        async let standResult = fetchStandHoursValue()
        async let heartRateResult = fetchHeartRateValue()
        async let distanceResult = fetchDistanceValue()
        async let sleepResult = fetchSleepValue()
        async let waterResult = fetchWaterIntakeValue()
        
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
    
    private func fetchStepsValue() async -> Int {
        let stepType = HKQuantityType(.stepCount)
        let value = await fetchTodaySum(for: stepType, unit: .count())
        return Int(value)
    }
    
    // MARK: - Active Calories
    
    private func fetchActiveCaloriesValue() async -> Int {
        let calorieType = HKQuantityType(.activeEnergyBurned)
        let value = await fetchTodaySum(for: calorieType, unit: .kilocalorie())
        return Int(value)
    }
    
    // MARK: - Exercise Minutes
    
    private func fetchExerciseMinutesValue() async -> Int {
        let exerciseType = HKQuantityType(.appleExerciseTime)
        let value = await fetchTodaySum(for: exerciseType, unit: .minute())
        return Int(value)
    }
    
    // MARK: - Stand Hours
    
    private func fetchStandHoursValue() async -> Int {
        let standType = HKQuantityType(.appleStandTime)
        let value = await fetchTodaySum(for: standType, unit: .minute())
        return Int(value / 60)
    }
    
    // MARK: - Heart Rate
    
    private func fetchHeartRateValue() async -> Int {
        guard let store = healthStore else { return 0 }
        
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date())
        
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
    
    private func fetchDistanceValue() async -> Double {
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        return await fetchTodaySum(for: distanceType, unit: .meterUnit(with: .kilo))
    }
    
    // MARK: - Sleep
    
    private func fetchSleepValue() async -> Double {
        guard let store = healthStore else { return 0 }
        
        let sleepType = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar.current
        let now = Date()
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else {
            return 0
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now)
        
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
    
    private func fetchWaterIntakeValue() async -> Double {
        let waterType = HKQuantityType(.dietaryWater)
        return await fetchTodaySum(for: waterType, unit: .liter())
    }
    
    // MARK: - Helper Methods
    
    private func fetchTodaySum(for quantityType: HKQuantityType, unit: HKUnit) async -> Double {
        guard let store = healthStore else { return 0 }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())
        
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
