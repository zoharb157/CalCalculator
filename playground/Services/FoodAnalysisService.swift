//
//  FoodAnalysisService.swift
//  playground
//
//  CalAI Clone - Food analysis service using Calories Analysis API
//

import Foundation
import UIKit

// MARK: - Compile-time flag for API mode
#if DEBUG
let USE_REAL_API = false  // Set to true when you have a valid JWT token
#else
let USE_REAL_API = true
#endif

// MARK: - API Configuration
enum APIConfiguration {
    static let baseURL = "https://app.caloriecount-ai.com"
    static let analyzeEndpoint = "/calories/analyze"
    static let imageCompressionQuality: CGFloat = 0.8
}

// MARK: - Service Protocol

protocol FoodAnalysisServiceProtocol {
    func analyzeFood(image: UIImage) async throws -> FoodAnalysisResult
}

// MARK: - Confidence Level

enum ConfidenceLevel: String, Codable {
    case high
    case medium
    case low
    
    var numericValue: Double {
        switch self {
        case .high: return 0.9
        case .medium: return 0.7
        case .low: return 0.5
        }
    }
    
    var displayText: String {
        switch self {
        case .high: return "High Confidence"
        case .medium: return "Medium Confidence"
        case .low: return "Low Confidence"
        }
    }
}

// MARK: - Nutrition Breakdown (API Response)

struct NutritionBreakdown: Codable {
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    
    enum CodingKeys: String, CodingKey {
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
    }
    
    var toMacroData: MacroData {
        MacroData(
            calories: 0,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG
        )
    }
}

// MARK: - Food Item Result

struct FoodItemResult {
    let name: String
    let calories: Int
    let portion: String
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    
    func toMealItem() -> MealItem {
        let (portionValue, unit) = parsePortionString(portion)
        
        return MealItem(
            name: name,
            portion: portionValue,
            unit: unit,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG
        )
    }
    
    private func parsePortionString(_ portion: String) -> (Double, String) {
        let pattern = "([0-9]+\\.?[0-9]*|[0-9]+/[0-9]+)"
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: portion, range: NSRange(portion.startIndex..., in: portion)),
           let range = Range(match.range(at: 1), in: portion) {
            
            let numericPart = String(portion[range])
            let remainingPart = portion.replacingOccurrences(of: numericPart, with: "").trimmingCharacters(in: .whitespaces)
            
            if numericPart.contains("/") {
                let parts = numericPart.split(separator: "/")
                if parts.count == 2,
                   let numerator = Double(parts[0]),
                   let denominator = Double(parts[1]),
                   denominator != 0 {
                    return (numerator / denominator, remainingPart.isEmpty ? "serving" : remainingPart)
                }
            }
            
            if let value = Double(numericPart) {
                return (value, remainingPart.isEmpty ? "serving" : remainingPart)
            }
        }
        
        return (1.0, portion)
    }
}

// MARK: - Food Analysis Result (Unified result for the app)

struct FoodAnalysisResult {
    let foodDetected: Bool
    let mealName: String?
    let totalCalories: Int?
    let confidence: ConfidenceLevel?
    let breakdown: NutritionBreakdown?
    let items: [FoodItemResult]?
    let notes: String?
    
    func toMeal() -> Meal? {
        guard foodDetected,
              let mealName = mealName else {
            return nil
        }
        
        let meal = Meal(
            name: mealName,
            confidence: confidence?.numericValue ?? 0,
            notes: notes
        )
        
        if let items = items {
            meal.items = items.map { $0.toMealItem() }
        }
        
        return meal
    }
}

// MARK: - API Request/Response Models

struct CaloriesAnalyzeRequest: Codable {
    let image: String
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case image
        case userId = "user_id"
    }
}

struct CaloriesAnalyzeResponse: Codable {
    let ok: Bool
    let analysis: APIFoodAnalysis?
    let error: String?
    let exceptionType: String?
    
    enum CodingKeys: String, CodingKey {
        case ok
        case analysis
        case error
        case exceptionType = "exception_type"
    }
}

