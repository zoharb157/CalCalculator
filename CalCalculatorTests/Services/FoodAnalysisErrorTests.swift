//
//  FoodAnalysisErrorTests.swift
//  CalCalculatorTests
//
//  Unit tests for FoodAnalysisError
//

import XCTest
@testable import playground

final class FoodAnalysisErrorTests: XCTestCase {
    
    func testErrorDescriptions() {
        // Then
        XCTAssertNotNil(FoodAnalysisError.imageProcessingFailed.errorDescription)
        XCTAssertNotNil(FoodAnalysisError.networkError.errorDescription)
        XCTAssertNotNil(FoodAnalysisError.decodingError.errorDescription)
        XCTAssertNotNil(FoodAnalysisError.authenticationFailed.errorDescription)
    }
    
    func testNoFoodDetectedError() {
        // Given
        let notes = "No food items detected in image"
        let error = FoodAnalysisError.noFoodDetected(notes)
        
        // Then
        if case .noFoodDetected(let errorNotes) = error {
            XCTAssertEqual(errorNotes, notes)
        } else {
            XCTFail("Expected noFoodDetected error")
        }
    }
    
    func testServerError() {
        // Given
        let message = "Internal server error"
        let error = FoodAnalysisError.serverError(message)
        
        // Then
        if case .serverError(let errorMessage) = error {
            XCTAssertEqual(errorMessage, message)
        } else {
            XCTFail("Expected serverError error")
        }
    }
    
    func testNetworkError() {
        // Given
        let underlyingError = NSError(domain: "Test", code: 500, userInfo: [NSLocalizedDescriptionKey: "Connection failed"])
        let error = FoodAnalysisError.networkError(underlyingError)
        
        // Then
        if case .networkError(let err) = error {
            XCTAssertEqual((err as NSError).code, 500)
        } else {
            XCTFail("Expected networkError error")
        }
    }
    
    func testDecodingError() {
        // Given
        let underlyingError = NSError(domain: "Test", code: 3840) // Decoding error code
        let error = FoodAnalysisError.decodingError(underlyingError)
        
        // Then
        if case .decodingError(let err) = error {
            XCTAssertEqual((err as NSError).code, 3840)
        } else {
            XCTFail("Expected decodingError error")
        }
    }
    
    func testErrorIsNetworkError() {
        // Then
        let networkErr = NSError(domain: "Test", code: 500)
        XCTAssertTrue(FoodAnalysisError.networkError(networkErr).isNetworkError)
        XCTAssertFalse(FoodAnalysisError.authenticationFailed.isNetworkError)
        let decodingErr = NSError(domain: "Test", code: 500)
        XCTAssertFalse(FoodAnalysisError.decodingError(decodingErr).isNetworkError)
    }
    
    func testErrorIsAuthenticationError() {
        // Then
        XCTAssertTrue(FoodAnalysisError.authenticationFailed.isAuthenticationError)
        XCTAssertTrue(FoodAnalysisError.missingCredentials.isAuthenticationError)
        XCTAssertFalse(FoodAnalysisError.networkError.isAuthenticationError)
    }
    
    func testErrorIsNoFoodDetected() {
        // Then
        let networkErr = NSError(domain: "Test", code: 500)
        XCTAssertTrue(FoodAnalysisError.noFoodDetected(nil).isNoFoodDetected)
        XCTAssertTrue(FoodAnalysisError.noFoodDetected("No food").isNoFoodDetected)
        XCTAssertFalse(FoodAnalysisError.networkError(networkErr).isNoFoodDetected)
    }
}

