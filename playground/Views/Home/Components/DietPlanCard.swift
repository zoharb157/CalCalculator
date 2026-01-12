//
//  DietPlanCard.swift
//  playground
//
//  Card showing today's diet plan schedule on home screen
//  Handles all diet states: no plans, no active plan, has active plan
//

import SwiftUI
import SwiftData

struct DietPlanCard: View {
    // Selected date for viewing diet plan (defaults to today)
    var selectedDate: Date = Date()
    
    @Query private var allPlans: [DietPlan]
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activePlans: [DietPlan]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isSubscribed) private var isSubscribed
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var todaysMeals: [ScheduledMeal] = []
    @State private var completedMeals: Set<UUID> = []
    @State private var showingPlansList = false
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    var body: some View {
        let _ = localizationManager.currentLanguage
        
        return Group {
            if allPlans.isEmpty {
                noPlanPromptCard
            } else if activePlans.isEmpty {
                noActivePlanCard
            } else if !todaysMeals.isEmpty {
                activePlanSummaryCard
            } else {
                noMealsForDayCard
            }
        }
        .sheet(isPresented: $showingPlansList) {
            DietPlansListView()
        }
        .task {
            loadMealsForSelectedDate()
        }
        .onChange(of: selectedDate) { _, _ in
            loadMealsForSelectedDate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mealReminderAction)) { _ in
            loadMealsForSelectedDate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dietPlanChanged)) { _ in
            loadMealsForSelectedDate()
        }
    }
    
    // MARK: - State 1: No Plan Prompt Card
    
    private var noPlanPromptCard: some View {
        VStack(spacing: 16) {
            // Header with icon
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .cyan.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSubscribed 
                         ? localizationManager.localizedString(for: AppStrings.History.createYourDietPlan) 
                         : localizationManager.localizedString(for: AppStrings.History.unlockDietPlans))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(isSubscribed
                         ? localizationManager.localizedString(for: AppStrings.History.scheduleRepetitiveMeals)
                         : localizationManager.localizedString(for: AppStrings.History.subscribeToCreateDietPlans))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            // Features preview
            HStack(spacing: 16) {
                DietFeatureItem(icon: "clock.fill", text: localizationManager.localizedString(for: AppStrings.DietPlan.mealReminders), color: .orange)
                DietFeatureItem(icon: "chart.bar.fill", text: localizationManager.localizedString(for: AppStrings.DietPlan.trackAdherence), color: .green)
                DietFeatureItem(icon: "target", text: localizationManager.localizedString(for: AppStrings.DietPlan.reachGoals), color: .purple)
            }
            
            // Action button
            Button {
                if isSubscribed {
                    showingPlansList = true
                } else {
                    NotificationCenter.default.post(name: .showPaywall, object: nil)
                }
            } label: {
                HStack(spacing: 8) {
                    if !isSubscribed {
                        Image(systemName: "crown.fill")
                            .font(.subheadline)
                    }
                    Text(isSubscribed 
                         ? localizationManager.localizedString(for: AppStrings.History.createDietPlan) 
                         : localizationManager.localizedString(for: AppStrings.History.subscribeCreate))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: isSubscribed ? [.blue, .cyan] : [.orange, .yellow.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - State 2: No Active Plan Card
    
    private var noActivePlanCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.2), .yellow.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.noPlanActive))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(localizationManager.localizedString(
                        for: AppStrings.DietPlan.savedPlansAvailable,
                        arguments: allPlans.count
                    ))
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            // Quick preview of available plans
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(allPlans.prefix(3)) { plan in
                        InactivePlanChip(plan: plan)
                    }
                    
                    if allPlans.count > 3 {
                        Text("+\(allPlans.count - 3)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            
            Button {
                showingPlansList = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.activateAPlan))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - State 3: Active Plan Summary Card
    
    private var activePlanSummaryCard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.2), .mint.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizationManager.localizedString(for: AppStrings.Home.todaysDietPlan))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let plan = activePlans.first {
                        Text(plan.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let plan = activePlans.first {
                    Button {
                        NotificationCenter.default.post(
                            name: Notification.Name("editDietPlan"),
                            object: plan
                        )
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.blue.opacity(0.8))
                    }
                }
            }
            
            // Progress Section
            let completionRate = todaysMeals.isEmpty ? 0 : Double(completedMeals.count) / Double(todaysMeals.count)
            
            HStack(spacing: 20) {
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: completionRate)
                        .stroke(
                            LinearGradient(
                                colors: [completionColor(completionRate), completionColor(completionRate).opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionRate)
                    
                    Text("\(Int(completionRate * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(completionColor(completionRate))
                }
                
                // Stats
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        DietStatPill(
                            icon: "checkmark.circle.fill",
                            value: "\(completedMeals.count)",
                            label: localizationManager.localizedString(for: AppStrings.History.completed),
                            color: .green
                        )
                        
                        DietStatPill(
                            icon: "circle.dashed",
                            value: "\(todaysMeals.count - completedMeals.count)",
                            label: localizationManager.localizedString(for: AppStrings.DietPlan.remaining),
                            color: .orange
                        )
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [completionColor(completionRate), completionColor(completionRate).opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * completionRate, height: 6)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionRate)
                        }
                    }
                    .frame(height: 6)
                }
            }
            
            Divider()
            
            // Upcoming meals
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(todaysMeals.sorted(by: { $0.time < $1.time }), id: \.id) { meal in
                        MealScheduleChip(
                            meal: meal,
                            isCompleted: completedMeals.contains(meal.id)
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - State 4: No Meals for Day Card
    
    private var noMealsForDayCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.2), .indigo.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.noMealsScheduled))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.noMealsScheduledDescription))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // Quick actions
            HStack(spacing: 12) {
                if let plan = activePlans.first {
                    Button {
                        NotificationCenter.default.post(
                            name: Notification.Name("editDietPlan"),
                            object: plan
                        )
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption)
                            Text(localizationManager.localizedString(for: AppStrings.DietPlan.addMeals))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [.purple, .indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Helper Methods
    
    private func loadMealsForSelectedDate() {
        Task {
            let calendar = Calendar.current
            let dayOfWeek = calendar.component(.weekday, from: selectedDate)
            
            var meals: [ScheduledMeal] = []
            for plan in activePlans {
                meals.append(contentsOf: plan.scheduledMeals(for: dayOfWeek))
            }
            
            do {
                let adherence = try dietPlanRepository.getDietAdherence(
                    for: selectedDate,
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

// MARK: - Supporting Views

private struct DietFeatureItem: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct InactivePlanChip: View {
    let plan: DietPlan
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "fork.knife")
                .font(.caption2)
                .foregroundColor(.orange)
            
            Text(plan.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

private struct DietStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct MealScheduleChip: View {
    let meal: ScheduledMeal
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green.opacity(0.15) : meal.category.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: isCompleted ? "checkmark" : meal.category.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isCompleted ? .green : meal.category.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(meal.formattedTime)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCompleted ? Color.green.opacity(0.08) : Color.gray.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCompleted ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    DietPlanCard()
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self])
        .padding()
}
