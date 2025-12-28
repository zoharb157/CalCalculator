//
//  NetworkRetry.swift
//  playground
//
//  Network retry utilities with exponential backoff
//

import Foundation

struct NetworkRetry {
    /// Retry a network operation with exponential backoff
    static func retry<T>(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        backoffMultiplier: Double = 2.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = initialDelay
        
        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry on certain errors
                if let foodError = error as? FoodAnalysisError {
                    if foodError.isAuthenticationError || foodError.isNoFoodDetected {
                        throw error
                    }
                }
                
                // If this was the last attempt, throw the error
                if attempt >= maxRetries {
                    throw error
                }
                
                // Wait before retrying (exponential backoff)
                let delay = min(currentDelay, maxDelay)
                print("⚠️ [NetworkRetry] Attempt \(attempt + 1) failed, retrying in \(delay)s...")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                currentDelay *= backoffMultiplier
            }
        }
        
        // This should never be reached, but just in case
        throw lastError ?? NSError(domain: "NetworkRetry", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
    }
    
    /// Check if error is retryable
    static func isRetryable(_ error: Error) -> Bool {
        if let foodError = error as? FoodAnalysisError {
            return foodError.isNetworkError
        }
        
        // Check for common network errors
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && (
            nsError.code == NSURLErrorTimedOut ||
            nsError.code == NSURLErrorNotConnectedToInternet ||
            nsError.code == NSURLErrorNetworkConnectionLost ||
            nsError.code == NSURLErrorCannotConnectToHost
        )
    }
}


