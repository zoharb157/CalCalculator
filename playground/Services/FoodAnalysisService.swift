//
//  FoodAnalysisService.swift
//  playground
//
//  CalAI Clone - Food analysis service using Calories Analysis API
//

import Foundation
import UIKit

// MARK: - Calories API Service

enum APIConfiguration {
    static let baseURL = "https://app.caloriecount-ai.com"
    static let analyzeEndpoint = "/calories/analyze"
    static let imageCompressionQuality: CGFloat = 0.8
    static let requestTimeoutInterval: TimeInterval = 60
    static let maxImageSizeBytes = 4 * 1024 * 1024  // 4MB
}

protocol FoodAnalysisServiceProtocol {
    func analyzeFood(image: UIImage, mode: ScanMode, foodHint: String?) async throws -> FoodAnalysisResult
}

extension FoodAnalysisServiceProtocol {
    func analyzeFood(image: UIImage, mode: ScanMode = .food) async throws -> FoodAnalysisResult {
        try await analyzeFood(image: image, mode: mode, foodHint: nil)
    }
    
    func analyzeFood(image: UIImage, foodHint: String?) async throws -> FoodAnalysisResult {
        try await analyzeFood(image: image, mode: .food, foodHint: foodHint)
    }
    
    func analyzeFood(image: UIImage) async throws -> FoodAnalysisResult {
        try await analyzeFood(image: image, mode: .food, foodHint: nil)
    }
}

final class CaloriesAPIService: FoodAnalysisServiceProtocol {

    private let session: URLSession
    private let authManager: AuthenticationManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        session: URLSession = .shared,
        authManager: AuthenticationManager = .shared
    ) {
        self.session = session
        self.authManager = authManager
    }

    func analyzeFood(
        image: UIImage,
        mode: ScanMode = .food,
        foodHint: String? = nil
    ) async throws -> FoodAnalysisResult {
        let (userId, token) = try getCredentials()
        let base64Image = try encodeImage(image)
        let request = try buildRequest(
            base64Image: base64Image,
            userId: userId,
            token: token,
            mode: mode,
            foodHint: foodHint
        )

        return try await performRequest(request)
    }

    // MARK: - Private Helpers

    private func getCredentials() throws -> (
        userId: String,
        token: String
    ) {
        guard let userId = authManager.userId, let token = authManager.jwtToken else {
            throw FoodAnalysisError.missingCredentials
        }
        return (userId, token)
    }

    private func encodeImage(
        _ image: UIImage
    ) throws -> String {
        guard
            let imageData = image.jpegData(
                compressionQuality: APIConfiguration.imageCompressionQuality)
        else {
            throw FoodAnalysisError.imageProcessingFailed
        }

        if imageData.count > APIConfiguration.maxImageSizeBytes {
            throw FoodAnalysisError.imageTooLarge
        }

        return imageData.base64EncodedString()
    }

    private func buildRequest(
        base64Image: String,
        userId: String,
        token: String,
        mode: ScanMode = .food,
        foodHint: String? = nil
    ) throws -> URLRequest {
        var urlComponents = URLComponents(
            string: "\(APIConfiguration.baseURL)\(APIConfiguration.analyzeEndpoint)")
        urlComponents?.queryItems = [URLQueryItem(name: "user_id", value: userId)]

        guard let url = urlComponents?.url else {
            throw FoodAnalysisError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = APIConfiguration.requestTimeoutInterval

        let requestBody = AnalyzeRequest(
            image: base64Image,
            userId: userId,
            mode: mode,
            foodHint: foodHint
        )
        request.httpBody = try encoder.encode(requestBody)

        return request
    }

    private func performRequest(
        _ request: URLRequest
    ) async throws -> FoodAnalysisResult {
        do {
            let (data, response) = try await session.data(for: request)
            return try processResponse(data: data, response: response)
        } catch let error as FoodAnalysisError {
            throw error
        } catch let error as DecodingError {
            throw FoodAnalysisError.decodingError(error)
        } catch {
            throw FoodAnalysisError.networkError(error)
        }
    }

    private func processResponse(
        data: Data,
        response: URLResponse
    ) throws -> FoodAnalysisResult {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisError.invalidResponse
        }

        try validateHTTPStatus(httpResponse.statusCode, data: data)

        let apiResponse = try decoder.decode(AnalyzeResponse.self, from: data)

        guard apiResponse.ok, let analysis = apiResponse.analysis else {
            let errorMessage = apiResponse.error ?? "Unknown error"
            throw FoodAnalysisError.serverError(errorMessage)
        }

        if !analysis.foodDetected {
            throw FoodAnalysisError.noFoodDetected(analysis.notes)
        }

        return mapToResult(analysis)
    }

    private func validateHTTPStatus(
        _ statusCode: Int,
        data: Data
    ) throws {
        switch statusCode {
        case 200:
            return
        case 400:
            let errorResponse = try? decoder.decode(AnalyzeResponse.self, from: data)
            throw FoodAnalysisError.serverError(errorResponse?.error ?? "Bad request")
        case 423:
            throw FoodAnalysisError.authenticationFailed
        case 500:
            let errorResponse = try? decoder.decode(AnalyzeResponse.self, from: data)
            throw FoodAnalysisError.serverError(errorResponse?.error ?? "Server error")
        default:
            throw FoodAnalysisError.serverError("Unexpected status code: \(statusCode)")
        }
    }

    private func mapToResult(
        _ analysis: AnalysisData
    ) -> FoodAnalysisResult {
        let confidenceLevel = analysis.confidence.flatMap { ConfidenceLevel(rawValue: $0) }
        let totalCalories = analysis.totalCalories ?? 0

        let resultItems: [FoodItemResult]? = analysis.items?.map { item in
            let macros = calculateItemMacros(
                itemCalories: item.calories,
                totalCalories: totalCalories,
                breakdown: analysis.breakdown
            )

            return FoodItemResult(
                name: item.name,
                calories: item.calories,
                portion: item.portion,
                proteinG: macros.protein,
                carbsG: macros.carbs,
                fatG: macros.fat
            )
        }

        return FoodAnalysisResult(
            foodDetected: analysis.foodDetected,
            mealName: analysis.foodName,
            brand: analysis.brand,
            totalCalories: analysis.totalCalories,
            confidence: confidenceLevel,
            breakdown: analysis.breakdown,
            servingSize: analysis.servingSize,
            items: resultItems,
            source: analysis.source,
            barcode: analysis.barcode,
            ingredients: analysis.ingredients,
            labelType: analysis.labelType,
            notes: analysis.notes
        )
    }

    private func calculateItemMacros(
        itemCalories: Int,
        totalCalories: Int,
        breakdown: NutritionBreakdown?
    ) -> (protein: Double, carbs: Double, fat: Double) {
        guard let breakdown = breakdown, totalCalories > 0 else {
            // Estimate using typical macro distribution: 15% protein, 50% carbs, 35% fat
            let calories = Double(itemCalories)
            return (
                protein: calories * 0.15 / 4,  // 4 cal per gram of protein
                carbs: calories * 0.50 / 4,  // 4 cal per gram of carbs
                fat: calories * 0.35 / 9  // 9 cal per gram of fat
            )
        }

        // Distribute macros proportionally based on calories
        let ratio = Double(itemCalories) / Double(totalCalories)
        return (
            protein: breakdown.proteinG * ratio,
            carbs: breakdown.carbsG * ratio,
            fat: breakdown.fatG * ratio
        )
    }
}
