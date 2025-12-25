//
//  NetworkRetryTests.swift
//  CalCalculatorTests
//
//  Unit tests for NetworkRetry utility
//

import XCTest
@testable import playground

final class NetworkRetryTests: XCTestCase {
    
    func testRetrySuccessOnFirstAttempt() async throws {
        // Given
        var attemptCount = 0
        let operation: () async throws -> String = {
            attemptCount += 1
            return "Success"
        }
        
        // When
        let result = try await NetworkRetry.retry(maxRetries: 3, operation: operation)
        
        // Then
        XCTAssertEqual(result, "Success")
        XCTAssertEqual(attemptCount, 1)
    }
    
    func testRetrySuccessAfterFailures() async throws {
        // Given
        var attemptCount = 0
        let operation: () async throws -> String = {
            attemptCount += 1
            if attemptCount < 3 {
                throw NSError(domain: "TestError", code: 500)
            }
            return "Success"
        }
        
        // When
        let result = try await NetworkRetry.retry(
            maxRetries: 3,
            initialDelay: 0.01, // Short delay for testing
            operation: operation
        )
        
        // Then
        XCTAssertEqual(result, "Success")
        XCTAssertEqual(attemptCount, 3)
    }
    
    func testRetryExhaustsAllAttempts() async throws {
        // Given
        var attemptCount = 0
        let operation: () async throws -> String = {
            attemptCount += 1
            throw NSError(domain: "TestError", code: 500)
        }
        
        // When & Then
        do {
            _ = try await NetworkRetry.retry(
                maxRetries: 2,
                initialDelay: 0.01,
                operation: operation
            )
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertEqual(attemptCount, 3) // 1, 2, 3 = 3 attempts total (0...maxRetries)
        }
    }
    
    func testRetryExponentialBackoff() async throws {
        // Given
        var delays: [TimeInterval] = []
        let startTime = Date()
        var lastTime = startTime
        var attemptCount = 0
        
        let operation: () async throws -> String = {
            attemptCount += 1
            let currentTime = Date()
            if attemptCount > 1 {
                delays.append(currentTime.timeIntervalSince(lastTime))
            }
            lastTime = currentTime
            
            if attemptCount < 3 {
                throw NSError(domain: "TestError", code: 500)
            }
            return "Success"
        }
        
        // When
        _ = try await NetworkRetry.retry(
            maxRetries: 3,
            initialDelay: 0.1,
            backoffMultiplier: 2.0,
            operation: operation
        )
        
        // Then
        XCTAssertEqual(delays.count, 2)
        // First delay should be ~0.1s, second should be ~0.2s (with some tolerance)
        XCTAssertGreaterThanOrEqual(delays[0], 0.08)
        XCTAssertLessThanOrEqual(delays[0], 0.15)
        XCTAssertGreaterThanOrEqual(delays[1], 0.18)
        XCTAssertLessThanOrEqual(delays[1], 0.25)
    }
    
    func testRetryDoesNotRetryOnAuthenticationError() async throws {
        // Given
        var attemptCount = 0
        let operation: () async throws -> String = {
            attemptCount += 1
            throw FoodAnalysisError.authenticationFailed
        }
        
        // When & Then
        do {
            _ = try await NetworkRetry.retry(
                maxRetries: 3,
                initialDelay: 0.01,
                operation: operation
            )
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertEqual(attemptCount, 1) // Should not retry on auth errors
        }
    }
    
    func testRetryDoesNotRetryOnNoFoodDetected() async throws {
        // Given
        var attemptCount = 0
        let operation: () async throws -> String = {
            attemptCount += 1
            throw FoodAnalysisError.noFoodDetected("No food")
        }
        
        // When & Then
        do {
            _ = try await NetworkRetry.retry(
                maxRetries: 3,
                initialDelay: 0.01,
                operation: operation
            )
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertEqual(attemptCount, 1) // Should not retry on no food detected
        }
    }
    
    func testIsRetryable() {
        // Then
        XCTAssertTrue(NetworkRetry.isRetryable(FoodAnalysisError.networkError))
        XCTAssertFalse(NetworkRetry.isRetryable(FoodAnalysisError.authenticationFailed))
        XCTAssertFalse(NetworkRetry.isRetryable(FoodAnalysisError.noFoodDetected(notes: nil)))
        
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        XCTAssertTrue(NetworkRetry.isRetryable(timeoutError))
        
        let connectionError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        XCTAssertTrue(NetworkRetry.isRetryable(connectionError))
    }
}

