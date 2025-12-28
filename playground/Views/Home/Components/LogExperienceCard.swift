//
//  LogExperienceCard.swift
//  playground
//
//  Card showing today's log summary with quick actions
//

import SwiftUI

struct LogExperienceCard: View {
    let mealsCount: Int
    let exercisesCount: Int
    let totalCaloriesConsumed: Int
    let totalCaloriesBurned: Int

    let onLogFood: () -> Void
    let onLogExercise: () -> Void
    let onScanMeal: () -> Void
    var onTextLog: (() -> Void)? = nil
    var onViewHistory: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Today's Log", systemImage: "list.bullet.clipboard.fill")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if let onViewHistory = onViewHistory {
                    Button(action: onViewHistory) {
                        HStack(spacing: 4) {
                            Text("View All")
                                .font(.caption)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                } else {
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Stats Row
            HStack(spacing: 24) {
                LogStatItem(
                    icon: "fork.knife",
                    value: "\(mealsCount)",
                    label: "Meals",
                    color: .orange
                )

                LogStatItem(
                    icon: "flame.fill",
                    value: "\(totalCaloriesConsumed)",
                    label: "Consumed",
                    color: .red
                )

                LogStatItem(
                    icon: "figure.run",
                    value: "\(exercisesCount)",
                    label: "Workouts",
                    color: .green
                )

                LogStatItem(
                    icon: "bolt.fill",
                    value: "\(totalCaloriesBurned)",
                    label: "Burned",
                    color: .blue
                )
            }

            Divider()

            // Quick Actions
            HStack(spacing: 8) {
                QuickLogButton(
                    icon: "camera.fill",
                    title: "Scan",
                    color: .purple,
                    action: onScanMeal
                )

                QuickLogButton(
                    icon: "pencil.line",
                    title: "Log Food",
                    color: .green,
                    action: onLogFood
                )

                if let onTextLog = onTextLog {
                    QuickLogButton(
                        icon: "text.bubble.fill",
                        title: "Describe",
                        color: .indigo,
                        action: onTextLog
                    )
                }

                QuickLogButton(
                    icon: "dumbbell.fill",
                    title: "Exercise",
                    color: .orange,
                    action: onLogExercise
                )
            }
        }
        .padding()
        .cardStyle(background: Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Log Stat Item

struct LogStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)

                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Log Button

struct QuickLogButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Log Card (alternative smaller version)

struct CompactLogExperienceCard: View {
    let mealsCount: Int
    let totalCalories: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "list.bullet.clipboard.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Log")
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        Label("\(mealsCount) meals", systemImage: "fork.knife")
                        Text("•")
                        Text("\(totalCalories) cal")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .cardStyle(background: Color(.secondarySystemGroupedBackground))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Log Summary Banner (inline banner version)

struct LogSummaryBanner: View {
    let mealsLogged: Int
    let exercisesLogged: Int
    let caloriesRemaining: Int

    var body: some View {
        HStack(spacing: 16) {
            // Meals indicator
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .foregroundColor(.orange)
                Text("\(mealsLogged)")
                    .fontWeight(.semibold)
            }

            Divider()
                .frame(height: 20)

            // Exercises indicator
            HStack(spacing: 4) {
                Image(systemName: "figure.run")
                    .foregroundColor(.green)
                Text("\(exercisesLogged)")
                    .fontWeight(.semibold)
            }

            Divider()
                .frame(height: 20)

            // Calories remaining
            HStack(spacing: 4) {
                Image(systemName: caloriesRemaining > 0 ? "flame" : "checkmark.circle.fill")
                    .foregroundColor(caloriesRemaining > 0 ? .orange : .green)
                Text("\(abs(caloriesRemaining))")
                    .fontWeight(.semibold)
                Text(caloriesRemaining > 0 ? "left" : "over")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Previews

#Preview("Full Card") {
    LogExperienceCard(
        mealsCount: 3,
        exercisesCount: 1,
        totalCaloriesConsumed: 1450,
        totalCaloriesBurned: 320,
        onLogFood: {},
        onLogExercise: {},
        onScanMeal: {}
    )
    .padding()
}

#Preview("Compact Card") {
    CompactLogExperienceCard(
        mealsCount: 3,
        totalCalories: 1450,
        onTap: {}
    )
    .padding()
}

#Preview("Summary Banner") {
    LogSummaryBanner(
        mealsLogged: 3,
        exercisesLogged: 1,
        caloriesRemaining: 550
    )
    .padding()
}
