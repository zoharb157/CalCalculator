//
//  EditNutritionGoalsView.swift
//  playground
//
//  Edit Nutrition Goals screen with circular progress indicators
//

import SwiftUI

struct EditNutritionGoalsView: View {
    @State private var settings = UserSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingMicronutrients = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NutritionGoalRow(
                        icon: "flame.fill",
                        iconColor: .orange,
                        title: "Calorie goal",
                        value: settings.calorieGoal,
                        progress: 0.75,
                        unit: "cal"
                    ) {
                        // Edit calories
                    }
                    
                    NutritionGoalRow(
                        icon: "drumstick.fill",
                        iconColor: .red,
                        title: "Protein goal",
                        value: Int(settings.proteinGoal),
                        progress: 0.5,
                        unit: "g"
                    ) {
                        // Edit protein
                    }
                    
                    NutritionGoalRow(
                        icon: "leaf.fill",
                        iconColor: .brown,
                        title: "Carb goal",
                        value: Int(settings.carbsGoal),
                        progress: 0.65,
                        unit: "g"
                    ) {
                        // Edit carbs
                    }
                    
                    NutritionGoalRow(
                        icon: "drop.fill",
                        iconColor: .blue,
                        title: "Fat goal",
                        value: Int(settings.fatGoal),
                        progress: 0.33,
                        unit: "g"
                    ) {
                        // Edit fat
                    }
                }
                
                Section {
                    Button {
                        showingMicronutrients = true
                    } label: {
                        HStack {
                            Text("View micronutrients")
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button {
                        // Auto generate goals
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Auto Generate Goals")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Edit nutrition goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Revert") {
                        // Revert changes
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMicronutrients) {
                MicronutrientsView()
            }
        }
    }
}

struct NutritionGoalRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: Int
    let progress: Double
    let unit: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Circular Progress Indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(iconColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(value) \(unit)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

struct MicronutrientsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Micronutrients")
                .navigationTitle("Micronutrients")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview {
    EditNutritionGoalsView()
}

