//
//  BurnedCaloriesView.swift
//
//  Burned Calories result screen
//

import SwiftUI
import SwiftData

struct BurnedCaloriesView: View {
    let calories: Int
    let exerciseType: ExerciseType
    let duration: Int
    let intensity: ExerciseIntensity?
    let notes: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var editedCalories: Int
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    init(calories: Int, exerciseType: ExerciseType, duration: Int, intensity: ExerciseIntensity? = nil, notes: String? = nil) {
        self.calories = calories
        self.exerciseType = exerciseType
        self.duration = duration
        self.intensity = intensity
        self.notes = notes
        _editedCalories = State(initialValue: calories)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .trim(from: 0, to: 0.67) // 67% filled
                        .stroke(Color.black, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.black)
                }
                
                VStack(spacing: 8) {
                    Text(LocalizationManager.shared.localizedString(for: "Your workout burned"))
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .id("workout-burned-\(LocalizationManager.shared.currentLanguage)")
                    
                    if isEditing {
                        TextField("", value: $editedCalories, format: .number)
                            .font(.system(size: 48, weight: .bold))
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .keyboardDoneButton()
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(editedCalories)")
                                .font(.system(size: 48, weight: .bold))
                            
                            Text(LocalizationManager.shared.localizedString(for: "Cals"))
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .id("cals-\(LocalizationManager.shared.currentLanguage)")
                            
                            Button {
                                isEditing = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Save Button
                Button {
                    Task {
                        await saveExercise()
                    }
                } label: {
                    HStack {
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
                    .padding()
                    .background(isSaving ? Color.gray : Color.black)
                    .cornerRadius(12)
                }
                .disabled(isSaving)
                .padding(.horizontal)
                .padding(.bottom, 40)
                .alert("Error", isPresented: $showError) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.ok)) { }
                } message: {
                    Text(errorMessage)
                }
            }
            .padding()
            .navigationTitle(LocalizationManager.shared.localizedString(for: "Burned Calories"))
                .id("burned-calories-title-\(LocalizationManager.shared.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
    
    private func saveExercise() async {
        guard !isSaving else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        // Validate input
        guard editedCalories > 0 else {
            errorMessage = "Please enter a valid number of calories burned."
            showError = true
            return
        }
        
        guard duration > 0 else {
            errorMessage = "Please enter a valid duration."
            showError = true
            return
        }
        
        do {
            let exercise = Exercise(
                type: exerciseType,
                calories: editedCalories,
                duration: duration,
                intensity: intensity,
                notes: notes
            )
            
            // Use repository pattern for consistent saving
            let repository = MealRepository(context: modelContext)
            try repository.saveExercise(exercise)
            
            // Notify that an exercise was saved so HomeViewModel can refresh burned calories
            NotificationCenter.default.post(name: .exerciseSaved, object: nil)
            
            // Provide haptic feedback
            HapticManager.shared.notification(.success)
            
            // Dismiss immediately
            dismiss()
        } catch {
            errorMessage = "Failed to save exercise: \(error.localizedDescription)"
            showError = true
            HapticManager.shared.notification(.error)
            print("❌ Error saving exercise: \(error)")
        }
    }
}

#Preview {
    BurnedCaloriesView(calories: 134, exerciseType: .run, duration: 15, intensity: .medium, notes: nil)
}

