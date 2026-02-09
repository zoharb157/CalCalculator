//
//  LogExerciseView.swift
//
//  Log Exercise screen with options
//

import SwiftUI

struct LogExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: ExerciseType?
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text(localizationManager.localizedString(for: AppStrings.Exercise.saveExercise))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .id("save-exercise-title-\(localizationManager.currentLanguage)")
                    
                    Text("Choose how you want to log your workout")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 32)
                
                // Exercise Options Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    EnhancedExerciseCard(
                        type: .run,
                        title: localizationManager.localizedString(for: AppStrings.Exercise.run),
                        subtitle: "Track distance & pace",
                        gradient: [Color.green.opacity(0.8), Color.green],
                        iconBackground: .green
                    ) {
                        selectedType = .run
                    }
                    
                    EnhancedExerciseCard(
                        type: .weightLifting,
                        title: localizationManager.localizedString(for: AppStrings.Exercise.weightLifting),
                        subtitle: "Log sets & reps",
                        gradient: [Color.orange.opacity(0.8), Color.orange],
                        iconBackground: .orange
                    ) {
                        selectedType = .weightLifting
                    }
                    
                    EnhancedExerciseCard(
                        type: .describe,
                        title: localizationManager.localizedString(for: AppStrings.Food.describe),
                        subtitle: "Describe your workout",
                        gradient: [Color.blue.opacity(0.8), Color.blue],
                        iconBackground: .blue
                    ) {
                        selectedType = .describe
                    }
                    
                    EnhancedExerciseCard(
                        type: .manual,
                        title: localizationManager.localizedString(for: AppStrings.Exercise.manualEntry),
                        subtitle: "Enter calories directly",
                        gradient: [Color.purple.opacity(0.8), Color.purple],
                        iconBackground: .purple
                    ) {
                        selectedType = .manual
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Quick tip
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Tip: Use 'Describe' to log any type of exercise with AI estimation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Food.exercise))
                .id("exercise-nav-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Pixel.track("screen_log_exercise", type: .navigation)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationDestination(item: $selectedType) { type in
                ExerciseDetailView(exerciseType: type)
            }
            .onReceive(NotificationCenter.default.publisher(for: .exerciseFlowShouldDismiss)) { _ in
                dismiss()
            }
        }
    }
}

// MARK: - Enhanced Exercise Card

struct EnhancedExerciseCard: View {
    let type: ExerciseType
    let title: String
    let subtitle: String
    let gradient: [Color]
    let iconBackground: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconBackground.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundColor(iconBackground)
                }
                
                Spacer()
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(iconBackground.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Original Card (kept for compatibility)

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
