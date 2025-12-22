//
//  PersonalDetailsView.swift
//  playground
//
//  Personal Details screen
//

import SwiftUI

struct PersonalDetailsView: View {
    @State private var profile = UserProfile.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditWeightGoal = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Goal Weight Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Goal Weight")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("\(profile.goalWeight, format: .number.precision(.fractionLength(1))) lbs")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        Button("Change Goal") {
                            showingEditWeightGoal = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 8)
                }
                
                // Personal Metrics Section
                Section {
                    EditableRow(
                        label: "Current weight",
                        value: "\(Int(profile.currentWeight)) lbs",
                        icon: "scalemass"
                    ) {
                        // Edit weight
                    }
                    
                    EditableRow(
                        label: "Height",
                        value: profile.heightDisplay,
                        icon: "ruler"
                    ) {
                        // Edit height
                    }
                    
                    EditableRow(
                        label: "Date of birth",
                        value: profile.dateOfBirth.formatted(date: .abbreviated, time: .omitted),
                        icon: "calendar"
                    ) {
                        // Edit DOB
                    }
                    
                    EditableRow(
                        label: "Gender",
                        value: profile.gender.displayName,
                        icon: "person"
                    ) {
                        // Edit gender
                    }
                    
                    EditableRow(
                        label: "Daily step goal",
                        value: "\(profile.dailyStepGoal) steps",
                        icon: "figure.walk"
                    ) {
                        // Edit step goal
                    }
                }
            }
            .navigationTitle("Personal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEditWeightGoal) {
                EditWeightGoalView()
            }
        }
    }
}

struct EditableRow: View {
    let label: String
    let value: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(label)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(value)
                    .foregroundColor(.secondary)
                
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    PersonalDetailsView()
}

