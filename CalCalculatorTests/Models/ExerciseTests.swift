//
//  ExerciseTests.swift
//  CalCalculatorTests
//
//  Unit tests for Exercise model
//

import XCTest
@testable import playground

final class ExerciseTests: XCTestCase {
    
    func testExerciseInitialization() {
        // Given
        let type = ExerciseType.run
        let calories = 300
        let duration = 30
        let intensity = ExerciseIntensity.high
        let notes = "Morning run"
        let date = Date()
        
        // When
        let exercise = Exercise(
            type: type,
            calories: calories,
            duration: duration,
            intensity: intensity,
            notes: notes,
            date: date
        )
        
        // Then
        XCTAssertEqual(exercise.type, type)
        XCTAssertEqual(exercise.calories, calories)
        XCTAssertEqual(exercise.duration, duration)
        XCTAssertEqual(exercise.intensity, intensity)
        XCTAssertEqual(exercise.notes, notes)
        XCTAssertEqual(exercise.date, date)
    }
    
    func testExerciseDefaultValues() {
        // When
        let exercise = Exercise(type: .run, calories: 200, duration: 20)
        
        // Then
        XCTAssertNil(exercise.intensity)
        XCTAssertNil(exercise.notes)
    }
    
    func testExerciseTypeDisplayNames() {
        // Then
        XCTAssertEqual(ExerciseType.run.displayName, "Run")
        XCTAssertEqual(ExerciseType.weightLifting.displayName, "Weight lifting")
        XCTAssertEqual(ExerciseType.describe.displayName, "Describe")
        XCTAssertEqual(ExerciseType.manual.displayName, "Manual")
    }
    
    func testExerciseTypeIcons() {
        // Then
        XCTAssertEqual(ExerciseType.run.icon, "figure.run")
        XCTAssertEqual(ExerciseType.weightLifting.icon, "dumbbell.fill")
        XCTAssertEqual(ExerciseType.describe.icon, "text.bubble")
        XCTAssertEqual(ExerciseType.manual.icon, "flame.fill")
    }
    
    func testExerciseIntensityDisplayNames() {
        // Then
        XCTAssertEqual(ExerciseIntensity.high.displayName, "High")
        XCTAssertEqual(ExerciseIntensity.medium.displayName, "Medium")
        XCTAssertEqual(ExerciseIntensity.low.displayName, "Low")
    }
}

