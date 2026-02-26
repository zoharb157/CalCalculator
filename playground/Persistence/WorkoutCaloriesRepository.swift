//
//  WorkoutCaloriesRepository.swift
//  playground
//
//  Repository for calculating calories burned from workouts using the Calories Workout API.
//  Personalized to the user's physical characteristics.
//

import Foundation

// MARK: - Protocol

/// Protocol for workout calories calculation operations
protocol WorkoutCaloriesRepositoryProtocol {
    /// Calculate calories burned for a single workout
    func calculateCalories(
        workout: WorkoutInput,
        userProfile: WorkoutUserProfile
    ) async throws -> WorkoutCaloriesResult
    
    /// Calculate calories burned for multiple workouts
    func calculateCalories(
        workouts: [WorkoutInput],
        userProfile: WorkoutUserProfile
    ) async throws -> BulkWorkoutCaloriesResult
    
    /// Calculate calories using user settings from the app
    func calculateCalories(
        workout: WorkoutInput
    ) async throws -> WorkoutCaloriesResult
    
    /// Calculate calories for multiple workouts using user settings
    func calculateCalories(
        workouts: [WorkoutInput]
    ) async throws -> BulkWorkoutCaloriesResult
}

// MARK: - Input Models

/// User profile data required for personalized calorie calculations
struct WorkoutUserProfile {
    let userId: String
    let gender: Gender
    let age: Int
    let weight: WeightMeasurement
    let height: HeightMeasurement
    
    enum Gender: String, Codable {
        case male
        case female
    }
    
    struct WeightMeasurement {
        let value: Double
        let unit: WeightUnit
        
        enum WeightUnit: String, Codable {
            case kg
            case lbs
        }
    }
    
    struct HeightMeasurement {
        let value: Double
        let unit: HeightUnit
        
        enum HeightUnit: String, Codable {
            case cm
            case `in` = "in"
        }
    }
}

/// Input data for a single workout
struct WorkoutInput {
    let type: WorkoutType
    let durationMinutes: Int
    let intensity: Intensity
    
    /// Predefined workout types with optimized MET values
    enum WorkoutType: String, CaseIterable {
        case walking
        case running
        case cycling
        case swimming
        case weightlifting
        case hiit = "HIIT"
        case yoga
        case dancing
        case basketball
        case soccer
        case tennis
        case custom
        
        /// Custom workout type with user-provided name
        var apiValue: String {
            return rawValue
        }
    }
    
    /// Intensity levels for workouts
    enum Intensity: String, Codable, CaseIterable {
        case low
        case moderate
        case high
        case vigorous
        
        var description: String {
            switch self {
            case .low:
                return "Light effort, easy to maintain conversation"
            case .moderate:
                return "Some effort, can speak in short sentences"
            case .high:
                return "Hard effort, difficult to speak"
            case .vigorous:
                return "Maximum effort, cannot speak"
            }
        }
    }
    
    /// Initialize with predefined workout type
    init(type: WorkoutType, durationMinutes: Int, intensity: Intensity = .moderate) {
        self.type = type
        self.durationMinutes = durationMinutes
        self.intensity = intensity
    }
    
    /// Initialize with custom workout type name
    static func custom(name: String, durationMinutes: Int, intensity: Intensity = .moderate) -> WorkoutInput {
        return WorkoutInput(type: .custom, durationMinutes: durationMinutes, intensity: intensity)
    }
}

// MARK: - Result Models

/// Result for a single workout calorie calculation
struct WorkoutCaloriesResult {
    let type: String
    let durationMinutes: Int
    let intensity: String
    let caloriesBurned: Int
    let metValue: Double
}

/// Result for bulk workout calorie calculations
struct BulkWorkoutCaloriesResult {
    let totalCalories: Int
    let workouts: [WorkoutCaloriesResult]
    let notes: String
}

// MARK: - Error Types

