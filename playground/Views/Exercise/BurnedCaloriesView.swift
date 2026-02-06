//
//  BurnedCaloriesView.swift
//
//  Burned Calories result screen
//

import SwiftUI
import SwiftData
import SDK

struct BurnedCaloriesView: View {
    let calories: Int
    let exerciseType: ExerciseType
    let duration: Int
    let intensity: ExerciseIntensity?
    let notes: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isSubscribed) private var isSubscribed
    @State private var editedCalories: Int
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoadingCalories = true // Track if we're loading calories from API
    @State private var showPaywall = false
    @Environment(TheSDK.self) private var sdk
    @ObservedObject private var localizationManager = LocalizationManager.shared
    private let userSettings = UserSettings.shared
    
    // Weight lifting specific - sets-based
    let reps: Int?
    let sets: Int?
    let weight: Double?
    let exerciseSets: [ExerciseSet]?
    
    // Running specific
    let distance: Double?
    let distanceUnit: DistanceUnit?
    
    // Exercise types that require duration (not weight lifting)
    private var requiresDuration: Bool {
        exerciseType == .run
    }
    
    init(
        calories: Int,
        exerciseType: ExerciseType,
        duration: Int,
        intensity: ExerciseIntensity? = nil,
        notes: String? = nil,
        reps: Int? = nil,
        sets: Int? = nil,
        weight: Double? = nil,
        exerciseSets: [ExerciseSet]? = nil,
        distance: Double? = nil,
        distanceUnit: DistanceUnit? = nil
    ) {
        self.calories = calories
        self.exerciseType = exerciseType
        self.duration = duration
        self.intensity = intensity
        self.notes = notes
        self.reps = reps
        self.sets = sets
        self.weight = weight
        self.exerciseSets = exerciseSets
        self.distance = distance
        self.distanceUnit = distanceUnit
        // If calories is 0, try to calculate from API
        // Otherwise use the provided calories
        let initialCalories = calories > 0 ? calories : 0
        _editedCalories = State(initialValue: initialCalories)
        // Start with loading state if we need to calculate from API
        // For weight lifting or if calories is 0, we'll calculate from API
        _isLoadingCalories = State(initialValue: exerciseType == .weightLifting || calories == 0)
    }
    
    var body: some View {
        NavigationStack {
            if isLoadingCalories {
                // Loading state - show loader while calculating calories
                VStack(spacing: 24) {
                    Spacer()
                    
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.orange)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Common.loading))
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .id("calculating-\(localizationManager.currentLanguage)")
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                // Content view - show once calories are calculated
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Circular Progress with animated flame
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                            .frame(width: 200, height: 200)
                        
                        // Animated progress ring
                        Circle()
                            .trim(from: 0, to: min(Double(editedCalories) / 500.0, 1.0))
                            .stroke(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.8), value: editedCalories)
                        
                        // Flame icon
                        Image(systemName: "flame.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    
                    // Calories Display
                    VStack(spacing: 8) {
                        Text(LocalizationManager.shared.localizedString(for: "Your workout burned"))
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .id("workout-burned-\(LocalizationManager.shared.currentLanguage)")
                        
                        if isEditing {
                            TextField("", value: $editedCalories, format: .number)
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                                .keyboardDoneButton()
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(editedCalories)")
                                    .font(.system(size: 56, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text(LocalizationManager.shared.localizedString(for: "Cals"))
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                    .id("cals-\(LocalizationManager.shared.currentLanguage)")
                                
                                Button {
                                    isEditing = true
                                } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Exercise Summary Card
                    exerciseSummaryCard
                    
                    Spacer()
                    
                    // Save Button
                    Button {
                        Task {
                            await saveExercise()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isSaving ? LocalizationManager.shared.localizedString(for: "Saving...") : LocalizationManager.shared.localizedString(for: AppStrings.Common.save))
                                .id("save-button-\(LocalizationManager.shared.currentLanguage)-\(isSaving)")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: isSaving ? [Color.gray] : [Color.orange, Color.red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .disabled(isSaving)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                    .alert("Error", isPresented: $showError) {
                        Button(localizationManager.localizedString(for: AppStrings.Common.ok)) { }
                    } message: {
                        Text(errorMessage)
                    }
                    .fullScreenCover(isPresented: $showPaywall) {
                        SDKView(
                            model: sdk,
                            page: .splash,
                            show: paywallBinding(showPaywall: $showPaywall, sdk: sdk),
                            backgroundColor: Color(UIColor.systemBackground),
                            ignoreSafeArea: true
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle(LocalizationManager.shared.localizedString(for: "Burned Calories"))
            .id("burned-calories-title-\(LocalizationManager.shared.currentLanguage)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateCaloriesIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                }
            }
        }
    }
    
    // MARK: - Exercise Summary Card
    
    private var exerciseSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: exerciseType.icon)
                    .font(.title2)
                    .foregroundColor(.orange)
                Text(exerciseType.displayName)
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            // Show relevant info based on exercise type
            if exerciseType == .run {
                runSummaryContent
            } else if exerciseType == .weightLifting {
                weightLiftingSummaryContent
            } else {
                basicSummaryContent
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var runSummaryContent: some View {
        VStack(spacing: 8) {
            if let dist = distance, let unit = distanceUnit {
                HStack {
                    Label(localizationManager.localizedString(for: AppStrings.Exercise.distance), systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f %@", dist, unit.displayName))
                        .fontWeight(.medium)
                }
            }
            
            if duration > 0 {
                HStack {
                    Label(localizationManager.localizedString(for: AppStrings.Exercise.duration), systemImage: "clock.fill")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDuration(duration))
                        .fontWeight(.medium)
                }
            }
            
            if let dist = distance, dist > 0, duration > 0 {
                HStack {
                    Label(localizationManager.localizedString(for: AppStrings.Exercise.pace), systemImage: "speedometer")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(calculatePaceString())
                        .fontWeight(.medium)
                }
            }
            
            if let intensity = intensity {
                HStack {
                    Label(localizationManager.localizedString(for: AppStrings.Exercise.intensity), systemImage: "flame.fill")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(intensity.displayName)
                        .fontWeight(.medium)
                }
            }
        }
        .font(.subheadline)
    }
    
    private var weightLiftingSummaryContent: some View {
        VStack(spacing: 8) {
            if let sets = exerciseSets, !sets.isEmpty {
                HStack {
                    Label(localizationManager.localizedString(for: AppStrings.Exercise.sets), systemImage: "list.number")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(sets.count)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Label(localizationManager.localizedString(for: AppStrings.Exercise.totalReps), systemImage: "repeat")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(sets.reduce(0) { $0 + $1.reps })")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Label(localizationManager.localizedString(for: AppStrings.Exercise.totalVolume), systemImage: "scalemass.fill")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) })) \(userSettings.weightUnit)")
                        .fontWeight(.medium)
                }
            } else if let reps = reps, let sets = sets, let weight = weight {
                // Legacy single-set display
                HStack {
                    Label(localizationManager.localizedString(for: AppStrings.Exercise.setsXReps), systemImage: "list.number")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(sets) x \(reps)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Label(localizationManager.localizedString(for: AppStrings.Exercise.weight), systemImage: "scalemass.fill")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f %@", weight, userSettings.weightUnit))
                        .fontWeight(.medium)
                }
            }
        }
        .font(.subheadline)
    }
    
    private var basicSummaryContent: some View {
        VStack(spacing: 8) {
            if duration > 0 {
                HStack {
                    Label(localizationManager.localizedString(for: AppStrings.Exercise.duration), systemImage: "clock.fill")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(duration) \(localizationManager.localizedString(for: AppStrings.Exercise.mins))")
                        .fontWeight(.medium)
                }
            }
            
            if let intensity = intensity {
                HStack {
                    Label(localizationManager.localizedString(for: AppStrings.Exercise.intensity), systemImage: "flame.fill")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(intensity.displayName)
                        .fontWeight(.medium)
                }
            }
        }
        .font(.subheadline)
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins) min"
    }
    
    private func calculatePaceString() -> String {
        guard let dist = distance, dist > 0, duration > 0 else { return "--" }
        let pacePerUnit = Double(duration) / dist
        let minutes = Int(pacePerUnit)
        let seconds = Int((pacePerUnit - Double(minutes)) * 60)
        let unitStr = distanceUnit?.displayName ?? "km"
        return String(format: "%d:%02d /%@", minutes, seconds, unitStr)
    }
    
    /// Calculate calories from API for all exercise types
    private func calculateCaloriesIfNeeded() {
        // Always use API for all exercise types to get accurate calculations
        Task {
            let workoutType = mapExerciseTypeToWorkoutType(exerciseType)
            let intensity = mapIntensityToAPI(intensity ?? .medium)
            
            // For weight lifting, estimate duration based on sets (roughly 2-3 minutes per set)
            // For other exercises, use the provided duration
            let durationForAPI: Int
            if exerciseType == .weightLifting && duration == 0 {
                // Estimate: 2-3 minutes per set, minimum 5 minutes
                let estimatedSets = exerciseSets?.count ?? sets ?? 1
                durationForAPI = max(5, estimatedSets * 3)
            } else {
                // Use provided duration, but ensure at least 1 minute for API
                durationForAPI = max(1, duration)
            }
            
            AppLogger.forClass("BurnedCaloriesView").info("Calculating calories via API: type=\(workoutType), duration=\(durationForAPI) min, intensity=\(intensity)")
            
            do {
                if let calculatedCalories = try await WorkoutCaloriesAPIService.shared.calculateCalories(
                    workoutType: workoutType,
                    durationMinutes: durationForAPI,
                    intensity: intensity
                ) {
                    await MainActor.run {
                        AppLogger.forClass("BurnedCaloriesView").success("API calculated \(calculatedCalories) calories (was \(editedCalories))")
                        editedCalories = calculatedCalories
                        isLoadingCalories = false // Hide loader once we have the result
                    }
                } else {
                    // If API fails, use a fallback calculation
                    AppLogger.forClass("BurnedCaloriesView").warning("API returned nil, using fallback calculation")
                    await MainActor.run {
                        editedCalories = calculateFallbackCalories()
                        isLoadingCalories = false // Hide loader
                    }
                }
            } catch let error as WorkoutCaloriesAPIError {
                // Missing user data - show error to user
                AppLogger.forClass("BurnedCaloriesView").warning("Missing user data for API calculation", error: error)
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    // Use fallback calculation as backup
                    editedCalories = calculateFallbackCalories()
                    isLoadingCalories = false // Hide loader
                }
            } catch {
                AppLogger.forClass("BurnedCaloriesView").warning("Failed to calculate calories from API", error: error)
                // Use fallback calculation
                await MainActor.run {
                    editedCalories = calculateFallbackCalories()
                    isLoadingCalories = false // Hide loader
                }
            }
        }
    }
    
    /// Map ExerciseType to API workout type string
    private func mapExerciseTypeToWorkoutType(_ type: ExerciseType) -> String {
        switch type {
        case .run:
            return "running"
        case .weightLifting:
            return "weightlifting"
        case .describe, .manual:
            // For manual/describe exercises, try to infer from notes or use generic
            if let notes = notes?.lowercased() {
                if notes.contains("run") || notes.contains("running") {
                    return "running"
                } else if notes.contains("cycle") || notes.contains("cycling") || notes.contains("bike") {
                    return "cycling"
                } else if notes.contains("swim") || notes.contains("swimming") {
                    return "swimming"
                } else if notes.contains("yoga") {
                    return "yoga"
                } else if notes.contains("hiit") || notes.contains("high intensity") {
                    return "HIIT"
                }
            }
            return "general" // Generic workout type
        }
    }
    
    /// Map ExerciseIntensity to API intensity string
    private func mapIntensityToAPI(_ intensity: ExerciseIntensity) -> String {
        switch intensity {
        case .low:
            return "low"
        case .medium:
            return "moderate"
        case .high:
            return "high"
        }
    }
    
    /// Fallback calculation if API fails
    private func calculateFallbackCalories() -> Int {
        // Simple fallback: base calories per minute based on intensity
        let baseCaloriesPerMinute: Double
        switch intensity ?? .medium {
        case .low:
            baseCaloriesPerMinute = 5
        case .medium:
            baseCaloriesPerMinute = 10
        case .high:
            baseCaloriesPerMinute = 15
        }
        
        let calculated = Int(baseCaloriesPerMinute * Double(duration))
        return max(1, min(calculated, 1000)) // Clamp between 1 and 1000
    }
    
    private func saveExercise() async {
        guard !isSaving else { return }
        
        // Check free exercise save limit for non-subscribed users
        let limitManager = ExerciseSaveLimitManager.shared
        
        if !isSubscribed {
            // Check if user can save an exercise
            guard limitManager.canSaveExercise(isSubscribed: false) else {
                // No free exercise saves left - show paywall
                showPaywall = true
                return
            }
        }
        
        isSaving = true
        defer { isSaving = false }
        
        // Validate input
        guard editedCalories > 0 else {
            errorMessage = "Please enter a valid number of calories burned."
            showError = true
            return
        }
        
        // Only validate duration for exercise types that require it (not weight lifting)
        if requiresDuration {
            guard duration > 0 else {
                errorMessage = "Please enter a valid duration."
                showError = true
                return
            }
        }
        
        // For weight lifting, validate sets
        if exerciseType == .weightLifting {
            if let sets = exerciseSets, !sets.isEmpty {
                // Using new sets-based system
                guard sets.allSatisfy({ $0.reps > 0 && $0.weight > 0 }) else {
                    errorMessage = "Please enter valid reps and weight for all sets."
                    showError = true
                    return
                }
            } else if let repsValue = reps, let setsValue = sets, let weightValue = weight {
                // Legacy validation
                guard repsValue > 0, setsValue > 0, weightValue > 0 else {
                    errorMessage = "Please enter valid reps, sets, and weight."
                    showError = true
                    return
                }
            }
        }
        
        do {
            // Use duration if provided, otherwise use 0 for exercise types that don't require it
            let exerciseDuration = requiresDuration ? duration : (duration > 0 ? duration : 0)
            
            let exercise = Exercise(
                type: exerciseType,
                calories: editedCalories,
                duration: exerciseDuration,
                intensity: intensity,
                notes: notes,
                reps: exerciseType == .weightLifting ? reps : nil,
                sets: exerciseType == .weightLifting ? sets : nil,
                weight: exerciseType == .weightLifting ? weight : nil,
                exerciseSets: exerciseType == .weightLifting ? exerciseSets : nil,
                distance: exerciseType == .run ? distance : nil,
                distanceUnit: exerciseType == .run ? distanceUnit : nil
            )
            
            // Use ExerciseRepository for consistent saving
            // If save fails due to database issues, the repository will retry automatically
            let repository = ExerciseRepository(context: modelContext)
            
            // Try to save with error handling
            do {
                try repository.saveExercise(exercise)
            } catch let error as NSError {
                // Check if it's a database file error
                if error.domain == NSCocoaErrorDomain && error.code == 256 {
                    // Database file couldn't be opened - this means the store is corrupted
                    AppLogger.forClass("BurnedCaloriesView").error("Database store is corrupted or missing tables", error: error)
                    
                    // Show a more user-friendly error message
                    errorMessage = "Database error. Please restart the app to fix this issue."
                    showError = true
                    HapticManager.shared.notification(.error)
                    return
                } else {
                    // Other errors - try retry
                    AppLogger.forClass("BurnedCaloriesView").error("ExerciseRepository.saveExercise failed", error: error)
                    
                    // Try to process pending changes and save again
                    modelContext.processPendingChanges()
                    do {
                        try repository.saveExercise(exercise)
                    } catch {
                        // If retry also fails, show error
                        throw error
                    }
                }
            }
            
            // Record exercise save for non-subscribed users
            if !isSubscribed {
                _ = limitManager.recordExerciseSave()
            }
            
            // Sync widget data after saving exercise
            let mealRepository = MealRepository(context: modelContext)
            mealRepository.syncWidgetData()
            
            // Also save to HealthKit if available and authorized
            let healthKitManager = HealthKitManager.shared
            if healthKitManager.isHealthDataAvailable && healthKitManager.isAuthorized {
                do {
                    try await healthKitManager.saveExercise(
                        calories: editedCalories,
                        durationMinutes: exerciseDuration,
                        startDate: exercise.date
                    )
                    AppLogger.forClass("BurnedCaloriesView").success("Exercise saved to HealthKit: \(editedCalories) cal, \(exerciseDuration) min")
                } catch {
                    // Continue even if HealthKit save fails - SwiftData is primary source
                    AppLogger.forClass("BurnedCaloriesView").warning("Failed to save exercise to HealthKit", error: error)
                }
            }
            
            // Notify that an exercise was saved so HomeViewModel can refresh burned calories
            NotificationCenter.default.post(name: .exerciseSaved, object: nil)
            
            // Notify that exercise flow should be dismissed (dismiss all exercise views back to home)
            NotificationCenter.default.post(name: .exerciseFlowShouldDismiss, object: nil)
            
            // Provide haptic feedback
            HapticManager.shared.notification(.success)
            
            // Dismiss immediately
            dismiss()
        } catch {
            errorMessage = "Failed to save exercise: \(error.localizedDescription)"
            showError = true
            HapticManager.shared.notification(.error)
            AppLogger.forClass("BurnedCaloriesView").error("Error saving exercise", error: error)
        }
    }
}

#Preview {
    BurnedCaloriesView(
        calories: 350,
        exerciseType: .run,
        duration: 45,
        intensity: .medium,
        notes: nil,
        distance: 5.0,
        distanceUnit: .kilometers
    )
}
