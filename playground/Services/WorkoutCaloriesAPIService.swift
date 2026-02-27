//
//  WorkoutCaloriesAPIService.swift
//  playground
//
//  API service for calculating calories burned from workouts
//

import Foundation

// MARK: - Request Models

struct WeightInfo: Codable {
    let value: Double
    let unit: String  // "kg" or "lbs"
}

struct HeightInfo: Codable {
    let value: Double
    let unit: String  // "cm" or "in"
}

struct WorkoutRequest: Codable {
    let type: String
    let duration_minutes: Int
    let intensity: String
}

struct WorkoutCaloriesRequestBody: Codable {
    let user_id: String
    let gender: String
    let age: Int
    let weight: WeightInfo
    let height: HeightInfo
    let workouts: [WorkoutRequest]
}

// MARK: - Response Models

struct WorkoutCaloriesResponse: Codable {
    let ok: Bool
    let calories_burned: CaloriesBurned?
    let error: String?
    
    struct CaloriesBurned: Codable {
        let total_calories: Int
        let workouts: [WorkoutResult]
        let notes: String
    }
    
    struct WorkoutResult: Codable {
        let type: String
        let duration_minutes: Int
        let intensity: String
        let calories_burned: Int
        let met_value: Double
    }
}

// MARK: - Workout Calories API Error

enum WorkoutCaloriesAPIError: LocalizedError {
    case missingUserData(String)
    
    var errorDescription: String? {
        switch self {
        case .missingUserData(let field):
            return "Missing required user data: \(field). Please complete your profile in settings."
        }
    }
}

// MARK: - Workout Calories API Service

final class WorkoutCaloriesAPIService {
    static let shared = WorkoutCaloriesAPIService()
    