enum WorkoutCaloriesError: LocalizedError {
    case missingUserId
    case missingJWTToken
    case missingUserData(String)
    case invalidGender
    case invalidAge
    case invalidWeight
    case invalidHeight
    case invalidWorkouts
    case invalidWorkoutType(index: Int)
    case invalidDuration(index: Int)
    case invalidIntensity(index: Int)
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case serverError(String)
    case authenticationFailed
    case encodingError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingUserId:
            return "Missing required parameter: user_id"
        case .missingJWTToken:
            return "JWT token verification failed"
        case .missingUserData(let field):
            return "Missing required user data: \(field). Please complete your profile in settings."
        case .invalidGender:
            return "Missing or invalid required parameter: gender (must be 'male' or 'female')"
        case .invalidAge:
            return "Missing or invalid required parameter: age (must be a positive number between 1 and 120)"
        case .invalidWeight:
            return "Missing or invalid required parameter: weight (must include value as a positive number)"
        case .invalidHeight:
            return "Missing or invalid required parameter: height (must include value as a positive number)"
        case .invalidWorkouts:
            return "Missing or invalid required parameter: workouts (must be a non-empty array)"
        case .invalidWorkoutType(let index):
            return "Missing required field 'type' in workout at index \(index)"
        case .invalidDuration(let index):
            return "Missing or invalid 'duration_minutes' in workout at index \(index): must be a positive number"
        case .invalidIntensity(let index):
            return "Invalid 'intensity' in workout at index \(index): must be one of low, moderate, high, vigorous"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .authenticationFailed:
            return "JWT token verification failed"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

// MARK: - API Request/Response Models (Internal)

private struct WorkoutCaloriesAPIRequest: Codable {
    let user_id: String
    let gender: String
    let age: Int
    let weight: WeightData
    let height: HeightData
    let workouts: [WorkoutData]
    
    struct WeightData: Codable {
        let value: Double
        let unit: String
    }
    
    struct HeightData: Codable {
        let value: Double
        let unit: String
    }
    
    struct WorkoutData: Codable {
        let type: String
        let duration_minutes: Int
        let intensity: String
    }
}

private struct WorkoutCaloriesAPIResponse: Codable {
    let ok: Bool
    let calories_burned: CaloriesBurnedData?
    let error: String?
    
    struct CaloriesBurnedData: Codable {
        let total_calories: Int
        let workouts: [WorkoutResultData]
        let notes: String
    }
    
    struct WorkoutResultData: Codable {
        let type: String
        let duration_minutes: Int
        let intensity: String
        let calories_burned: Int
        let met_value: Double
    }
}

// MARK: - Configuration

private enum WorkoutAPIConfiguration {
    static let baseURL = "https://app.caloriecount-ai.com"
    static let endpoint = "/calories/workout"
    static let requestTimeoutInterval: TimeInterval = 30
    static let resourceTimeoutInterval: TimeInterval = 60
}

// MARK: - Repository Implementation

final class WorkoutCaloriesRepository: WorkoutCaloriesRepositoryProtocol {
    
    // MARK: - Singleton
    
    static let shared = WorkoutCaloriesRepository()
    
    // MARK: - Properties
    
    private let session: URLSession
    private let authManager: AuthenticationManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    init(
        session: URLSession? = nil,
        authManager: AuthenticationManager = .shared
    ) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = WorkoutAPIConfiguration.requestTimeoutInterval
        configuration.timeoutIntervalForResource = WorkoutAPIConfiguration.resourceTimeoutInterval
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = session ?? URLSession(configuration: configuration)
        self.authManager = authManager
    }
    
    // MARK: - Public Methods
    
    /// Calculate calories burned for a single workout with explicit user profile
    func calculateCalories(
        workout: WorkoutInput,
        userProfile: WorkoutUserProfile
    ) async throws -> WorkoutCaloriesResult {
        let result = try await calculateCalories(workouts: [workout], userProfile: userProfile)
        guard let firstWorkout = result.workouts.first else {
            throw WorkoutCaloriesError.invalidResponse
        }
        return firstWorkout
    }
    
    /// Calculate calories burned for multiple workouts with explicit user profile
    func calculateCalories(
        workouts: [WorkoutInput],
        userProfile: WorkoutUserProfile
    ) async throws -> BulkWorkoutCaloriesResult {
        try AIConsentManager.shared.requireConsent()
        
        print("🔵 [WorkoutCaloriesRepository] ===== Starting workout calories calculation =====")
        
        // Validate inputs
        try validateUserProfile(userProfile)
        try validateWorkouts(workouts)
        
        // Get JWT token
        guard let jwtToken = authManager.jwtToken else {
            throw WorkoutCaloriesError.missingJWTToken
        }
        
        // Build and execute request
        let request = try buildRequest(
            workouts: workouts,
            userProfile: userProfile,
            jwtToken: jwtToken
        )
        
        return try await performRequest(request)
    }
    
