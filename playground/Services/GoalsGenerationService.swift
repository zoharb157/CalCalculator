//
//  GoalsGenerationService.swift
//  playground
//
//  Service for generating personalized nutrition goals via API
//  This service makes requests from native Swift code to bypass CORS restrictions
//

import Foundation

// MARK: - Result Type

struct GoalsResult {
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
}

// MARK: - Request Models

struct GoalsGenerationRequest: Codable {
    let userId: String
    let gender: String
    let desiredWeight: Double
    let heightWeight: HeightWeightData
    let goal: String
    let goalSpeed: Int
    let activityLevel: String
    let birthdate: BirthdateData
    let notifications: Bool
    let coach: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case gender
        case desiredWeight = "desired_weight"
        case heightWeight = "height_weight"
        case goal
        case goalSpeed = "goal_speed"
        case activityLevel = "activity_level"
        case birthdate
        case notifications
        case coach
    }
}

struct HeightWeightData: Codable {
    let weight: MeasurementData
    let height: MeasurementData
}

struct MeasurementData: Codable {
    let value: Double
    let unit: String
}

struct BirthdateData: Codable {
    let birthdate: String
}

// MARK: - Response Models

struct GoalsGenerationResponse: Codable {
    let ok: Bool
    let goals: GoalsData?
    let error: String?
    
    // Make decoding more flexible - try to decode even if some fields are missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = try container.decode(Bool.self, forKey: .ok)
        goals = try? container.decodeIfPresent(GoalsData.self, forKey: .goals)
        error = try? container.decodeIfPresent(String.self, forKey: .error)
    }
    
    enum CodingKeys: String, CodingKey {
        case ok
        case goals
        case error
    }
    
    struct GoalsData: Codable {
        let dailyCalories: Int
        let macros: MacrosData
        let bmi: Double?
        let bmr: Double?
        let tdee: Double?
        let calorieAdjustment: Double?
        let timeToGoalWeeks: Int?
        let notes: String?
        
        // Make decoding more flexible
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Try to decode daily_calories as Int or Double
            if let caloriesInt = try? container.decode(Int.self, forKey: .dailyCalories) {
                dailyCalories = caloriesInt
            } else if let caloriesDouble = try? container.decode(Double.self, forKey: .dailyCalories) {
                dailyCalories = Int(caloriesDouble)
            } else {
                throw DecodingError.keyNotFound(CodingKeys.dailyCalories, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "daily_calories is required"))
            }
            
            macros = try container.decode(MacrosData.self, forKey: .macros)
            bmi = try? container.decodeIfPresent(Double.self, forKey: .bmi)
            bmr = try? container.decodeIfPresent(Double.self, forKey: .bmr)
            tdee = try? container.decodeIfPresent(Double.self, forKey: .tdee)
            calorieAdjustment = try? container.decodeIfPresent(Double.self, forKey: .calorieAdjustment)
            timeToGoalWeeks = try? container.decodeIfPresent(Int.self, forKey: .timeToGoalWeeks)
            notes = try? container.decodeIfPresent(String.self, forKey: .notes)
        }
        
        enum CodingKeys: String, CodingKey {
            case dailyCalories = "daily_calories"
            case macros
            case bmi
            case bmr
            case tdee
            case calorieAdjustment = "calorie_adjustment"
            case timeToGoalWeeks = "time_to_goal_weeks"
            case notes
        }
    }
    
    struct MacrosData: Codable {
        let proteinG: Double
        let carbsG: Double
        let fatG: Double
        let fiberG: Double?
        
        // Make decoding more flexible - handle Int or Double
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Try Int first, then Double
            if let proteinInt = try? container.decode(Int.self, forKey: .proteinG) {
                proteinG = Double(proteinInt)
            } else {
                proteinG = try container.decode(Double.self, forKey: .proteinG)
            }
            
            if let carbsInt = try? container.decode(Int.self, forKey: .carbsG) {
                carbsG = Double(carbsInt)
            } else {
                carbsG = try container.decode(Double.self, forKey: .carbsG)
            }
            
            if let fatInt = try? container.decode(Int.self, forKey: .fatG) {
                fatG = Double(fatInt)
            } else {
                fatG = try container.decode(Double.self, forKey: .fatG)
            }
            
            fiberG = try? container.decodeIfPresent(Double.self, forKey: .fiberG)
        }
        
        enum CodingKeys: String, CodingKey {
            case proteinG = "protein_g"
            case carbsG = "carbs_g"
            case fatG = "fat_g"
            case fiberG = "fiber_g"
        }
    }
}

// MARK: - Service

final class GoalsGenerationService {
    static let shared = GoalsGenerationService()
    
    private let session: URLSession
    private let authManager: AuthenticationManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private static let endpoint = "/calories/goals"
    private static let requestTimeoutInterval: TimeInterval = 20
    private static let resourceTimeoutInterval: TimeInterval = 40
    
