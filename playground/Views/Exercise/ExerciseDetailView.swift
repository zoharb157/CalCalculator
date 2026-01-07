//
//  ExerciseDetailView.swift
//
//  Exercise detail screen (Run example)
//

import SwiftUI

struct ExerciseDetailView: View {
    let exerciseType: ExerciseType
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var selectedIntensity: ExerciseIntensity?
    @State private var selectedDuration: Int = 0
    @State private var customDuration: String = ""
    @State private var showingBurnedCalories = false
    @State private var calculatedCalories: Int = 0
    
    @State private var exerciseDescription: String = ""
    @State private var manualCalories: String = ""
    
    // Weight lifting specific
    @State private var reps: String = ""
    @State private var sets: String = ""
    @State private var weight: String = ""
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Different UI based on exercise type
                if exerciseType == .describe {
                    describeExerciseView
                } else if exerciseType == .manual {
                    manualExerciseView
                } else if exerciseType == .weightLifting {
                    // Weight lifting uses reps, sets, weight instead of duration
                    weightLiftingView
                } else {
                    // Run uses intensity and duration
                    intensityAndDurationView
                }
            }
        }
        .navigationTitle(exerciseType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Add single keyboard toolbar for weight lifting view only
            if exerciseType == .weightLifting {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .id("done-keyboard-\(localizationManager.currentLanguage)")
                }
            }
        }
        .sheet(isPresented: $showingBurnedCalories) {
            BurnedCaloriesView(
                calories: calculatedCalories,
                exerciseType: exerciseType,
                duration: exerciseType == .weightLifting ? 0 : selectedDuration,
                intensity: exerciseType == .describe || exerciseType == .manual || exerciseType == .weightLifting ? nil : selectedIntensity,
                notes: exerciseType == .describe ? exerciseDescription.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                reps: exerciseType == .weightLifting ? Int(reps) : nil,
                sets: exerciseType == .weightLifting ? Int(sets) : nil,
                weight: exerciseType == .weightLifting ? (Double(weight) ?? nil) : nil
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .exerciseFlowShouldDismiss)) { _ in
            // Dismiss this view when exercise is saved, returning user to home
            dismiss()
        }
        .onAppear {
            // Reset to clean state when view appears
            selectedIntensity = nil
            selectedDuration = 0
            customDuration = ""
            // Temporary: Generate random calories between 1-10000 until API is connected
            calculatedCalories = Int.random(in: 1...10000)
            exerciseDescription = ""
            manualCalories = ""
            reps = ""
            sets = ""
            weight = ""
        }
    }
    
    // MARK: - Describe Exercise View
    
    private var describeExerciseView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizationManager.localizedString(for: AppStrings.Exercise.describeYourWorkout))
                .id("describe-workout-\(localizationManager.currentLanguage)")
                .font(.headline)
                .padding(.horizontal)
            
            TextEditor(text: $exerciseDescription)
                .frame(height: 200)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
            
            // Duration Section for describe
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "clock.fill")
                    Text(localizationManager.localizedString(for: AppStrings.Exercise.durationMinutes))
                        .id("duration-minutes-\(localizationManager.currentLanguage)")
                        .font(.headline)
                }
                
                // Quick duration buttons
                HStack(spacing: 12) {
                    DurationButton(minutes: 15, isSelected: selectedDuration == 15) {
                        selectedDuration = 15
                        customDuration = "15"
                    }
                    DurationButton(minutes: 30, isSelected: selectedDuration == 30) {
                        selectedDuration = 30
                        customDuration = "30"
                    }
                    DurationButton(minutes: 60, isSelected: selectedDuration == 60) {
                        selectedDuration = 60
                        customDuration = "60"
                    }
                    DurationButton(minutes: 90, isSelected: selectedDuration == 90) {
                        selectedDuration = 90
                        customDuration = "90"
                    }
                }
                
                // Custom duration input
                TextField("Custom", text: $customDuration)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .keyboardDoneButton()
                    .onChange(of: customDuration) { oldValue, newValue in
                        if let minutes = Int(newValue), minutes > 0 {
                            selectedDuration = minutes
                        } else {
                            selectedDuration = 0
                        }
                    }
            }
            .padding()
            
            Spacer()
            
            // Continue Button - only show when valid
            if !exerciseDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedDuration > 0 {
                Button {
                    calculateCaloriesForDescribe()
                    showingBurnedCalories = true
                } label: {
                    Text(localizationManager.localizedString(for: AppStrings.Common.continue_))
                        .id("continue-\(localizationManager.currentLanguage)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Manual Exercise View
    
    private var manualExerciseView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text(localizationManager.localizedString(for: AppStrings.Exercise.enterCaloriesBurned))
                    .id("enter-calories-\(localizationManager.currentLanguage)")
                    .font(.headline)
                    .padding(.horizontal)
                
                TextField("Calories", text: $manualCalories)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .keyboardDoneButton()
                    .padding(.horizontal)
                    .onChange(of: manualCalories) { oldValue, newValue in
                        if let calories = Int(newValue), calories > 0 {
                            calculatedCalories = calories
                        } else {
                            // Temporary: Generate random calories between 1-10000 until API is connected
                            calculatedCalories = Int.random(in: 1...10000)
                        }
                    }
            }
            
            Spacer()
            
            // Continue Button - only show when valid
            if let calories = Int(manualCalories), calories > 0 {
                Button {
                    calculatedCalories = calories
                    showingBurnedCalories = true
                } label: {
                    Text(localizationManager.localizedString(for: AppStrings.Common.continue_))
                        .id("continue-\(localizationManager.currentLanguage)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Weight Lifting View
    
    private var weightLiftingView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Reps Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "repeat")
                    Text(localizationManager.localizedString(for: AppStrings.Exercise.reps))
                        .id("reps-label-\(localizationManager.currentLanguage)")
                        .font(.headline)
                }
                
                TextField("Reps", text: $reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            
            // Sets Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "list.number")
                    Text(localizationManager.localizedString(for: AppStrings.Exercise.sets))
                        .id("sets-label-\(localizationManager.currentLanguage)")
                        .font(.headline)
                }
                
                TextField("Sets", text: $sets)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            
            // Weight Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "scalemass")
                    Text(localizationManager.localizedString(for: AppStrings.Exercise.weight))
                        .id("weight-label-\(localizationManager.currentLanguage)")
                        .font(.headline)
                }
                
                TextField("Weight (kg)", text: $weight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            
            Spacer()
            
            // Continue Button - only show when valid
            if let repsValue = Int(reps), repsValue > 0,
               let setsValue = Int(sets), setsValue > 0,
               let weightValue = Double(weight), weightValue > 0 {
                Button {
                    // Calculate calories based on reps, sets, and weight
                    // Temporary: Generate random calories between 1-10000 until API is connected
                    calculatedCalories = Int.random(in: 1...10000)
                    showingBurnedCalories = true
                } label: {
                    Text(localizationManager.localizedString(for: AppStrings.Common.continue_))
                        .id("continue-\(localizationManager.currentLanguage)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .id("done-keyboard-\(localizationManager.currentLanguage)")
            }
        }
    }
    
    // MARK: - Intensity and Duration View (for Run)
    
    private var intensityAndDurationView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Set Intensity Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "sun.max.fill")
                    Text(localizationManager.localizedString(for: AppStrings.Exercise.setIntensity))
                        .id("set-intensity-\(localizationManager.currentLanguage)")
                        .font(.headline)
                }
                
                VStack(spacing: 12) {
                    IntensityOption(
                        title: localizationManager.localizedString(for: AppStrings.Exercise.high),
                        subtitle: localizationManager.localizedString(for: AppStrings.Exercise.sprinting),
                        isSelected: selectedIntensity == .high
                    ) {
                        selectedIntensity = .high
                    }
                    
                    IntensityOption(
                        title: localizationManager.localizedString(for: AppStrings.Exercise.medium),
                        subtitle: localizationManager.localizedString(for: AppStrings.Exercise.jogging),
                        isSelected: selectedIntensity == .medium
                    ) {
                        selectedIntensity = .medium
                    }
                    
                    IntensityOption(
                        title: localizationManager.localizedString(for: AppStrings.Exercise.low),
                        subtitle: localizationManager.localizedString(for: AppStrings.Exercise.chillWalk),
                        isSelected: selectedIntensity == .low
                    ) {
                        selectedIntensity = .low
                    }
                }
            }
            .padding()
            
            // Duration Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "clock.fill")
                    Text(localizationManager.localizedString(for: AppStrings.Progress.duration))
                        .font(.headline)
                        .id("duration-label-\(localizationManager.currentLanguage)")
                }
                
                // Quick duration buttons
                HStack(spacing: 12) {
                    DurationButton(minutes: 15, isSelected: selectedDuration == 15) {
                        selectedDuration = 15
                        customDuration = "15"
                    }
                    DurationButton(minutes: 30, isSelected: selectedDuration == 30) {
                        selectedDuration = 30
                        customDuration = "30"
                    }
                    DurationButton(minutes: 60, isSelected: selectedDuration == 60) {
                        selectedDuration = 60
                        customDuration = "60"
                    }
                    DurationButton(minutes: 90, isSelected: selectedDuration == 90) {
                        selectedDuration = 90
                        customDuration = "90"
                    }
                }
                
                // Custom duration input
                TextField("Custom", text: $customDuration)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .keyboardDoneButton()
                    .onChange(of: customDuration) { oldValue, newValue in
                        if let minutes = Int(newValue), minutes > 0 {
                            selectedDuration = minutes
                        } else {
                            selectedDuration = 0
                        }
                    }
            }
            .padding()
            
            Spacer()
            
            // Continue Button - only show when intensity and duration are selected
            if selectedIntensity != nil && selectedDuration > 0 {
                Button {
                    calculateCalories()
                    showingBurnedCalories = true
                } label: {
                    Text(localizationManager.localizedString(for: AppStrings.Common.continue_))
                        .id("continue-\(localizationManager.currentLanguage)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func calculateCalories() {
        // Check if duration and intensity are set before calculating
        guard let intensity = selectedIntensity, selectedDuration > 0 else {
            // Temporary: Generate random calories between 1-10000 until API is connected
            calculatedCalories = Int.random(in: 1...10000)
            return
        }
        
        // Simple calculation based on intensity and duration
        let baseCaloriesPerMinute: Double
        switch intensity {
        case .high: baseCaloriesPerMinute = 15
        case .medium: baseCaloriesPerMinute = 10
        case .low: baseCaloriesPerMinute = 5
        }
        let calculated = Int(baseCaloriesPerMinute * Double(selectedDuration))
        // Ensure we have at least 1 calorie, otherwise generate random
        calculatedCalories = calculated > 0 ? calculated : Int.random(in: 1...10000)
    }
    
    private func calculateCaloriesForDescribe() {
        // For describe type, use a simple estimation based on duration
        // Default to medium intensity estimation
        guard selectedDuration > 0 else {
            // Temporary: Generate random calories between 1-10000 until API is connected
            calculatedCalories = Int.random(in: 1...10000)
            return
        }
        // Use medium intensity as default for described exercises
        let calculated = Int(10.0 * Double(selectedDuration))
        // Ensure we have at least 1 calorie, otherwise generate random
        calculatedCalories = calculated > 0 ? calculated : Int.random(in: 1...10000)
    }
}

struct IntensityOption: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                        )
                } else {
                    Circle()
                        .stroke(Color.gray, lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .padding()
            .background(isSelected ? Color.gray.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
    }
}

struct DurationButton: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        Button(action: action) {
            Text("\(minutes) \(localizationManager.localizedString(for: AppStrings.Exercise.mins))")
                .id("minutes-label-\(localizationManager.currentLanguage)")
                .font(.subheadline)
                .foregroundColor(isSelected ? .white : .black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.black : Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exerciseType: .run)
    }
}