    /// Calculate calories burned for a single workout using app's user settings
    func calculateCalories(
        workout: WorkoutInput
    ) async throws -> WorkoutCaloriesResult {
        let userProfile = try getUserProfileFromSettings()
        return try await calculateCalories(workout: workout, userProfile: userProfile)
    }
    
    /// Calculate calories burned for multiple workouts using app's user settings
    func calculateCalories(
        workouts: [WorkoutInput]
    ) async throws -> BulkWorkoutCaloriesResult {
        let userProfile = try getUserProfileFromSettings()
        return try await calculateCalories(workouts: workouts, userProfile: userProfile)
    }
    
    // MARK: - Convenience Methods
    
    /// Quick calculation for running
    func calculateRunningCalories(
        durationMinutes: Int,
        intensity: WorkoutInput.Intensity = .moderate
    ) async throws -> Int {
        let workout = WorkoutInput(type: .running, durationMinutes: durationMinutes, intensity: intensity)
        let result = try await calculateCalories(workout: workout)
        return result.caloriesBurned
    }
    
    /// Quick calculation for walking
    func calculateWalkingCalories(
        durationMinutes: Int,
        intensity: WorkoutInput.Intensity = .low
    ) async throws -> Int {
        let workout = WorkoutInput(type: .walking, durationMinutes: durationMinutes, intensity: intensity)
        let result = try await calculateCalories(workout: workout)
        return result.caloriesBurned
    }
    
    /// Quick calculation for cycling
    func calculateCyclingCalories(
        durationMinutes: Int,
        intensity: WorkoutInput.Intensity = .moderate
    ) async throws -> Int {
        let workout = WorkoutInput(type: .cycling, durationMinutes: durationMinutes, intensity: intensity)
        let result = try await calculateCalories(workout: workout)
        return result.caloriesBurned
    }
    
    /// Quick calculation for weightlifting
    func calculateWeightliftingCalories(
        durationMinutes: Int,
        intensity: WorkoutInput.Intensity = .moderate
    ) async throws -> Int {
        let workout = WorkoutInput(type: .weightlifting, durationMinutes: durationMinutes, intensity: intensity)
        let result = try await calculateCalories(workout: workout)
        return result.caloriesBurned
    }
    
    /// Quick calculation for HIIT
    func calculateHIITCalories(
        durationMinutes: Int,
        intensity: WorkoutInput.Intensity = .high
    ) async throws -> Int {
        let workout = WorkoutInput(type: .hiit, durationMinutes: durationMinutes, intensity: intensity)
        let result = try await calculateCalories(workout: workout)
        return result.caloriesBurned
    }
    
    /// Quick calculation for swimming
    func calculateSwimmingCalories(
        durationMinutes: Int,
        intensity: WorkoutInput.Intensity = .moderate
    ) async throws -> Int {
        let workout = WorkoutInput(type: .swimming, durationMinutes: durationMinutes, intensity: intensity)
        let result = try await calculateCalories(workout: workout)
        return result.caloriesBurned
    }
    
    /// Quick calculation for yoga
    func calculateYogaCalories(
        durationMinutes: Int,
        intensity: WorkoutInput.Intensity = .low
    ) async throws -> Int {
        let workout = WorkoutInput(type: .yoga, durationMinutes: durationMinutes, intensity: intensity)
        let result = try await calculateCalories(workout: workout)
        return result.caloriesBurned
    }
    
    /// Calculate calories for a custom workout type
    func calculateCustomWorkoutCalories(
        workoutType: String,
        durationMinutes: Int,
        intensity: WorkoutInput.Intensity = .moderate
    ) async throws -> Int {
        let userProfile = try getUserProfileFromSettings()
        
        guard let userId = authManager.userId else {
            throw WorkoutCaloriesError.missingUserId
        }
        
        guard let jwtToken = authManager.jwtToken else {
            throw WorkoutCaloriesError.missingJWTToken
        }
        
        let requestBody = WorkoutCaloriesAPIRequest(
            user_id: userId,
            gender: userProfile.gender.rawValue,
            age: userProfile.age,
            weight: WorkoutCaloriesAPIRequest.WeightData(
                value: userProfile.weight.value,
                unit: userProfile.weight.unit.rawValue
            ),
            height: WorkoutCaloriesAPIRequest.HeightData(
                value: userProfile.height.value,
                unit: userProfile.height.unit.rawValue
            ),
            workouts: [
                WorkoutCaloriesAPIRequest.WorkoutData(
                    type: workoutType,
                    duration_minutes: durationMinutes,
                    intensity: intensity.rawValue
                )
            ]
        )
        
        let request = try buildURLRequest(
            userId: userId,
            jwtToken: jwtToken,
            body: requestBody
        )
        
        let result = try await performRequest(request)
        return result.totalCalories
    }
    
