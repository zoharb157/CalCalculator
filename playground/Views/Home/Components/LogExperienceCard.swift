//
//  LogExperienceCard.swift
//  playground
//
//  Card showing today's activity summary with quick actions
//

import SwiftUI
import SwiftData

struct LogExperienceCard: View {
    let mealsCount: Int
    let exercisesCount: Int
    let totalCaloriesConsumed: Int
    let totalCaloriesBurned: Int

    let onLogFood: () -> Void
    let onLogExercise: () -> Void
    var onTextLog: (() -> Void)? = nil
    var onViewHistory: (() -> Void)? = nil
    var onViewDiet: (() -> Void)? = nil
    
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activePlans: [DietPlan]
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var todaysMealsCount: Int = 0
    @State private var completedMealsCount: Int = 0
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label(localizationManager.localizedString(for: AppStrings.Food.todayActivity), systemImage: "list.bullet.clipboard.fill")
                    .id("today-activity-label-\(localizationManager.currentLanguage)")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if let onViewHistory = onViewHistory {
                    Button(action: onViewHistory) {
                        HStack(spacing: 4) {
                            Text(localizationManager.localizedString(for: AppStrings.Food.viewAll))
                                .id("view-all-\(localizationManager.currentLanguage)")
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
                // Diet Plan Button - always show (premium feature)
                if let onViewDiet = onViewDiet {
                    QuickLogButton(
                        icon: "calendar.badge.clock",
                        title: localizationManager.localizedString(for: AppStrings.DietPlan.myDiet),
                        color: .blue,
                        action: onViewDiet
                    )
                }

                QuickLogButton(
                    icon: "pencil.line",
                    title: localizationManager.localizedString(for: AppStrings.Food.saveFood),
                    color: .green,
                    action: onLogFood
                )

                if let onTextLog = onTextLog {
                    QuickLogButton(
                        icon: "text.bubble.fill",
                        title: localizationManager.localizedString(for: AppStrings.Food.describeYourFood),
                        color: .indigo,
                        action: onTextLog
                    )
                }

                QuickLogButton(
                    icon: "dumbbell.fill",
                    title: localizationManager.localizedString(for: AppStrings.Food.exercise),
                    color: .orange,
                    action: onLogExercise
                )
                .id("quick-actions-\(localizationManager.currentLanguage)")
            }
        }
        .padding()
        .cardStyle(background: Color(.secondarySystemGroupedBackground))
        .task {
            loadTodaysDietInfo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dietPlanChanged)) { _ in
            loadTodaysDietInfo()
        }
    }
    
    private func loadTodaysDietInfo() {
        Task {
            let calendar = Calendar.current
            let today = Date()
            let dayOfWeek = calendar.component(.weekday, from: today)
            
            var meals: [ScheduledMeal] = []
            for plan in activePlans {
                meals.append(contentsOf: plan.scheduledMeals(for: dayOfWeek))
            }
            
            // Get completed meals
            var completedCount = 0
            if !activePlans.isEmpty {
                do {
                    let adherence = try dietPlanRepository.getDietAdherence(
                        for: today,
                        activePlans: activePlans
                    )
                    completedCount = adherence.completedMeals.count
                } catch {
                    // Ignore error, use 0
                }
            }
            
            await MainActor.run {
                todaysMealsCount = meals.count
                completedMealsCount = completedCount
            }
        }
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
    @ObservedObject private var localizationManager = LocalizationManager.shared

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
                    Text(localizationManager.localizedString(for: AppStrings.Food.todayActivity))
                        .font(.headline)
                        .foregroundColor(.primary)
                        .id("today-activity-info-\(localizationManager.currentLanguage)")

                    HStack(spacing: 8) {
                        Label("\(mealsCount) \(localizationManager.localizedString(for: AppStrings.Food.meals))", systemImage: "fork.knife")
                            .id("meals-count-\(localizationManager.currentLanguage)")
                        Text("•")
                        Text("\(totalCalories) \(localizationManager.localizedString(for: AppStrings.Progress.cal))")
                            .id("calories-count-\(localizationManager.currentLanguage)")
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
    @ObservedObject private var localizationManager = LocalizationManager.shared

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
                Text(caloriesRemaining > 0 ? localizationManager.localizedString(for: AppStrings.Home.caloriesLeft) : localizationManager.localizedString(for: AppStrings.Home.over))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .id("calories-remaining-\(localizationManager.currentLanguage)-\(caloriesRemaining > 0)")
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
        onViewDiet: {}
    )
    .modelContainer(for: [DietPlan.self, ScheduledMeal.self], inMemory: true)
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