    private let baseURL = "https://app.caloriecount-ai.com"
    private let endpoint = "/calories/workout"
    private let session: URLSession
    private let authManager: AuthenticationManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init(
        session: URLSession? = nil,
        authManager: AuthenticationManager = .shared
    ) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = session ?? URLSession(configuration: configuration)
        self.authManager = authManager
    }
    
    /// Calculate calories burned for a workout
    /// - Parameters:
    ///   - workoutType: Type of workout (e.g., "running", "weightlifting", "cycling")
    ///   - durationMinutes: Duration in minutes
    ///   - intensity: Intensity level ("low", "moderate", "high", "vigorous")
    /// - Returns: Calories burned, or nil if calculation fails
    func calculateCalories(
        workoutType: String,
        durationMinutes: Int,
        intensity: String = "moderate"
    ) async throws -> Int? {
        try AIConsentManager.shared.requireConsent()
        
        guard let userId = authManager.userId,
              let jwtToken = authManager.jwtToken else {
            AppLogger.forClass("WorkoutCaloriesAPIService").warning("Missing credentials for workout calories API")
            return nil
        }
        
        let settings = UserSettings.shared
        
        // Check gender with detailed logging
        let genderValue = settings.gender
        print("🔍 [WorkoutCaloriesAPIService] Checking gender - settings.gender: '\(genderValue ?? "nil")'")
        
        // Also check UserDefaults directly to verify
        let genderFromDefaults = UserDefaults.standard.string(forKey: "gender")
        print("🔍 [WorkoutCaloriesAPIService] Gender from UserDefaults: '\(genderFromDefaults ?? "nil")'")
        
        // Validate required user data - return nil if missing (caller will show error)
        guard let gender = genderValue?.lowercased(),
              gender == "male" || gender == "female" else {
            AppLogger.forClass("WorkoutCaloriesAPIService").warning("Missing or invalid gender in UserSettings")
            print("❌ [WorkoutCaloriesAPIService] Gender validation failed - value: '\(genderValue ?? "nil")', fromDefaults: '\(genderFromDefaults ?? "nil")'")
            throw WorkoutCaloriesAPIError.missingUserData("gender")
        }
        
        print("✅ [WorkoutCaloriesAPIService] Gender validated: '\(gender)'")
        
        // Check age - if missing, try to calculate from birthdate
        var age: Int?
        if let storedAge = settings.age, storedAge > 0, storedAge <= 120 {
            age = storedAge
            print("✅ [WorkoutCaloriesAPIService] Using stored age: \(storedAge)")
        } else if let birthdate = settings.birthdate {
            // Try to calculate age from birthdate
            let calendar = Calendar.current
            let ageComponents = calendar.dateComponents([.year], from: birthdate, to: Date())
            if let calculatedAge = ageComponents.year, calculatedAge > 0, calculatedAge <= 120 {
                age = calculatedAge
                // Save the calculated age back to settings
                settings.age = calculatedAge
                print("✅ [WorkoutCaloriesAPIService] Calculated age from birthdate: \(calculatedAge) years")
            } else {
                print("❌ [WorkoutCaloriesAPIService] Could not calculate valid age from birthdate: \(birthdate)")
            }
        }
        
        guard let validAge = age, validAge > 0, validAge <= 120 else {
            AppLogger.forClass("WorkoutCaloriesAPIService").warning("Missing or invalid age in UserSettings")
            print("❌ [WorkoutCaloriesAPIService] Age validation failed - age: '\(age?.description ?? "nil")', birthdate: '\(settings.birthdate?.description ?? "nil")'")
            throw WorkoutCaloriesAPIError.missingUserData("age")
        }
        
        print("✅ [WorkoutCaloriesAPIService] Age validated: \(validAge) years")
        
        guard settings.currentWeight > 0 else {
            AppLogger.forClass("WorkoutCaloriesAPIService").warning("Missing weight in UserSettings")
            throw WorkoutCaloriesAPIError.missingUserData("weight")
        }
        
        guard settings.height > 0 else {
            AppLogger.forClass("WorkoutCaloriesAPIService").warning("Missing height in UserSettings")
            throw WorkoutCaloriesAPIError.missingUserData("height")
        }
        
        // Build request
        let weightInfo = WeightInfo(
            value: settings.useMetricUnits ? settings.currentWeight : settings.currentWeight * 2.20462,
            unit: settings.useMetricUnits ? "kg" : "lbs"
        )
        
        let heightInfo = HeightInfo(
            value: settings.useMetricUnits ? settings.height : settings.height / 2.54,
            unit: settings.useMetricUnits ? "cm" : "in"
        )
        
        let workout = WorkoutRequest(
            type: workoutType,
            duration_minutes: durationMinutes,
            intensity: intensity
        )
        
        let requestBody = WorkoutCaloriesRequestBody(
            user_id: userId,
            gender: gender,
            age: validAge,
            weight: weightInfo,
            height: heightInfo,
            workouts: [workout]
        )
        
        // Build URL with query parameter
        guard var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)") else {
            throw NSError(domain: "WorkoutCaloriesAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        urlComponents.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        
        guard let url = urlComponents.url else {
            throw NSError(domain: "WorkoutCaloriesAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try encoder.encode(requestBody)
        } catch {
            AppLogger.forClass("WorkoutCaloriesAPIService").error("Failed to encode request body", error: error)
            throw error
        }
        
        AppLogger.forClass("WorkoutCaloriesAPIService").info("Requesting calories for workout: \(workoutType), \(durationMinutes) min, \(intensity)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "WorkoutCaloriesAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                AppLogger.forClass("WorkoutCaloriesAPIService").error("API returned status \(httpResponse.statusCode): \(errorMessage)")
                return nil
            }
            
            let result = try decoder.decode(WorkoutCaloriesResponse.self, from: data)
            
            if result.ok, let caloriesBurned = result.calories_burned,
               let firstWorkout = caloriesBurned.workouts.first {
                AppLogger.forClass("WorkoutCaloriesAPIService").success("Calculated \(firstWorkout.calories_burned) calories for \(workoutType)")
                return firstWorkout.calories_burned
            } else {
                AppLogger.forClass("WorkoutCaloriesAPIService").warning("API returned ok=false: \(result.error ?? "Unknown error")")
                return nil
            }
        } catch {
            AppLogger.forClass("WorkoutCaloriesAPIService").error("Failed to calculate workout calories", error: error)
            throw error
        }
    }
}


