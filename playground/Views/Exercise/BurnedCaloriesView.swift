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
    let intensity: ExerciseIntensity
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var editedCalories: Int
    @State private var isEditing = false
    
    init(calories: Int, exerciseType: ExerciseType, duration: Int, intensity: ExerciseIntensity) {
        self.calories = calories
        self.exerciseType = exerciseType
        self.duration = duration
        self.intensity = intensity
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
                    Text("Your workout burned")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    if isEditing {
                        TextField("", value: $editedCalories, format: .number)
                            .font(.system(size: 48, weight: .bold))
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(editedCalories)")
                                .font(.system(size: 48, weight: .bold))
                            
                            Text("Cals")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
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
                
                // Log Button
                Button {
                    saveExercise()
                } label: {
                    Text("Log")
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
            .padding()
            .navigationTitle("Burned Calories")
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
    
    private func saveExercise() {
        let exercise = Exercise(
            type: exerciseType,
            calories: editedCalories,
            duration: duration,
            intensity: intensity
        )
        modelContext.insert(exercise)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    BurnedCaloriesView(calories: 134, exerciseType: .run, duration: 15, intensity: .medium)
}