    init(
        session: URLSession? = nil,
        authManager: AuthenticationManager = .shared
    ) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Self.requestTimeoutInterval
        configuration.timeoutIntervalForResource = Self.resourceTimeoutInterval
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = session ?? URLSession(configuration: configuration)
        self.authManager = authManager
        
        encoder.keyEncodingStrategy = .convertToSnakeCase
        // Use default keys since we handle snake_case manually in CodingKeys
        decoder.keyDecodingStrategy = .useDefaultKeys
    }
    
    func generateGoals(from onboardingData: [String: Any]) async throws -> GoalsResult {
        print("🔵 [GoalsGenerationService] ===== Starting goals generation ======")
        
        guard let userId = authManager.userId else {
            throw GoalsGenerationError.missingUserId
        }
        
        guard let jwtToken = authManager.jwtToken else {
            throw GoalsGenerationError.missingJWTToken
        }
        
        print("🔵 [GoalsGenerationService] User ID: \(userId)")
        
        let request = try buildRequest(
            onboardingData: onboardingData,
            userId: userId,
            jwtToken: jwtToken
        )
        
        print("🔵 [GoalsGenerationService] Request built successfully")
        let response = try await performRequest(request)
        
        guard let goals = response.goals else {
            throw GoalsGenerationError.invalidResponse
        }
        
        print("✅ [GoalsGenerationService] Goals generated successfully")
        print("   - Calories: \(goals.dailyCalories)")
        print("   - Protein: \(goals.macros.proteinG)g")
        
        return GoalsResult(
            calories: goals.dailyCalories,
            proteinG: goals.macros.proteinG,
            carbsG: goals.macros.carbsG,
            fatG: goals.macros.fatG
        )
    }
    
    // MARK: - Private Helpers
    
    private func buildRequest(
        onboardingData: [String: Any],
        userId: String,
        jwtToken: String
    ) throws -> URLRequest {
        // Extract and map data from onboarding answers (same logic as JavaScript)
        let gender = (onboardingData["gender"] as? [String: Any])?["value"] as? String ?? "male"
        let genderLower = gender.lowercased()
        
        // Height and weight
        let hw = onboardingData["height_weight"] as? [String: Any] ?? [:]
        let weightValue = (hw["weight"] as? Double) ?? (hw["weight"] as? String).flatMap(Double.init) ?? 70.0
        let weightUnit = (hw["weight__unit"] as? String)?.lowercased() ?? "kg"
        let weightUnitApi = weightUnit == "lb" ? "lbs" : "kg"
        
        let heightValue = (hw["height"] as? Double) ?? (hw["height"] as? String).flatMap(Double.init) ?? 170.0
        let heightUnit = (hw["height__unit"] as? String)?.lowercased() ?? "cm"
        let heightUnitApi = heightUnit == "ft" ? "in" : "cm"
        let heightValueApi = heightUnit == "ft" ? heightValue * 12.0 : heightValue
        
        // Desired weight
        let dw = onboardingData["desired_weight"] as? [String: Any] ?? [:]
        let desiredWeightKg = (dw["value"] as? Double) ?? (dw["value"] as? String).flatMap(Double.init) ?? weightValue
        var desiredWeightApi = desiredWeightKg
        if weightUnit == "lb" {
            desiredWeightApi = desiredWeightKg * 2.2046226218
        }
        desiredWeightApi = round(desiredWeightApi * 10) / 10
        
        // Goal
        let goalValue = (onboardingData["goal"] as? [String: Any])?["value"] as? String ?? "maintain"
        let goalApi: String
        switch goalValue.lowercased() {
        case "lose_weight", "lose":
            goalApi = "Lose"
        case "gain_weight", "gain":
            goalApi = "Gain"
        default:
            goalApi = "Maintain"
        }
        
        // Goal speed
        let goalSpeedValue = (onboardingData["goal_speed"] as? [String: Any])?["value"] as? Double ?? 0.5
        let goalSpeedApi: Int
        if goalSpeedValue <= 0.3 {
            goalSpeedApi = 1
        } else if goalSpeedValue <= 0.6 {
            goalSpeedApi = 2
        } else if goalSpeedValue <= 0.8 {
            goalSpeedApi = 3
        } else {
            goalSpeedApi = 4
        }
        
        // Activity level
        let activityValue = (onboardingData["activity_level"] as? [String: Any])?["value"] as? String ?? "moderately_active"
        let activityApi = activityValue == "extra_active" ? "extremely_active" : activityValue
        
        // Birthdate - parse and format to ISO8601
        let birthdateStr = (onboardingData["birthdate"] as? [String: Any])?["birthdate"] as? String
        let birthIso: String
        if let bd = birthdateStr, !bd.isEmpty {
            // Try ISO8601 with fractional seconds first
            let formatterWithFractional = ISO8601DateFormatter()
            formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Try ISO8601 without fractional seconds
            let formatterStandard = ISO8601DateFormatter()
            formatterStandard.formatOptions = [.withInternetDateTime]
            
            // Try YYYY-MM-DD format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let date = formatterWithFractional.date(from: bd) 
                ?? formatterStandard.date(from: bd)
                ?? dateFormatter.date(from: bd) {
                birthIso = ISO8601DateFormatter().string(from: date)
            } else {
                // Fallback to current date if parsing fails
                print("⚠️ [GoalsGenerationService] Failed to parse birthdate '\(bd)', using current date")
                birthIso = ISO8601DateFormatter().string(from: Date())
            }
        } else {
            // Fallback to current date if missing
            print("⚠️ [GoalsGenerationService] Birthdate missing, using current date")
            birthIso = ISO8601DateFormatter().string(from: Date())
        }
        
        // Coach
        let coachValue = (onboardingData["coach"] as? [String: Any])?["value"] as? String ?? "no"
        let coachApi = coachValue.lowercased() == "yes" ? "Yes" : "No"
        
        // Build request
        let requestBody = GoalsGenerationRequest(
            userId: userId,
            gender: genderLower,
            desiredWeight: desiredWeightApi,
            heightWeight: HeightWeightData(
                weight: MeasurementData(value: weightValue, unit: weightUnitApi),
                height: MeasurementData(value: heightValueApi, unit: heightUnitApi)
            ),
            goal: goalApi,
            goalSpeed: goalSpeedApi,
            activityLevel: activityApi,
            birthdate: BirthdateData(birthdate: birthIso),
            notifications: false,
            coach: coachApi
        )
        
        let baseURL = Config.baseURL.absoluteString
        var urlComponents = URLComponents(string: "\(baseURL)\(Self.endpoint)")
        urlComponents?.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        
        guard let url = urlComponents?.url else {
            throw GoalsGenerationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = Self.requestTimeoutInterval
        
        request.httpBody = try encoder.encode(requestBody)
        
        return request
    }
    
    private func performRequest(_ request: URLRequest) async throws -> GoalsGenerationResponse {
        print("🔵 [GoalsGenerationService] Sending POST request...")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🟢 [GoalsGenerationService] Status code: \(httpResponse.statusCode)")
            print("🟢 [GoalsGenerationService] Response headers: \(httpResponse.allHeaderFields)")
        }
        
        // Log raw response for debugging (limited to first 500 chars to avoid spam)
        if let responseString = String(data: data, encoding: .utf8) {
            let preview = String(responseString.prefix(500))
            print("🟢 [GoalsGenerationService] Response data preview (first 500 chars): \(preview)")
            if responseString.count > 500 {
                print("🟢 [GoalsGenerationService] ... (truncated, total: \(responseString.count) chars)")
            }
        } else {
            print("⚠️ [GoalsGenerationService] Response data is not valid UTF-8, size: \(data.count) bytes")
        }
        
        // Try to decode
        do {
            let decoded = try decoder.decode(GoalsGenerationResponse.self, from: data)
            
            if !decoded.ok {
                let errorMsg = decoded.error ?? "Unknown error"
                print("🔴 [GoalsGenerationService] API returned error: \(errorMsg)")
                throw GoalsGenerationError.apiError(errorMsg)
            }
            
            guard decoded.goals != nil else {
                print("🔴 [GoalsGenerationService] Response missing goals field")
                throw GoalsGenerationError.invalidResponse
            }
            
            return decoded
        } catch let decodingError as DecodingError {
            print("🔴 [GoalsGenerationService] Decoding error: \(decodingError)")
            print("🔴 [GoalsGenerationService] Decoding error details:")
            switch decodingError {
            case .typeMismatch(let type, let context):
                print("   - Type mismatch: expected \(type), path: \(context.codingPath)")
            case .valueNotFound(let type, let context):
                print("   - Value not found: \(type), path: \(context.codingPath)")
            case .keyNotFound(let key, let context):
                print("   - Key not found: \(key.stringValue), path: \(context.codingPath)")
            case .dataCorrupted(let context):
                print("   - Data corrupted: \(context.debugDescription)")
            @unknown default:
                print("   - Unknown decoding error")
            }
            throw GoalsGenerationError.invalidResponse
        } catch {
            print("🔴 [GoalsGenerationService] Unexpected error: \(error)")
            throw error
        }
    }
}

// MARK: - Errors

enum GoalsGenerationError: LocalizedError {
    case missingUserId
    case missingJWTToken
    case invalidURL
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingUserId:
            return "User ID is not available"
        case .missingJWTToken:
            return "JWT token is not available"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return message
        }
    }
}

