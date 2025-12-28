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
}


