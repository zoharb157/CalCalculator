//
//  GoalsRepositoryTests.swift
//  CalCalculatorTests
//
//  Unit tests for GoalsRepository
//

import XCTest
@testable import playground

@MainActor
final class GoalsRepositoryTests: XCTestCase {
    
    var repository: GoalsRepository!
    
    override func setUpWithError() throws {
        repository = GoalsRepository.shared
    }
    
    override func tearDownWithError() throws {
        repository = nil
    }
    
    func testDefaultGoals() {
        // When
        let defaultGoals = GeneratedGoals.default
        
        // Then
        XCTAssertEqual(defaultGoals.calories, 2000)
        XCTAssertEqual(defaultGoals.proteinG, 150, accuracy: 0.01)
        XCTAssertEqual(defaultGoals.carbsG, 250, accuracy: 0.01)
        XCTAssertEqual(defaultGoals.fatG, 65, accuracy: 0.01)
    }
    
    func testGenerateGoalsWithCalorieGoal() async throws {
        // Given
        let onboardingData: [String: Any] = [
            "calorie_goal": 1800
        ]
        
        // When
        let goals = try await repository.generateGoals(from: onboardingData)
        
        // Then
        XCTAssertEqual(goals.calories, 1800)
        XCTAssertGreaterThan(goals.proteinG, 0)
        XCTAssertGreaterThan(goals.carbsG, 0)
        XCTAssertGreaterThan(goals.fatG, 0)
    }
    
    func testGenerateGoalsWithActivityLevel() async throws {
        // Given
        let onboardingData: [String: Any] = [
            "activity_level": "very_active"
        ]
        
        // When
        let goals = try await repository.generateGoals(from: onboardingData)
        
        // Then
        XCTAssertGreaterThan(goals.calories, 2000) // Very active should be higher
        XCTAssertGreaterThan(goals.proteinG, 0)
    }
    
    func testGenerateGoalsWithWeightLossGoal() async throws {
        // Given
        let onboardingData: [String: Any] = [
            "goal": "lose_weight"
        ]
        
        // When
        let goals = try await repository.generateGoals(from: onboardingData)
        
        // Then
        XCTAssertLessThan(goals.calories, 2000) // Weight loss should reduce calories
        XCTAssertGreaterThan(goals.proteinG, 0)
    }
    
    func testGenerateGoalsWithWeightGainGoal() async throws {
        // Given
        let onboardingData: [String: Any] = [
            "goal": "gain_weight"
        ]
        
        // When
        let goals = try await repository.generateGoals(from: onboardingData)
        
        // Then
        XCTAssertGreaterThan(goals.calories, 2000) // Weight gain should increase calories
        XCTAssertGreaterThan(goals.proteinG, 0)
    }
    
    func testSaveGoals() {
        // Given
        let goals = GeneratedGoals(calories: 2200, proteinG: 165, carbsG: 275, fatG: 73)
        let settings = UserSettings.shared
        let originalCalories = settings.calorieGoal
        
        // When
        repository.saveGoals(goals)
        
        // Then
        XCTAssertEqual(settings.calorieGoal, 2200)
        XCTAssertEqual(settings.proteinGoal, 165, accuracy: 0.01)
        XCTAssertEqual(settings.carbsGoal, 275, accuracy: 0.01)
        XCTAssertEqual(settings.fatGoal, 73, accuracy: 0.01)
        
        // Restore original
        settings.calorieGoal = originalCalories
    }
}