struct APIFoodAnalysis: Codable {
    let foodDetected: Bool
    let foodName: String?
    let totalCalories: Int?
    let confidence: String?
    let breakdown: NutritionBreakdown?
    let items: [APIFoodItem]?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case foodDetected = "food_detected"
        case foodName = "food_name"
        case totalCalories = "total_calories"
        case confidence
        case breakdown
        case items
        case notes
    }
    
    func toFoodAnalysisResult() -> FoodAnalysisResult {
        let confidenceLevel = confidence.flatMap { ConfidenceLevel(rawValue: $0) }
        
        let resultItems: [FoodItemResult]? = items?.map { apiItem in
            let estimatedProtein = Double(apiItem.calories) * 0.15 / 4
            let estimatedCarbs = Double(apiItem.calories) * 0.50 / 4
            let estimatedFat = Double(apiItem.calories) * 0.35 / 9
            
            return FoodItemResult(
                name: apiItem.name,
                calories: apiItem.calories,
                portion: apiItem.portion,
                proteinG: breakdown != nil ? (breakdown!.proteinG * Double(apiItem.calories) / Double(totalCalories ?? 1)) : estimatedProtein,
                carbsG: breakdown != nil ? (breakdown!.carbsG * Double(apiItem.calories) / Double(totalCalories ?? 1)) : estimatedCarbs,
                fatG: breakdown != nil ? (breakdown!.fatG * Double(apiItem.calories) / Double(totalCalories ?? 1)) : estimatedFat
            )
        }
        
        return FoodAnalysisResult(
            foodDetected: foodDetected,
            mealName: foodName,
            totalCalories: totalCalories,
            confidence: confidenceLevel,
            breakdown: breakdown,
            items: resultItems,
            notes: notes
        )
    }
}

struct APIFoodItem: Codable {
    let name: String
    let calories: Int
    let portion: String
}

// MARK: - Service Errors

enum FoodAnalysisError: LocalizedError {
    case imageProcessingFailed
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
        if case .noFoodDetected = self {
            return true
        }
        return false
    }
}

// MARK: - Service Factory

struct FoodAnalysisServiceFactory {
    static func createService() -> FoodAnalysisServiceProtocol {
        if USE_REAL_API {
            return CaloriesAPIService()
        } else {
            return MockFoodAnalysisService()
        }
    }
}

// MARK: - Authentication Manager

final class AuthenticationManager {
    static let shared = AuthenticationManager()
    
    private let defaults = UserDefaults.standard
    
    // Hardcoded API token for this app
    private let apiToken = "OdIlX0QEIodS2ixLg2v0WFI5Hb7EH9cFDGEaNa94Xts="
    
    private enum Keys {
        static let userId = "auth_user_id"
        static let tokenExpiration = "auth_token_expiration"
    }
    
    var userId: String? {
        get { defaults.string(forKey: Keys.userId) }
        set { defaults.set(newValue, forKey: Keys.userId) }
    }
    
    /// Returns the API token for authentication
    var jwtToken: String? {
        return apiToken
    }
    
    var tokenExpiration: Date? {
        get { defaults.object(forKey: Keys.tokenExpiration) as? Date }
        set { defaults.set(newValue, forKey: Keys.tokenExpiration) }
    }
    
    var isAuthenticated: Bool {
        // With hardcoded token, we just need a userId
        return userId != nil
    }
    
    private init() {
        // Generate a unique user ID if not already set
        if userId == nil {
            userId = "user_\(UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(16))"
        }
    }
    
    func setUserId(_ id: String) {
        self.userId = id
    }
    
    func clearCredentials() {
        userId = nil
        tokenExpiration = nil
    }
}

// MARK: - Calories API Service Implementation

final class CaloriesAPIService: FoodAnalysisServiceProtocol {
    
    private let session: URLSession
    private let authManager: AuthenticationManager
    
    init(session: URLSession = .shared, authManager: AuthenticationManager = .shared) {
        self.session = session
        self.authManager = authManager
    }
    
