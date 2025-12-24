//
//  LogExerciseView.swift
//
//  Log Exercise screen with options
//

import SwiftUI

struct LogExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: ExerciseType?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Log Exercise")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    ExerciseOptionCard(
                        type: .run,
                        title: "Run",
                        subtitle: "Running, jogging, sprinting, etc.",
                        isSelected: selectedType == .run
                    ) {
                        selectedType = .run
                    }
                    
                    ExerciseOptionCard(
                        type: .weightLifting,
                        title: "Weight lifting",
                        subtitle: "Machines, free weights, etc.",
                        isSelected: selectedType == .weightLifting
                    ) {
                        selectedType = .weightLifting
                    }
                    
                    ExerciseOptionCard(
                        type: .describe,
                        title: "Describe",
                        subtitle: "Write your workout in text",
                        isSelected: selectedType == .describe
                    ) {
                        selectedType = .describe
                    }
                    
                    ExerciseOptionCard(
                        type: .manual,
                        title: "Manual",
                        subtitle: "Enter exactly how many calories you burned",
                        isSelected: selectedType == .manual
                    ) {
                        selectedType = .manual
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Exercise")
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
            .navigationDestination(item: $selectedType) { type in
                ExerciseDetailView(exerciseType: type)
            }
        }
    }
}

struct ExerciseOptionCard: View {
    let type: ExerciseType
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

extension ExerciseType: Identifiable {
    var id: String { rawValue }
}

#Preview {
    LogExerciseView()
}

