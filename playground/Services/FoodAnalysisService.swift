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
    static let requestTimeoutInterval: TimeInterval = 90  // Increased to 90 seconds for barcode analysis
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
        session: URLSession? = nil,
        authManager: AuthenticationManager = .shared
    ) {
        // Create a custom URLSession with proper timeout configuration
        // This ensures timeouts are respected even for long-running requests like barcode analysis
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = APIConfiguration.requestTimeoutInterval
        configuration.timeoutIntervalForResource = APIConfiguration.requestTimeoutInterval * 2 // Allow 2x for resource timeout
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = session ?? URLSession(configuration: configuration)
        self.authManager = authManager
    }

    func analyzeFood(
        image: UIImage,
        mode: ScanMode = .food,
        foodHint: String? = nil
    ) async throws -> FoodAnalysisResult {
        try AIConsentManager.shared.requireConsent()
        
        print("🔵 [FoodAnalysis] ===== Starting food analysis =====")
        print("🔵 [FoodAnalysis] Mode: \(mode)")
        print("🔵 [FoodAnalysis] Food hint: \(foodHint ?? "none")")
        print("🔵 [FoodAnalysis] Image size: \(image.size)")
        
        let (userId, token) = try getCredentials()
        print("🔵 [FoodAnalysis] User ID: \(userId)")
        print("🔵 [FoodAnalysis] Token present: \(!token.isEmpty)")
        
        let base64Image = try encodeImage(image)
        print("🔵 [FoodAnalysis] Base64 image length: \(base64Image.count) characters")
        
        let request = try buildRequest(
            base64Image: base64Image,
            userId: userId,
            token: token,
            mode: mode,
            foodHint: foodHint
        )

        print("🔵 [FoodAnalysis] Request built successfully")
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
        // Set timeout on the request (URLSession configuration also has timeout)
        // Allow longer timeout for barcode analysis which may take more time
        if mode == .barcode {
            request.timeoutInterval = APIConfiguration.requestTimeoutInterval * 1.5  // 135 seconds for barcode
        } else {
            request.timeoutInterval = APIConfiguration.requestTimeoutInterval
        }

        let requestBody = AnalyzeRequest(
            image: base64Image,
            userId: userId,
            mode: mode,
            foodHint: foodHint
        )
        request.httpBody = try encoder.encode(requestBody)
        
        // Log request details for debugging
        print("🔵 [FoodAnalysis] Request URL: \(url.absoluteString)")
        print("🔵 [FoodAnalysis] Request timeout: \(request.timeoutInterval) seconds")
        print("🔵 [FoodAnalysis] Request mode: \(mode.rawValue)")
        print("🔵 [FoodAnalysis] Request body size: \(request.httpBody?.count ?? 0) bytes")

        return request
    }

    private func performRequest(
        _ request: URLRequest
    ) async throws -> FoodAnalysisResult {
        // Log request details
        print("🔵 [FoodAnalysis] Starting request to: \(request.url?.absoluteString ?? "unknown")")
        print("🔵 [FoodAnalysis] Method: \(request.httpMethod ?? "unknown")")
        print("🔵 [FoodAnalysis] Timeout: \(request.timeoutInterval) seconds")
        print("🔵 [FoodAnalysis] Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let body = request.httpBody {
            print("🔵 [FoodAnalysis] Request body size: \(body.count) bytes")
            if let bodyString = String(data: body, encoding: .utf8) {
                let preview = String(bodyString.prefix(200))
                print("🔵 [FoodAnalysis] Request body preview: \(preview)...")
            }
        }
        
        do {
            // Use async/await with proper timeout handling
            let (data, response) = try await session.data(for: request)
            
            // Log response details
            print("🟢 [FoodAnalysis] Received response")
            if let httpResponse = response as? HTTPURLResponse {
                print("🟢 [FoodAnalysis] Status code: \(httpResponse.statusCode)")
                print("🟢 [FoodAnalysis] Response headers: \(httpResponse.allHeaderFields)")
            }
            print("🟢 [FoodAnalysis] Response data size: \(data.count) bytes")
            
            // Log response data content for debugging
            if data.isEmpty {
                print("⚠️ [FoodAnalysis] WARNING: Response data is EMPTY!")
            } else {
                if let dataString = String(data: data, encoding: .utf8) {
                    let preview = String(dataString.prefix(500))
                    print("🟢 [FoodAnalysis] Response data preview: \(preview)")
                } else {
                    print("⚠️ [FoodAnalysis] Response data is not valid UTF-8 string")
                }
            }
            
            return try processResponse(data: data, response: response)
        } catch let error as FoodAnalysisError {
            print("🔴 [FoodAnalysis] FoodAnalysisError: \(error)")
            throw error
        } catch let error as DecodingError {
            print("🔴 [FoodAnalysis] DecodingError: \(error)")
            print("🔴 [FoodAnalysis] DecodingError details:")
            switch error {
            case .typeMismatch(let type, let context):
                print("   - Type mismatch: expected \(type), context: \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("   - Value not found: \(type), context: \(context.debugDescription)")
            case .keyNotFound(let key, let context):
                print("   - Key not found: \(key.stringValue), context: \(context.debugDescription)")
            case .dataCorrupted(let context):
                print("   - Data corrupted: \(context.debugDescription)")
            @unknown default:
                print("   - Unknown decoding error")
            }
            throw FoodAnalysisError.decodingError(error)
        } catch {
            print("🔴 [FoodAnalysis] Network error: \(error.localizedDescription)")
            print("🔴 [FoodAnalysis] Error type: \(type(of: error))")
            throw FoodAnalysisError.networkError(error)
        }
    }

    private func processResponse(
        data: Data,
        response: URLResponse
    ) throws -> FoodAnalysisResult {
        print("🟡 [FoodAnalysis] Processing response...")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔴 [FoodAnalysis] Invalid response type: \(type(of: response))")
            throw FoodAnalysisError.invalidResponse
        }

        print("🟡 [FoodAnalysis] Validating HTTP status: \(httpResponse.statusCode)")
        try validateHTTPStatus(httpResponse.statusCode, data: data)

        // Check if data is empty before decoding
        if data.isEmpty {
            print("🔴 [FoodAnalysis] ERROR: Data is empty, cannot decode!")
            throw FoodAnalysisError.decodingError(
                DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: [],
                        debugDescription: "Response data is empty"
                    )
                )
            )
        }

        print("🟡 [FoodAnalysis] Attempting to decode AnalyzeResponse from \(data.count) bytes")
        
        do {
            let apiResponse = try decoder.decode(AnalyzeResponse.self, from: data)
            print("🟢 [FoodAnalysis] Successfully decoded response")
            print("🟢 [FoodAnalysis] Response.ok: \(apiResponse.ok)")
            print("🟢 [FoodAnalysis] Response.error: \(apiResponse.error ?? "nil")")
            print("🟢 [FoodAnalysis] Response.analysis: \(apiResponse.analysis != nil ? "present" : "nil")")

            guard apiResponse.ok, let analysis = apiResponse.analysis else {
                let errorMessage = apiResponse.error ?? "Unknown error"
                print("🔴 [FoodAnalysis] API returned error: \(errorMessage)")
                throw FoodAnalysisError.serverError(errorMessage)
            }

            print("🟢 [FoodAnalysis] Analysis - foodDetected: \(analysis.foodDetected)")
            print("🟢 [FoodAnalysis] Analysis - foodName: \(analysis.foodName ?? "nil")")
            print("🟢 [FoodAnalysis] Analysis - totalCalories: \(analysis.totalCalories ?? 0)")

            if !analysis.foodDetected {
                print("⚠️ [FoodAnalysis] No food detected in analysis")
                throw FoodAnalysisError.noFoodDetected(analysis.notes)
            }

            print("🟢 [FoodAnalysis] Mapping to result...")
            return mapToResult(analysis)
        } catch let decodingError as DecodingError {
            print("🔴 [FoodAnalysis] Decoding failed in processResponse")
            print("🔴 [FoodAnalysis] DecodingError: \(decodingError)")
            
            // Try to get more details about what went wrong
            if let dataString = String(data: data, encoding: .utf8) {
                print("🔴 [FoodAnalysis] Full response data: \(dataString)")
            }
            
            throw FoodAnalysisError.decodingError(decodingError)
        }
    }

    private func validateHTTPStatus(
        _ statusCode: Int,
        data: Data
    ) throws {
        print("🟡 [FoodAnalysis] Validating HTTP status code: \(statusCode)")
        
        switch statusCode {
        case 200:
            print("🟢 [FoodAnalysis] Status 200 OK")
            return
        case 400:
            print("🔴 [FoodAnalysis] Status 400 Bad Request")
            print("🔴 [FoodAnalysis] Error data size: \(data.count) bytes")
            if !data.isEmpty {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("🔴 [FoodAnalysis] Error response: \(errorString)")
                }
                let errorResponse = try? decoder.decode(AnalyzeResponse.self, from: data)
                throw FoodAnalysisError.serverError(errorResponse?.error ?? "Bad request")
            } else {
                throw FoodAnalysisError.serverError("Bad request (empty response)")
            }
        case 423:
            print("🔴 [FoodAnalysis] Status 423 Authentication Failed")
            throw FoodAnalysisError.authenticationFailed
        case 500:
            print("🔴 [FoodAnalysis] Status 500 Server Error")
            print("🔴 [FoodAnalysis] Error data size: \(data.count) bytes")
            if !data.isEmpty {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("🔴 [FoodAnalysis] Error response: \(errorString)")
                }
                let errorResponse = try? decoder.decode(AnalyzeResponse.self, from: data)
                throw FoodAnalysisError.serverError(errorResponse?.error ?? "Server error")
            } else {
                throw FoodAnalysisError.serverError("Server error (empty response)")
            }
        default:
            print("🔴 [FoodAnalysis] Unexpected status code: \(statusCode)")
            print("🔴 [FoodAnalysis] Response data size: \(data.count) bytes")
            if !data.isEmpty, let errorString = String(data: data, encoding: .utf8) {
                print("🔴 [FoodAnalysis] Response content: \(errorString)")
            }
            throw FoodAnalysisError.serverError("Unexpected status code: \(statusCode)")
        }
    }

    private func mapToResult(
        _ analysis: AnalysisData
    ) -> FoodAnalysisResult {
        print("🟡 [FoodAnalysis] Mapping analysis to result...")
        print("🟡 [FoodAnalysis] API confidence string: \(analysis.confidence ?? "nil")")
        
        let confidenceLevel = analysis.confidence.flatMap { ConfidenceLevel(rawValue: $0) }
        if let conf = confidenceLevel {
            print("🟢 [FoodAnalysis] ConfidenceLevel enum: \(conf)")
            print("🟢 [FoodAnalysis] Confidence numeric value: \(conf.numericValue)")
        } else {
            print("⚠️ [FoodAnalysis] Could not convert confidence string to ConfidenceLevel")
        }
        
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
            // Estimate using standard macro distribution: 30% protein, 40% carbs, 30% fat
            // This matches the standard split used in goal calculations
            let calories = Double(itemCalories)
            return (
                protein: calories * 0.30 / 4,  // 4 cal per gram of protein
                carbs: calories * 0.40 / 4,  // 4 cal per gram of carbs
                fat: calories * 0.30 / 9  // 9 cal per gram of fat
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
