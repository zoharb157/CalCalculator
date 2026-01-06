//
//  DietPlanCard.swift
//  playground
//
//  Card showing today's diet plan schedule on home screen
//

import SwiftUI
import SwiftData

struct DietPlanCard: View {
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activePlans: [DietPlan]
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var todaysMeals: [ScheduledMeal] = []
    @State private var completedMeals: Set<UUID> = []
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return Group {
            if !activePlans.isEmpty, !todaysMeals.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(localizationManager.localizedString(for: AppStrings.Home.todaysDietPlan), systemImage: "calendar.badge.clock")
                        .id("todays-diet-plan-\(localizationManager.currentLanguage)")
                        .font(.headline)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        if !activePlans.isEmpty {
                            Button {
                                // Edit diet plan - send notification to parent
                                if let plan = activePlans.first {
                                    NotificationCenter.default.post(
                                        name: Notification.Name("editDietPlan"),
                                        object: plan
                                    )
                                }
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Only show navigation link if there's an active plan
                        if !activePlans.isEmpty {
                            NavigationLink {
                                EnhancedDietSummaryView()
                            } label: {
                                Text(localizationManager.localizedString(for: AppStrings.Home.viewAll))
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                    .id("view-all-diet-\(localizationManager.currentLanguage)")
                            }
                        }
                    }
                }
                
                // Progress indicator
                if !todaysMeals.isEmpty {
                    let completionRate = Double(completedMeals.count) / Double(todaysMeals.count)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(String(format: localizationManager.localizedString(for: AppStrings.DietPlan.mealsCompletedFormat), completedMeals.count, todaysMeals.count))
                                .id("meals-completed-\(localizationManager.currentLanguage)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(completionRate * 100))%")
                                .font(.headline)
                                .foregroundColor(completionColor(completionRate))
                        }
                        
                        ProgressView(value: completionRate)
                            .tint(completionColor(completionRate))
                    }
                }
                
                // Upcoming meals
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(todaysMeals.sorted(by: { $0.time < $1.time }), id: \.id) { meal in
                            MealScheduleItem(
                                meal: meal,
                                isCompleted: completedMeals.contains(meal.id)
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .task {
                loadTodaysMeals()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mealReminderAction)) { _ in
                loadTodaysMeals()
            }
            } else {
                EmptyView()
            }
        }
    }
    
    private func loadTodaysMeals() {
        Task {
            let calendar = Calendar.current
            let today = Date()
            let dayOfWeek = calendar.component(.weekday, from: today)
            
            var meals: [ScheduledMeal] = []
            for plan in activePlans {
                meals.append(contentsOf: plan.scheduledMeals(for: dayOfWeek))
            }
            
            // Get completed meals
            do {
                let adherence = try dietPlanRepository.getDietAdherence(
                    for: today,
                    activePlans: activePlans
                )
                await MainActor.run {
                    todaysMeals = meals
                    completedMeals = Set(adherence.completedMeals)
                }
            } catch {
                await MainActor.run {
                    todaysMeals = meals
                    completedMeals = []
                }
            }
        }
    }
    
    private func completionColor(_ rate: Double) -> Color {
        switch rate {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
}

struct MealScheduleItem: View {
    let meal: ScheduledMeal
    let isCompleted: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: meal.category.icon)
                .font(.title2)
                .foregroundColor(isCompleted ? .green : meal.category.color)
            
            VStack(spacing: 2) {
                Text(meal.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(meal.formattedTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80)
            
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCompleted ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    DietPlanCard()
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self])
        .padding()
}

