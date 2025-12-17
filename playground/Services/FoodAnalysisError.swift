//
//  FoodAnalysisError.swift
//  playground
//
//  Created by Bassam-Hillo on 18/12/2025.
//

import Foundation

enum FoodAnalysisError: LocalizedError {
    case imageProcessingFailed
    case imageTooLarge
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(String)
    case decodingError(Error)
    case authenticationFailed
    case missingCredentials
    case noFoodDetected(String?)
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process the image"
        case .imageTooLarge:
            return "Image file is too large. Please use a smaller image."
        case .invalidURL:
            return "Invalid API URL configuration"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .authenticationFailed:
            return "Authentication failed. Please log in again."
        case .missingCredentials:
            return "Missing user credentials. Please log in."
        case .noFoodDetected(let notes):
            return notes ?? "No food items detected in the image. Please ensure the image clearly shows food."
        }
    }
    
    var isNoFoodDetected: Bool {
        if case .noFoodDetected = self { return true }
        return false
    }
    
    var isAuthenticationError: Bool {
        if case .authenticationFailed = self { return true }
        if case .missingCredentials = self { return true }
        return false
    }
}