    func analyzeFood(image: UIImage) async throws -> FoodAnalysisResult {
        guard let userId = authManager.userId,
              let token = authManager.jwtToken else {
            throw FoodAnalysisError.missingCredentials
        }
        
        guard let imageData = image.jpegData(compressionQuality: APIConfiguration.imageCompressionQuality) else {
            throw FoodAnalysisError.imageProcessingFailed
        }
        let base64Image = imageData.base64EncodedString()
        
        var urlComponents = URLComponents(string: "\(APIConfiguration.baseURL)\(APIConfiguration.analyzeEndpoint)")
        urlComponents?.queryItems = [
            URLQueryItem(name: "user_id", value: userId)
        ]
        
        guard let url = urlComponents?.url else {
            throw FoodAnalysisError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        
        // Debug logging
        print("🔐 API Request URL: \(url.absoluteString)")
        print("🔐 Authorization Header: Bearer \(token)")
        print("🔐 User ID: \(userId)")
        
        let requestBody = CaloriesAnalyzeRequest(image: base64Image, userId: userId)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Debug: print raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔐 API Response: \(responseString)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FoodAnalysisError.invalidResponse
            }
            
            print("🔐 HTTP Status Code: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                break
            case 400:
                let errorResponse = try? JSONDecoder().decode(CaloriesAnalyzeResponse.self, from: data)
                throw FoodAnalysisError.serverError(errorResponse?.error ?? "Bad request")
            case 423:
                let errorResponse = try? JSONDecoder().decode(CaloriesAnalyzeResponse.self, from: data)
                print("🔐 423 Error Response: \(errorResponse?.error ?? "No error message")")
                throw FoodAnalysisError.authenticationFailed
            case 500:
                let errorResponse = try? JSONDecoder().decode(CaloriesAnalyzeResponse.self, from: data)
                throw FoodAnalysisError.serverError(errorResponse?.error ?? "Server error")
            default:
                throw FoodAnalysisError.serverError("Unexpected status code: \(httpResponse.statusCode)")
            }
            
            let apiResponse = try JSONDecoder().decode(CaloriesAnalyzeResponse.self, from: data)
            
            guard apiResponse.ok, let analysis = apiResponse.analysis else {
                throw FoodAnalysisError.serverError(apiResponse.error ?? "Unknown error")
            }
            
            if !analysis.foodDetected {
                throw FoodAnalysisError.noFoodDetected(analysis.notes)
            }
            
            return analysis.toFoodAnalysisResult()
            
        } catch let error as FoodAnalysisError {
            throw error
        } catch let error as DecodingError {
            throw FoodAnalysisError.decodingError(error)
        } catch {
            throw FoodAnalysisError.networkError(error)
        }
    }
}

// MARK: - Mock Implementation

final class MockFoodAnalysisService: FoodAnalysisServiceProtocol {
    
