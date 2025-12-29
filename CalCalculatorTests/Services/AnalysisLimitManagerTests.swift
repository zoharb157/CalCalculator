//
//  AnalysisLimitManagerTests.swift
//  CalCalculatorTests
//
//  Unit tests for AnalysisLimitManager
//

import XCTest
@testable import playground

@MainActor
final class AnalysisLimitManagerTests: XCTestCase {
    
    var manager: AnalysisLimitManager!
    let testKey = "test_analysis_count"
    
    override func setUp() {
        super.setUp()
        manager = AnalysisLimitManager.shared
        // Reset count before each test
        manager.resetAnalysisCount()
    }
    
    override func tearDown() {
        // Clean up
        manager.resetAnalysisCount()
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialAnalysisCount() {
        XCTAssertEqual(manager.currentAnalysisCount, 0)
    }
    
    // MARK: - Can Perform Analysis Tests
    
    func testCanPerformAnalysisWhenSubscribed() {
        // Subscribed users can always perform analysis
        XCTAssertTrue(manager.canPerformAnalysis(isSubscribed: true))
        
        // Even after using free analysis
        manager.recordAnalysis()
        XCTAssertTrue(manager.canPerformAnalysis(isSubscribed: true))
    }
    
    func testCanPerformAnalysisWhenNotSubscribed() {
        // Non-subscribed users can perform one free analysis
        XCTAssertTrue(manager.canPerformAnalysis(isSubscribed: false))
        
        // After using free analysis, should return false
        let recorded = manager.recordAnalysis()
        XCTAssertTrue(recorded) // Should successfully record
        XCTAssertFalse(manager.canPerformAnalysis(isSubscribed: false))
    }
    
    // MARK: - Record Analysis Tests
    
    func testRecordAnalysis() {
        XCTAssertEqual(manager.currentAnalysisCount, 0)
        
        let result = manager.recordAnalysis()
        XCTAssertTrue(result)
        XCTAssertEqual(manager.currentAnalysisCount, 1)
        
        // Try to record again (should fail for non-subscribed)
        let result2 = manager.recordAnalysis()
        XCTAssertFalse(result2) // Should fail because limit reached
        XCTAssertEqual(manager.currentAnalysisCount, 1) // Should still be 1
    }
    
    func testRecordAnalysisMultipleTimes() {
        // First analysis should succeed
        XCTAssertTrue(manager.recordAnalysis())
        XCTAssertEqual(manager.currentAnalysisCount, 1)
        
        // Second analysis should fail (limit reached)
        XCTAssertFalse(manager.recordAnalysis())
        XCTAssertEqual(manager.currentAnalysisCount, 1) // Still 1, not 2
    }
    
    // MARK: - Reset Tests
    
    func testResetAnalysisCount() {
        // Record an analysis
        manager.recordAnalysis()
        XCTAssertEqual(manager.currentAnalysisCount, 1)
        
        // Reset
        manager.resetAnalysisCount()
        XCTAssertEqual(manager.currentAnalysisCount, 0)
        
        // Should be able to perform analysis again
        XCTAssertTrue(manager.canPerformAnalysis(isSubscribed: false))
    }
    
    // MARK: - Remaining Free Analyses Tests
    
    func testRemainingFreeAnalysesWhenSubscribed() {
        // Subscribed users have unlimited analyses
        XCTAssertEqual(manager.remainingFreeAnalyses(isSubscribed: true), Int.max)
        
        // Even after recording
        manager.recordAnalysis()
        XCTAssertEqual(manager.remainingFreeAnalyses(isSubscribed: true), Int.max)
    }
    
    func testRemainingFreeAnalysesWhenNotSubscribed() {
        // Initially should have 1 free analysis
        XCTAssertEqual(manager.remainingFreeAnalyses(isSubscribed: false), 1)
        
        // After using it, should have 0
        manager.recordAnalysis()
        XCTAssertEqual(manager.remainingFreeAnalyses(isSubscribed: false), 0)
        
        // After reset, should have 1 again
        manager.resetAnalysisCount()
        XCTAssertEqual(manager.remainingFreeAnalyses(isSubscribed: false), 1)
    }
}

