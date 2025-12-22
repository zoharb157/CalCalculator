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
    
    @State private var selectedIntensity: ExerciseIntensity = .medium
    @State private var selectedDuration: Int = 15
    @State private var customDuration: String = "15"
    @State private var showingBurnedCalories = false
    @State private var calculatedCalories: Int = 0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Set Intensity Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                        Text("Set intensity")
                            .font(.headline)
                    }
                    
                    VStack(spacing: 12) {
                        IntensityOption(
                            title: "High",
                            subtitle: "Sprinting - 14 mph (4 minute miles)",
                            isSelected: selectedIntensity == .high
                        ) {
                            selectedIntensity = .high
                        }
                        
                        IntensityOption(
                            title: "Medium",
                            subtitle: "Jogging - 6 mph (10 minute miles)",
                            isSelected: selectedIntensity == .medium
                        ) {
                            selectedIntensity = .medium
                        }
                        
                        IntensityOption(
                            title: "Low",
                            subtitle: "Chill walk - 3 mph (20 minute miles)",
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
                        Text("Duration")
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
                        .onChange(of: customDuration) { oldValue, newValue in
                            if let minutes = Int(newValue) {
                                selectedDuration = minutes
                            }
                        }
                }
                .padding()
                
                Spacer()
                
                // Continue Button
                Button {
                    calculateCalories()
                    showingBurnedCalories = true
                } label: {
                    Text("Continue")
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
        .navigationTitle(exerciseType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingBurnedCalories) {
            BurnedCaloriesView(
                calories: calculatedCalories,
                exerciseType: exerciseType,
                duration: selectedDuration,
                intensity: selectedIntensity
            )
        }
    }
    
    private func calculateCalories() {
        // Simple calculation based on intensity and duration
        let baseCaloriesPerMinute: Double
        switch selectedIntensity {
        case .high: baseCaloriesPerMinute = 15
        case .medium: baseCaloriesPerMinute = 10
        case .low: baseCaloriesPerMinute = 5
        }
        calculatedCalories = Int(baseCaloriesPerMinute * Double(selectedDuration))
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
    
    var body: some View {
        Button(action: action) {
            Text("\(minutes) mins")
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