    private let mockResponses: [FoodAnalysisResult] = [
        FoodAnalysisResult(
            foodDetected: true,
            mealName: "Chicken Shawarma Bowl",
            totalCalories: 620,
            confidence: .medium,
            breakdown: NutritionBreakdown(proteinG: 42, carbsG: 55, fatG: 22, fiberG: 6),
            items: [
                FoodItemResult(name: "Chicken shawarma", calories: 320, portion: "150g", proteinG: 35, carbsG: 3, fatG: 18),
                FoodItemResult(name: "Rice", calories: 190, portion: "150g", proteinG: 4, carbsG: 41, fatG: 1),
                FoodItemResult(name: "Salad", calories: 60, portion: "2 cups", proteinG: 2, carbsG: 10, fatG: 1),
                FoodItemResult(name: "Tahini sauce", calories: 50, portion: "1 tbsp", proteinG: 1, carbsG: 1, fatG: 4)
            ],
            notes: "Estimates vary by recipe and portion size."
        ),
        FoodAnalysisResult(
            foodDetected: true,
            mealName: "Grilled Salmon Plate",
            totalCalories: 485,
            confidence: .high,
            breakdown: NutritionBreakdown(proteinG: 38, carbsG: 32, fatG: 24, fiberG: 5),
            items: [
                FoodItemResult(name: "Grilled salmon fillet", calories: 280, portion: "150g", proteinG: 32, carbsG: 0, fatG: 16),
                FoodItemResult(name: "Roasted vegetables", calories: 95, portion: "180g", proteinG: 3, carbsG: 18, fatG: 3),
                FoodItemResult(name: "Quinoa", calories: 110, portion: "100g", proteinG: 3, carbsG: 14, fatG: 5)
            ],
            notes: "Salmon provides omega-3 fatty acids."
        ),
        FoodAnalysisResult(
            foodDetected: true,
            mealName: "Berry Oatmeal Bowl",
            totalCalories: 380,
            confidence: .high,
            breakdown: NutritionBreakdown(proteinG: 12, carbsG: 58, fatG: 11, fiberG: 8),
            items: [
                FoodItemResult(name: "Oatmeal", calories: 220, portion: "200g", proteinG: 8, carbsG: 38, fatG: 4),
                FoodItemResult(name: "Mixed berries", calories: 50, portion: "100g", proteinG: 1, carbsG: 12, fatG: 0),
                FoodItemResult(name: "Almond butter", calories: 110, portion: "20g", proteinG: 3, carbsG: 8, fatG: 7)
            ],
            notes: "Great source of fiber and antioxidants."
        ),
        FoodAnalysisResult(
            foodDetected: true,
            mealName: "Cheeseburger with Fries",
            totalCalories: 890,
            confidence: .medium,
            breakdown: NutritionBreakdown(proteinG: 35, carbsG: 72, fatG: 52, fiberG: 4),
            items: [
                FoodItemResult(name: "Beef patty", calories: 280, portion: "120g", proteinG: 24, carbsG: 0, fatG: 20),
                FoodItemResult(name: "Burger bun", calories: 150, portion: "60g", proteinG: 4, carbsG: 28, fatG: 2),
                FoodItemResult(name: "Cheese slice", calories: 110, portion: "30g", proteinG: 6, carbsG: 1, fatG: 9),
                FoodItemResult(name: "French fries", calories: 320, portion: "150g", proteinG: 1, carbsG: 42, fatG: 16),
                FoodItemResult(name: "Condiments", calories: 30, portion: "30g", proteinG: 0, carbsG: 1, fatG: 5)
            ],
            notes: "High calorie meal - consider portion control."
        ),
        FoodAnalysisResult(
            foodDetected: true,
            mealName: "Caesar Salad with Chicken",
            totalCalories: 420,
            confidence: .high,
            breakdown: NutritionBreakdown(proteinG: 32, carbsG: 18, fatG: 26, fiberG: 3),
            items: [
                FoodItemResult(name: "Grilled chicken breast", calories: 180, portion: "120g", proteinG: 28, carbsG: 0, fatG: 6),
                FoodItemResult(name: "Romaine lettuce", calories: 25, portion: "150g", proteinG: 2, carbsG: 4, fatG: 0),
                FoodItemResult(name: "Parmesan cheese", calories: 120, portion: "30g", proteinG: 2, carbsG: 2, fatG: 8),
                FoodItemResult(name: "Caesar dressing", calories: 70, portion: "40ml", proteinG: 0, carbsG: 2, fatG: 7),
                FoodItemResult(name: "Croutons", calories: 25, portion: "25g", proteinG: 0, carbsG: 10, fatG: 5)
            ],
            notes: "Classic salad option with good protein content."
        )
    ]
    
    func analyzeFood(image: UIImage) async throws -> FoodAnalysisResult {
        // Simulate network delay (1.5-2.5 seconds)
        try await Task.sleep(nanoseconds: UInt64.random(in: 1_500_000_000...2_500_000_000))
        
        // 10% chance to simulate no food detected for testing
        if Int.random(in: 1...10) == 1 {
            throw FoodAnalysisError.noFoodDetected("No food items detected in the image. Please ensure the image clearly shows food.")
        }
        
        return mockResponses.randomElement()!
    }
}

// MARK: - Legacy Support (backward compatibility with existing Meal.swift)

struct MealAnalysisResponse: Codable {
    let mealName: String
    let total: MacroData
    let items: [MealItemDTO]
    let confidence: Double
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case mealName = "meal_name"
        case total, items, confidence, notes
    }
    
    func toMeal(photoURL: String? = nil) -> Meal {
        let meal = Meal(
            name: mealName,
            photoURL: photoURL,
            confidence: confidence,
            notes: notes
        )
        meal.items = items.map { $0.toMealItem() }
        return meal
    }
}