    // MARK: - Private Helpers
    
    private func getUserProfileFromSettings() throws -> WorkoutUserProfile {
        guard let userId = authManager.userId else {
            throw WorkoutCaloriesError.missingUserId
        }
        
        let settings = UserSettings.shared
        
        // Validate and get gender
        guard let genderString = settings.gender?.lowercased(),
              let gender = WorkoutUserProfile.Gender(rawValue: genderString) else {
            print("❌ [WorkoutCaloriesRepository] Invalid gender: \(settings.gender ?? "nil")")
            throw WorkoutCaloriesError.missingUserData("gender")
        }
        
        // Validate and get age
        var age: Int?
        if let storedAge = settings.age, storedAge > 0, storedAge <= 120 {
            age = storedAge
        } else if let birthdate = settings.birthdate {
            let calendar = Calendar.current
            let ageComponents = calendar.dateComponents([.year], from: birthdate, to: Date())
            if let calculatedAge = ageComponents.year, calculatedAge > 0, calculatedAge <= 120 {
                age = calculatedAge
            }
        }
        
        guard let validAge = age else {
            print("❌ [WorkoutCaloriesRepository] Invalid age")
            throw WorkoutCaloriesError.missingUserData("age")
        }
        
        // Validate weight
        guard settings.currentWeight > 0 else {
            print("❌ [WorkoutCaloriesRepository] Invalid weight")
            throw WorkoutCaloriesError.missingUserData("weight")
        }
        
        // Validate height
        guard settings.height > 0 else {
            print("❌ [WorkoutCaloriesRepository] Invalid height")
            throw WorkoutCaloriesError.missingUserData("height")
        }
        
        // Build weight measurement
        let weightUnit: WorkoutUserProfile.WeightMeasurement.WeightUnit = settings.useMetricUnits ? .kg : .lbs
        let weightValue = settings.useMetricUnits ? settings.currentWeight : settings.currentWeight * 2.20462
        
        // Build height measurement
        let heightUnit: WorkoutUserProfile.HeightMeasurement.HeightUnit = settings.useMetricUnits ? .cm : .in
        let heightValue = settings.useMetricUnits ? settings.height : settings.height / 2.54
        
        return WorkoutUserProfile(
            userId: userId,
            gender: gender,
            age: validAge,
            weight: WorkoutUserProfile.WeightMeasurement(value: weightValue, unit: weightUnit),
            height: WorkoutUserProfile.HeightMeasurement(value: heightValue, unit: heightUnit)
        )
    }
    
    private func validateUserProfile(_ profile: WorkoutUserProfile) throws {
        // Validate age
        guard profile.age > 0, profile.age <= 120 else {
            throw WorkoutCaloriesError.invalidAge
        }
        
        // Validate weight
        guard profile.weight.value > 0 else {
            throw WorkoutCaloriesError.invalidWeight
        }
        
        // Validate height
        guard profile.height.value > 0 else {
            throw WorkoutCaloriesError.invalidHeight
        }
    }
    
    private func validateWorkouts(_ workouts: [WorkoutInput]) throws {
        guard !workouts.isEmpty else {
            throw WorkoutCaloriesError.invalidWorkouts
        }
        
        for (index, workout) in workouts.enumerated() {
            guard workout.durationMinutes > 0 else {
                throw WorkoutCaloriesError.invalidDuration(index: index)
            }
        }
    }
    
    private func buildRequest(
        workouts: [WorkoutInput],
        userProfile: WorkoutUserProfile,
        jwtToken: String
    ) throws -> URLRequest {
        let workoutData = workouts.map { workout in
            WorkoutCaloriesAPIRequest.WorkoutData(
                type: workout.type.apiValue,
                duration_minutes: workout.durationMinutes,
                intensity: workout.intensity.rawValue
            )
        }
        
        let requestBody = WorkoutCaloriesAPIRequest(
            user_id: userProfile.userId,
            gender: userProfile.gender.rawValue,
            age: userProfile.age,
            weight: WorkoutCaloriesAPIRequest.WeightData(
                value: userProfile.weight.value,
                unit: userProfile.weight.unit.rawValue
            ),
            height: WorkoutCaloriesAPIRequest.HeightData(
                value: userProfile.height.value,
                unit: userProfile.height.unit.rawValue
            ),
            workouts: workoutData
        )
        
        return try buildURLRequest(
            userId: userProfile.userId,
            jwtToken: jwtToken,
            body: requestBody
        )
    }
    
