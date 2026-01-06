//
//  ProgressViewModelTests.swift
//  CalCalculatorTests
//
//  Unit tests for ProgressViewModel
//

import XCTest
@testable import playground
import SwiftData

@MainActor
final class ProgressViewModelTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    var repository: MealRepository!
    var viewModel: ProgressViewModel!
    
    override func setUpWithError() throws {
        let schema = Schema([Meal.self, MealItem.self, DaySummary.self, Exercise.self, WeightEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        repository = MealRepository(context: context)
        viewModel = ProgressViewModel(repository: repository)
        viewModel.setModelContext(context)
        
        // Clear UserDefaults widget data before each test
        if let sharedDefaults = UserDefaults(suiteName: "group.CalCalculatorAiPlaygournd.shared") {
            sharedDefaults.removeObject(forKey: "widget.currentWeight")
            sharedDefaults.removeObject(forKey: "widget.useMetricUnits")
            sharedDefaults.removeObject(forKey: "widget.lastWeightDate")
            sharedDefaults.removeObject(forKey: "widget.weightUpdatedFromWidget")
            sharedDefaults.removeObject(forKey: "widget.pendingWeightUpdate")
        }
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
        repository = nil
        viewModel = nil
    }
    
    func testInitialState() {
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }
    
    func testTimeFilterDisplayNames() {
        // Then
        XCTAssertEqual(TimeFilter.oneWeek.displayName, "Last 7 Days")
        XCTAssertEqual(TimeFilter.oneMonth.displayName, "Last Month")
        XCTAssertEqual(TimeFilter.threeMonths.displayName, "Last 3 Months")
        XCTAssertEqual(TimeFilter.sixMonths.displayName, "Last 6 Months")
        XCTAssertEqual(TimeFilter.oneYear.displayName, "Last Year")
        XCTAssertEqual(TimeFilter.all.displayName, "All Time")
    }
    
    func testTimeFilterMonths() {
        // Then
        XCTAssertNil(TimeFilter.oneWeek.months)
        XCTAssertEqual(TimeFilter.oneMonth.months, 1)
        XCTAssertEqual(TimeFilter.threeMonths.months, 3)
        XCTAssertEqual(TimeFilter.sixMonths.months, 6)
        XCTAssertEqual(TimeFilter.oneYear.months, 12)
        XCTAssertNil(TimeFilter.all.months)
    }
    
    func testTimeFilterStartDate() {
        // Given
        let calendar = Calendar.current
        let now = Date()
        
        // When
        let oneWeekStart = TimeFilter.oneWeek.startDate
        let oneMonthStart = TimeFilter.oneMonth.startDate
        
        // Then
        XCTAssertLessThan(oneWeekStart, now)
        XCTAssertLessThan(oneMonthStart, now)
        
        // One week should be approximately 7 days ago
        let daysDiff = calendar.dateComponents([.day], from: oneWeekStart, to: now).day ?? 0
        XCTAssertGreaterThanOrEqual(daysDiff, 6)
        XCTAssertLessThanOrEqual(daysDiff, 8) // Allow some tolerance
    }
    
    func testCaloriesTimeFilterDisplayNames() {
        // Then
        XCTAssertEqual(CaloriesTimeFilter.oneWeek.displayName, "Last 7 Days")
        XCTAssertEqual(CaloriesTimeFilter.twoWeeks.displayName, "Last 2 Weeks")
        XCTAssertEqual(CaloriesTimeFilter.threeWeeks.displayName, "Last 3 Weeks")
        XCTAssertEqual(CaloriesTimeFilter.oneMonth.displayName, "Last Month")
    }
    
    func testCaloriesTimeFilterDays() {
        // Then
        XCTAssertEqual(CaloriesTimeFilter.oneWeek.days, 7)
        XCTAssertEqual(CaloriesTimeFilter.twoWeeks.days, 14)
        XCTAssertEqual(CaloriesTimeFilter.threeWeeks.days, 21)
        XCTAssertEqual(CaloriesTimeFilter.oneMonth.days, 30)
    }
    
    func testCaloriesTimeFilterStartDate() {
        // Given
        let calendar = Calendar.current
        let now = Date()
        
        // When
        let oneWeekStart = CaloriesTimeFilter.oneWeek.startDate
        
        // Then
        XCTAssertLessThan(oneWeekStart, now)
        let daysDiff = calendar.dateComponents([.day], from: oneWeekStart, to: now).day ?? 0
        XCTAssertGreaterThanOrEqual(daysDiff, 6)
        XCTAssertLessThanOrEqual(daysDiff, 8)
    }
    
    // MARK: - Weight Update Tests
    
    func testUpdateWeightCreatesNewEntry() async throws {
        // Given
        let newWeight = 75.5 // kg
        UserSettings.shared.useMetricUnits = true
        
        // When
        await viewModel.updateWeight(newWeight)
        
        // Then - should create a new weight entry for today
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate<WeightEntry> { entry in
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
                return entry.date >= today && entry.date < tomorrow
            }
        )
        let entries = try context.fetch(descriptor)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weight, newWeight, accuracy: 0.01)
    }
    
    func testUpdateWeightUpdatesExistingEntry() async throws {
        // Given
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let initialWeight = 70.0
        let updatedWeight = 70.5
        
        // Create existing entry for today
        let existingEntry = WeightEntry(weight: initialWeight, date: today)
        context.insert(existingEntry)
        try context.save()
        
        // When
        await viewModel.updateWeight(updatedWeight)
        
        // Then - should update existing entry, not create new one
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate<WeightEntry> { entry in
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
                return entry.date >= today && entry.date < tomorrow
            }
        )
        let entries = try context.fetch(descriptor)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weight, updatedWeight, accuracy: 0.01)
    }
    
    func testUpdateWeightUpdatesUserSettings() async throws {
        // Given
        let newWeight = 72.0 // kg
        UserSettings.shared.useMetricUnits = true
        let initialWeight = UserSettings.shared.currentWeight
        
        // When
        await viewModel.updateWeight(newWeight)
        
        // Then - UserSettings should be updated
        XCTAssertNotEqual(UserSettings.shared.currentWeight, initialWeight)
        XCTAssertEqual(UserSettings.shared.currentWeight, newWeight, accuracy: 0.01)
    }
    
    func testUpdateWeightConvertsToKilograms() async throws {
        // Given
        let weightInLbs = 154.0
        UserSettings.shared.useMetricUnits = false
        let expectedKg = weightInLbs / 2.20462
        
        // When
        await viewModel.updateWeight(weightInLbs)
        
        // Then - should store in kg internally
        let descriptor = FetchDescriptor<WeightEntry>()
        let entries = try context.fetch(descriptor)
        if let entry = entries.first {
            XCTAssertEqual(entry.weight, expectedKg, accuracy: 0.1)
        }
    }
    
    // MARK: - Most Recent Weight Tests
    
    func testMostRecentWeightFromHistory() async throws {
        // Given
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Create weight entries
        let entry1 = WeightEntry(weight: 70.0, date: yesterday)
        let entry2 = WeightEntry(weight: 71.0, date: today)
        context.insert(entry1)
        context.insert(entry2)
        try context.save()
        
        // When
        await viewModel.loadWeightHistory()
        
        // Then - most recent should be the latest entry
        XCTAssertEqual(viewModel.mostRecentWeight, 71.0, accuracy: 0.01)
    }
    
    func testMostRecentWeightFallsBackToDisplayWeight() {
        // Given - no weight history
        viewModel.weightHistory = []
        UserSettings.shared.currentWeight = 70.0
        
        // When
        let mostRecent = viewModel.mostRecentWeight
        
        // Then - should use display weight
        XCTAssertEqual(mostRecent, 70.0, accuracy: 0.01)
    }
    
    // MARK: - Weight History Loading Tests
    
    func testLoadWeightHistorySortsAscending() async throws {
        // Given
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        
        // Create entries out of order
        let entry1 = WeightEntry(weight: 71.0, date: today)
        let entry2 = WeightEntry(weight: 70.5, date: yesterday)
        let entry3 = WeightEntry(weight: 70.0, date: twoDaysAgo)
        context.insert(entry1)
        context.insert(entry2)
        context.insert(entry3)
        try context.save()
        
        // When
        await viewModel.loadWeightHistory()
        
        // Then - should be sorted ascending (oldest first)
        XCTAssertEqual(viewModel.weightHistory.count, 3)
        XCTAssertEqual(viewModel.weightHistory.first?.weight, 70.0, accuracy: 0.01)
        XCTAssertEqual(viewModel.weightHistory.last?.weight, 71.0, accuracy: 0.01)
    }
    
    func testLoadWeightHistoryCalculatesStats() async throws {
        // Given
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let entry1 = WeightEntry(weight: 70.0, date: yesterday)
        let entry2 = WeightEntry(weight: 71.0, date: today)
        context.insert(entry1)
        context.insert(entry2)
        try context.save()
        
        // When
        await viewModel.loadWeightHistory()
        
        // Then - stats should be calculated
        XCTAssertEqual(viewModel.totalWeightChange, 1.0, accuracy: 0.01)
        XCTAssertEqual(viewModel.averageWeight, 70.5, accuracy: 0.01)
        XCTAssertEqual(viewModel.minWeight, 70.0, accuracy: 0.01)
        XCTAssertEqual(viewModel.maxWeight, 71.0, accuracy: 0.01)
    }
    
    // MARK: - Weight Stats Calculation Tests
    
    func testCalculateWeightStatsWithEmptyHistory() async throws {
        // Given
        viewModel.weightHistory = []
        
        // When - load weight history (which triggers calculateWeightStats)
        await viewModel.loadWeightHistory()
        
        // Then - all stats should be zero
        XCTAssertEqual(viewModel.totalWeightChange, 0)
        XCTAssertEqual(viewModel.averageWeight, 0)
        XCTAssertEqual(viewModel.minWeight, 0)
        XCTAssertEqual(viewModel.maxWeight, 0)
    }
    
    func testCalculateWeightStatsWithSingleEntry() async throws {
        // Given
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entry = WeightEntry(weight: 70.0, date: today)
        context.insert(entry)
        try context.save()
        
        // When - load weight history (which triggers calculateWeightStats)
        await viewModel.loadWeightHistory()
        
        // Then
        XCTAssertEqual(viewModel.totalWeightChange, 0) // No change with single entry
        XCTAssertEqual(viewModel.averageWeight, 70.0, accuracy: 0.01)
        XCTAssertEqual(viewModel.minWeight, 70.0, accuracy: 0.01)
        XCTAssertEqual(viewModel.maxWeight, 70.0, accuracy: 0.01)
    }
    
    // MARK: - Widget Sync Tests
    
    func testUpdateWeightSyncsToWidget() async throws {
        // Given
        let weight = 75.0
        UserSettings.shared.useMetricUnits = true
        let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            XCTFail("Could not access shared UserDefaults")
            return
        }
        
        // When
        await viewModel.updateWeight(weight)
        
        // Then - widget data should be synced
        let syncedWeight = sharedDefaults.double(forKey: "widget.currentWeight")
        let useMetric = sharedDefaults.bool(forKey: "widget.useMetricUnits")
        
        XCTAssertEqual(syncedWeight, weight, accuracy: 0.01)
        XCTAssertTrue(useMetric)
        XCTAssertNotNil(sharedDefaults.object(forKey: "widget.lastWeightDate"))
    }
    
    // MARK: - Time Filter Tests
    
    func testTimeFilterNinetyDays() {
        // Given
        let filter = TimeFilter.ninetyDays
        
        // Then
        XCTAssertEqual(filter.days, 90)
        XCTAssertNil(filter.months) // Uses days, not months
    }
    
    func testTimeFilterAll() {
        // Given
        let filter = TimeFilter.all
        
        // Then
        XCTAssertNil(filter.days)
        XCTAssertNil(filter.months)
        // Start date should be far in the past
        let calendar = Calendar.current
        let yearsAgo = calendar.dateComponents([.year], from: filter.startDate, to: Date()).year ?? 0
        XCTAssertGreaterThan(yearsAgo, 5) // Should be at least 5 years ago
    }
}



