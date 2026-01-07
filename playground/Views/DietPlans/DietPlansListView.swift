//
//  DietPlansListView.swift
//  playground
//
//  List view for managing diet plans
//

import SwiftUI
import SwiftData
import SDK

struct DietPlansListView: View {
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activePlans: [DietPlan]
    @Query(sort: \DietPlan.createdAt, order: .reverse) private var allPlans: [DietPlan]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var showingCreatePlan = false
    @State private var showingTemplates = false
    @State private var showingQuickSetup = false
    @State private var selectedPlan: DietPlan?
    @State private var showingDeleteConfirmation = false
    @State private var planToDelete: DietPlan?
    @State private var showingWelcome = false
    @State private var showingPaywall = false
    @State private var showDeclineConfirmation = false
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    private var hasActivePlan: Bool {
        !activePlans.isEmpty
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if !hasActivePlan {
                        emptyStateView
                    } else {
                        activePlanView
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.title))
            .toolbar {
                if hasActivePlan {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            if let plan = activePlans.first {
                                selectedPlan = plan
                            }
                        } label: {
                            Label(localizationManager.localizedString(for: AppStrings.Common.edit), systemImage: "pencil")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingTemplates) {
                DietPlanTemplatesView { template in
                    // Template selected - create/replace plan (only one active diet allowed)
                    // Check premium subscription before saving
                    guard isSubscribed else {
                        showingPaywall = true
                        HapticManager.shared.notification(.warning)
                        return
                    }
                    
                    let plan = template.createDietPlan()
                    do {
                        try dietPlanRepository.saveDietPlan(plan)
                        Task {
                            let reminderService = MealReminderService.shared(context: modelContext)
                            try? await reminderService.requestAuthorization()
                            try? await reminderService.scheduleAllReminders()
                        }
                        NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
                        
                        // Show success notification
                        HapticManager.shared.notification(.success)
                    } catch {
                        print("Failed to create plan from template: \(error)")
                    }
                }
            }
            .sheet(isPresented: $showingQuickSetup) {
                DietQuickSetupView()
            }
            .sheet(isPresented: $showingCreatePlan) {
                // When creating, replace existing plan if any
                DietPlanEditorView(plan: activePlans.first, repository: dietPlanRepository)
            }
            .sheet(item: $selectedPlan) { plan in
                DietPlanEditorView(plan: plan, repository: dietPlanRepository)
            }
            .confirmationDialog(
                localizationManager.localizedString(for: AppStrings.DietPlan.deleteDietPlan),
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(localizationManager.localizedString(for: AppStrings.Common.delete), role: .destructive) {
                    if let plan = planToDelete {
                        deletePlan(plan)
                    }
                }
                Button(localizationManager.localizedString(for: AppStrings.Common.cancel), role: .cancel) {
                    planToDelete = nil
                }
            } message: {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.deleteConfirmation))
            }
            .overlay {
                if showingWelcome {
                    DietWelcomeView(isPresented: $showingWelcome)
                }
            }
            .onAppear {
                // Show welcome view if user hasn't seen it and has no active plan
                if !hasActivePlan && !UserSettings.shared.hasSeenDietWelcome {
                    showingWelcome = true
                }
            }
            .onChange(of: hasActivePlan) { oldValue, newValue in
                // Show welcome view when a plan is first created (transition from no plan to having plan)
                if !oldValue && newValue && !UserSettings.shared.hasSeenDietWelcome {
                    // Small delay to ensure the view is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingWelcome = true
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            // Illustration
            illustrationView
            
            // Text content
            VStack(spacing: 12) {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.noDietPlan))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.createDietDescription))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Creation options
            creationOptionsView
        }
        .padding(.top, 40)
    }
    
    private var illustrationView: some View {
        ZStack {
            // Background circles
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 160, height: 160)
            
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 120, height: 120)
            
            // Icons arranged in a pattern
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    mealIcon("sun.horizon.fill", color: .orange)
                    mealIcon("sun.max.fill", color: .green)
                }
                HStack(spacing: 16) {
                    mealIcon("moon.stars.fill", color: .blue)
                    mealIcon("leaf.fill", color: .purple)
                }
            }
        }
    }
    
    private func mealIcon(_ systemName: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 44, height: 44)
            
            Image(systemName: systemName)
                .font(.system(size: 20))
                .foregroundColor(color)
        }
    }
    
    private var creationOptionsView: some View {
        VStack(spacing: 12) {
            // Quick Setup - Primary action
            Button {
                HapticManager.shared.impact(.light)
                showingQuickSetup = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.quickSetup))
                            .font(.headline)
                        
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.quickSetupDescription))
                            .font(.caption)
                            .opacity(0.8)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            
            HStack(spacing: 12) {
                // Use Template
                CreationOptionCard(
                    icon: "doc.on.doc.fill",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.useTemplate),
                    color: .purple
                ) {
                    HapticManager.shared.impact(.light)
                    showingTemplates = true
                }
                
                // Create from Scratch
                CreationOptionCard(
                    icon: "pencil.and.list.clipboard",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.createFromScratch),
                    color: .green
                ) {
                    HapticManager.shared.impact(.light)
                    showingCreatePlan = true
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Active Plan View
    
    private var activePlanView: some View {
        VStack(spacing: 20) {
            if let plan = activePlans.first {
                // Active plan card
                ActivePlanCard(plan: plan) {
                    selectedPlan = plan
                }
                
                // Plan stats
                planStatsSection(plan: plan)
                
                // Today's meals section
                todaysMealsSection(plan: plan)
                
                // Actions section
                actionsSection(plan: plan)
            }
        }
    }
    
    private func planStatsSection(plan: DietPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "chart.bar.fill", title: localizationManager.localizedString(for: AppStrings.DietPlan.planSummary))
            
            HStack(spacing: 12) {
                DietPlanStatCard(
                    value: "\(plan.scheduledMeals.count)",
                    label: localizationManager.localizedString(for: AppStrings.History.meals),
                    icon: "fork.knife",
                    color: .blue
                )
                
                DietPlanStatCard(
                    value: "\(totalMealsPerWeek(plan: plan))",
                    label: localizationManager.localizedString(for: AppStrings.DietPlan.perWeek),
                    icon: "calendar",
                    color: .green
                )
                
                DietPlanStatCard(
                    value: "\(activeDaysCount(plan: plan))",
                    label: localizationManager.localizedString(for: AppStrings.DietPlan.days),
                    icon: "checkmark.circle.fill",
                    color: .orange
                )
            }
        }
    }
    
    private func todaysMealsSection(plan: DietPlan) -> some View {
        let todayMeals = mealsForToday(plan: plan)
        
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "sun.max.fill", title: localizationManager.localizedString(for: AppStrings.DietPlan.todaysMeals))
            
            if todayMeals.isEmpty {
                HStack {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundColor(.secondary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.noMealsToday))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(todayMeals) { meal in
                        TodayMealRow(meal: meal)
                    }
                }
            }
        }
    }
    
    private func actionsSection(plan: DietPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "gearshape.fill", title: localizationManager.localizedString(for: AppStrings.Common.actions))
            
            VStack(spacing: 0) {
                // Edit plan
                ActionRow(
                    icon: "pencil",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.editDietPlan),
                    color: .blue
                ) {
                    selectedPlan = plan
                }
                
                Divider()
                    .padding(.leading, 44)
                
                // Replace with template
                ActionRow(
                    icon: "doc.on.doc",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.replaceWithTemplate),
                    color: .purple
                ) {
                    showingTemplates = true
                }
                
                Divider()
                    .padding(.leading, 44)
                
                // Delete plan
                ActionRow(
                    icon: "trash",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.deleteDietPlan),
                    color: .red
                ) {
                    planToDelete = plan
                    showingDeleteConfirmation = true
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helper Methods
    
    private func totalMealsPerWeek(plan: DietPlan) -> Int {
        plan.scheduledMeals.reduce(0) { $0 + $1.daysOfWeek.count }
    }
    
    private func activeDaysCount(plan: DietPlan) -> Int {
        var days = Set<Int>()
        for meal in plan.scheduledMeals {
            for day in meal.daysOfWeek {
                days.insert(day)
            }
        }
        return days.count
    }
    
    private func mealsForToday(plan: DietPlan) -> [ScheduledMeal] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        // daysOfWeek uses 1=Sunday, 2=Monday, ..., 7=Saturday
        return plan.scheduledMeals
            .filter { $0.daysOfWeek.contains(weekday) }
            .sorted { $0.time < $1.time }
    }
    
    private func deletePlan(_ plan: DietPlan) {
        do {
            try dietPlanRepository.deleteDietPlan(plan)
            
            // Reschedule reminders after deletion
            Task {
                let reminderService = MealReminderService.shared(context: modelContext)
                try? await reminderService.scheduleAllReminders()
            }
            
            // Post notification that diet plan changed
            NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
            
            HapticManager.shared.notification(.success)
        } catch {
            print("Failed to delete diet plan: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct CreationOptionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct ActivePlanCard: View {
    let plan: DietPlan
    let onTap: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Active badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.active).uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                Text(plan.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let description = plan.planDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 16) {
                    Label("\(plan.scheduledMeals.count) \(localizationManager.localizedString(for: AppStrings.History.meals))", systemImage: "fork.knife")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(plan.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color(.secondarySystemGroupedBackground), Color(.secondarySystemGroupedBackground).opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct DietPlanStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct TodayMealRow: View {
    let meal: ScheduledMeal
    
    private var categoryColor: Color {
        switch meal.category {
        case .breakfast: return .orange
        case .lunch: return .green
        case .dinner: return .blue
        case .snack: return .purple
        }
    }
    
    private var categoryIcon: String {
        switch meal.category {
        case .breakfast: return "sun.horizon.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: categoryIcon)
                    .font(.system(size: 16))
                    .foregroundColor(categoryColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(meal.category.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(meal.time.formatted(date: .omitted, time: .shortened))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(categoryColor)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct ActionRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(color == .red ? .red : .primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Paywall View
    
    private var paywallView: some View {
        SDKView(
            model: sdk,
            page: .splash,
            show: paywallBinding(
                showPaywall: $showingPaywall,
                sdk: sdk,
                showDeclineConfirmation: $showDeclineConfirmation
            ),
            backgroundColor: .white,
            ignoreSafeArea: true
        )
    }
}

#Preview {
    DietPlansListView()
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self])
}