    private func buildURLRequest(
        userId: String,
        jwtToken: String,
        body: WorkoutCaloriesAPIRequest
    ) throws -> URLRequest {
        var urlComponents = URLComponents(
            string: "\(WorkoutAPIConfiguration.baseURL)\(WorkoutAPIConfiguration.endpoint)"
        )
        urlComponents?.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        
        guard let url = urlComponents?.url else {
            throw WorkoutCaloriesError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = WorkoutAPIConfiguration.requestTimeoutInterval
        
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw WorkoutCaloriesError.encodingError(error)
        }
        
        print("🔵 [WorkoutCaloriesRepository] Request URL: \(url.absoluteString)")
        print("🔵 [WorkoutCaloriesRepository] Request body size: \(request.httpBody?.count ?? 0) bytes")
        
        return request
    }
    
    private func performRequest(_ request: URLRequest) async throws -> BulkWorkoutCaloriesResult {
        print("🔵 [WorkoutCaloriesRepository] Sending POST request...")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WorkoutCaloriesError.invalidResponse
            }
            
            print("🟢 [WorkoutCaloriesRepository] Status code: \(httpResponse.statusCode)")
            
            // Log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                let preview = String(responseString.prefix(500))
                print("🟢 [WorkoutCaloriesRepository] Response preview: \(preview)")
            }
            
            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                break // Success, continue processing
            case 400:
                let errorResponse = try? decoder.decode(WorkoutCaloriesAPIResponse.self, from: data)
                throw WorkoutCaloriesError.serverError(errorResponse?.error ?? "Bad request")
            case 423:
                throw WorkoutCaloriesError.authenticationFailed
            case 500:
                let errorResponse = try? decoder.decode(WorkoutCaloriesAPIResponse.self, from: data)
                throw WorkoutCaloriesError.serverError(errorResponse?.error ?? "Server error")
            default:
                throw WorkoutCaloriesError.serverError("Unexpected status code: \(httpResponse.statusCode)")
            }
            
            // Decode response
            let apiResponse: WorkoutCaloriesAPIResponse
            do {
                apiResponse = try decoder.decode(WorkoutCaloriesAPIResponse.self, from: data)
            } catch {
                print("🔴 [WorkoutCaloriesRepository] Decoding error: \(error)")
                throw WorkoutCaloriesError.decodingError(error)
            }
            
            // Validate response
            guard apiResponse.ok, let caloriesBurned = apiResponse.calories_burned else {
                let errorMessage = apiResponse.error ?? "Unknown error"
                print("🔴 [WorkoutCaloriesRepository] API error: \(errorMessage)")
                throw WorkoutCaloriesError.serverError(errorMessage)
            }
            
            // Map to result
            let workoutResults = caloriesBurned.workouts.map { workout in
                WorkoutCaloriesResult(
                    type: workout.type,
                    durationMinutes: workout.duration_minutes,
                    intensity: workout.intensity,
                    caloriesBurned: workout.calories_burned,
                    metValue: workout.met_value
                )
            }
            
            print("✅ [WorkoutCaloriesRepository] Total calories: \(caloriesBurned.total_calories)")
            
            return BulkWorkoutCaloriesResult(
                totalCalories: caloriesBurned.total_calories,
                workouts: workoutResults,
                notes: caloriesBurned.notes
            )
            
        } catch let error as WorkoutCaloriesError {
            throw error
        } catch {
            print("🔴 [WorkoutCaloriesRepository] Network error: \(error)")
            throw WorkoutCaloriesError.networkError(error)
        }
    }
}

// MARK: - Preview/Testing Support

#if DEBUG
extension WorkoutCaloriesRepository {
    /// Create a mock repository for testing
    static func mock(
        session: URLSession,
        authManager: AuthenticationManager
    ) -> WorkoutCaloriesRepository {
        return WorkoutCaloriesRepository(session: session, authManager: authManager)
    }
}
#endif
