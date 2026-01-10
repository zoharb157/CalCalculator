//
//  MyDietView.swift
//  playground
//
//  Standalone My Diet tab view - NO search bar
//  Shows diet adherence, scheduled meals, and insights
//  Enhanced with diet plan switcher and Apple-style UI/UX
//

import Charts
import SwiftUI
import SwiftData
import SDK

// MARK: - MyDietView

struct MyDietView: View {
    
    // MARK: - Properties
    
    @Bindable var viewModel: MyDietViewModel
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    
    // MARK: - State
    
    @Query(sort: \DietPlan.createdAt, order: .reverse)
    private var allDietPlans: [DietPlan]
    
    @State private var showingEditPlan = false
    @State private var showingInsights = false
    @State private var showingPlansList = false
    @State private var showingPlanSwitcher = false
    @State private var showingPaywall = false
    @State private var showDeclineConfirmation = false
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    private var activePlan: DietPlan? {
        allDietPlans.first(where: { $0.isActive })
    }
    
    private var activeDietPlans: [DietPlan] {
        allDietPlans.filter { $0.isActive }
    }
    
    private var inactivePlans: [DietPlan] {
        // Explicitly exclude the active plan by ID to prevent duplicates
        guard let activeId = activePlan?.id else {
            return allDietPlans.filter { !$0.isActive }
        }
        return allDietPlans.filter { !$0.isActive && $0.id != activeId }
    }
    
    // MARK: - Body
    
    var body: some View {
        let _ = localizationManager.currentLanguage
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Plan Switcher Card
                    planSwitcherCard
                    
                    if activePlan != nil {
                        // Time Range Selector
                        timeRangeSelector
                        
                        // Adherence Overview
                        if let data = viewModel.adherenceData {
                            adherenceOverviewCard(data: data)
                        }
                        
                        // Trend Chart
                        if !viewModel.weeklyAdherence.isEmpty {
                            adherenceTrendChart
                        }
                        
                        // Today's Schedule
                        if let data = viewModel.adherenceData {
                            todaysScheduleSection(data: data)
                        }
                        
                        // Insights
                        insightsSection
                        
                        // Weekly Stats
                        weeklyStatsSection
                        
                        // Off-Diet Analysis
                        if let data = viewModel.adherenceData, data.offDietCalories > 0 {
                            offDietAnalysisSection(data: data)
                        }
                    } else {
                        // Empty State
                        emptyStateView
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.myDiet))
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
        }
        .sheet(isPresented: $showingInsights) {
            DietInsightsView(activePlans: activeDietPlans, repository: dietPlanRepository)
        }
        .sheet(isPresented: $showingEditPlan) {
            if let plan = activePlan {
                DietPlanEditorView(plan: plan, repository: dietPlanRepository)
            }
        }
        .sheet(isPresented: $showingPlansList) {
            DietPlansListView()
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            paywallView
        }
        .paywallDismissalOverlay(
            showPaywall: $showingPaywall,
            showDeclineConfirmation: $showDeclineConfirmation
        )
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task {
                await viewModel.loadAdherenceData()
            }
        }
        .onChange(of: viewModel.selectedTimeRange) { _, _ in
            Task {
                await viewModel.loadWeeklyAdherence()
            }
        }
        .task {
            viewModel.configure(modelContext: modelContext, activePlans: activeDietPlans)
            await viewModel.loadAllData()
        }
        .onChange(of: allDietPlans) { _, _ in
            viewModel.activePlans = activeDietPlans
            Task {
                await viewModel.loadAllData()
            }
        }
    }
    
    // MARK: - Plan Switcher Card
    
    private var planSwitcherCard: some View {
        Button {
            HapticManager.shared.impact(.light)
            if allDietPlans.count > 1 {
                showingPlanSwitcher = true
            } else if allDietPlans.isEmpty {
                showingPlansList = true
            } else {
                showingEditPlan = true
            }
        } label: {
            HStack(spacing: 12) {
                // Plan Icon
                ZStack {
                    Circle()
                        .fill(activePlan != nil ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: activePlan != nil ? "fork.knife.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(activePlan != nil ? .green : .gray)
                }
                
                // Plan Info
                VStack(alignment: .leading, spacing: 4) {
                    if let plan = activePlan {
                        HStack(spacing: 6) {
                            Text(localizationManager.localizedString(for: AppStrings.DietPlan.currentPlan))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if allDietPlans.count > 1 {
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(plan.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Label("\(plan.scheduledMeals.count) \(localizationManager.localizedString(for: AppStrings.DietPlan.mealsPerDay))", systemImage: "fork.knife")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let calories = plan.dailyCalorieGoal {
                                Label("\(calories) kcal", systemImage: "flame.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    } else {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.noPlanActive))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.tapToSelectPlan))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Status Indicator
                if activePlan != nil {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.active).uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(activePlan != nil ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            localizationManager.localizedString(for: AppStrings.DietPlan.switchPlan),
            isPresented: $showingPlanSwitcher,
            titleVisibility: .visible
        ) {
            planSwitcherOptions
        }
    }
    
    // MARK: - Plan Switcher Options
    
    @ViewBuilder
    private var planSwitcherOptions: some View {
        // Show all plans except the active one
        ForEach(inactivePlans) { plan in
            Button {
                activatePlan(plan)
            } label: {
                Label(plan.name, systemImage: "fork.knife")
            }
        }
        
        Button {
            showingPlansList = true
        } label: {
            Label(localizationManager.localizedString(for: AppStrings.DietPlan.managePlans), systemImage: "list.bullet")
        }
        
        Button(localizationManager.localizedString(for: AppStrings.Common.cancel), role: .cancel) {}
    }
    
    // MARK: - Activate Plan
    
    private func activatePlan(_ plan: DietPlan) {
        guard isSubscribed else {
            showingPaywall = true
            HapticManager.shared.notification(.warning)
            return
        }
        
        do {
            // Use repository to activate plan (handles deactivating others)
            try dietPlanRepository.activatePlan(plan)
            
            // Reschedule reminders
            Task {
                let reminderService = MealReminderService.shared(context: modelContext)
                try? await reminderService.scheduleAllReminders()
            }
            
            NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
            HapticManager.shared.notification(.success)
        } catch {
            print("Failed to activate plan: \(error)")
            HapticManager.shared.notification(.error)
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Illustration
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
            }
            .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.noDietPlan))
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.createDietDescription))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showingPlansList = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.createNewPlan))
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                if activePlan != nil {
                    Button {
                        showingEditPlan = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    
                    Button {
                        showingInsights = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                }
                
                Menu {
                    Button {
                        showingPlansList = true
                    } label: {
                        Label(localizationManager.localizedString(for: AppStrings.DietPlan.allPlans), systemImage: "list.bullet")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        Picker(localizationManager.localizedString(for: AppStrings.DietPlan.timeRange), selection: $viewModel.selectedTimeRange) {
            ForEach(DietTimeRange.allCases, id: \.self) { range in
                Text(localizationManager.localizedString(for: range.localizedKey))
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Adherence Overview Card
    
    private func adherenceOverviewCard(data: DietAdherenceData) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.adherence))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(data.completionRate * 100))%")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(viewModel.adherenceColor(data.completionRate))
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    
                    Circle()
                        .trim(from: 0, to: data.completionRate)
                        .stroke(
                            viewModel.adherenceColor(data.completionRate),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: data.completionRate)
                }
                .frame(width: 80, height: 80)
            }
            
            HStack(spacing: 20) {
                StatPill(
                    icon: "checkmark.circle.fill",
                    value: "\(data.completedMeals.count)",
                    label: localizationManager.localizedString(for: AppStrings.History.completed),
                    color: .green
                )
                
                StatPill(
                    icon: "xmark.circle.fill",
                    value: "\(data.missedMeals.count)",
                    label: localizationManager.localizedString(for: AppStrings.History.missed),
                    color: .red
                )
                
                StatPill(
                    icon: "fork.knife",
                    value: "\(data.scheduledMeals.count)",
                    label: localizationManager.localizedString(for: AppStrings.History.scheduled),
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Trend Chart
    
    private var adherenceTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.adherenceTrend))
                .font(.headline)
                .padding(.horizontal)
            
            Chart(viewModel.weeklyAdherence) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Adherence", day.completionRate)
                )
                .foregroundStyle(viewModel.adherenceColor(day.completionRate).gradient)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Today's Schedule
    
    private func todaysScheduleSection(data: DietAdherenceData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.todaySchedule))
                .font(.headline)
                .padding(.horizontal)
            
            if data.scheduledMeals.isEmpty {
                ContentUnavailableView(
                    localizationManager.localizedString(for: AppStrings.DietPlan.noMealsAlert),
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(localizationManager.localizedString(for: AppStrings.DietPlan.addMealsToDietPlan))
                )
                .frame(height: 150)
            } else {
                mealCardsView(data: data)
            }
        }
    }
    
    @ViewBuilder
    private func mealCardsView(data: DietAdherenceData) -> some View {
        let sortedMeals = data.scheduledMeals.sorted(by: { $0.time < $1.time })
        let missedMealIds = Set(data.missedMeals.map { $0.id })
        
        VStack(spacing: 8) {
            ForEach(sortedMeals, id: \.id) { meal in
                let isCompleted = data.completedMeals.contains(meal.id)
                let isMissed = missedMealIds.contains(meal.id)
                let goalAchieved = data.goalAchievedMeals.contains(meal.id)
                let goalMissed = data.goalMissedMeals.contains(meal.id)
                
                ScheduledMealCard(
                    meal: meal,
                    isCompleted: isCompleted,
                    isMissed: isMissed,
                    goalAchieved: goalAchieved,
                    goalMissed: goalMissed,
                    onTap: {
                        if !isCompleted {
                            Task {
                                await viewModel.completeMeal(meal)
                            }
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Insights Section
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.insights))
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                InsightCard(
                    icon: "flame.fill",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.streak),
                    value: viewModel.calculateStreak(),
                    color: .orange
                )
                
                InsightCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.bestDay),
                    value: viewModel.bestDayString(),
                    color: .green
                )
                
                InsightCard(
                    icon: "lightbulb.fill",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.tip),
                    value: viewModel.generateTip(),
                    color: .blue
                )
            }
        }
    }
    
    // MARK: - Weekly Stats
    
    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.weeklyStatistics))
                .font(.headline)
                .padding(.horizontal)
            
            if viewModel.weeklyAdherence.isEmpty {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.noDataAvailable))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                let avgAdherence = viewModel.weeklyAdherence.map { $0.completionRate }.reduce(0, +) / Double(viewModel.weeklyAdherence.count)
                let totalMeals = viewModel.weeklyAdherence.reduce(0) { $0 + $1.totalMeals }
                let completedMeals = viewModel.weeklyAdherence.reduce(0) { $0 + $1.completedMeals }
                
                HStack(spacing: 16) {
                    DietStatCard(
                        title: localizationManager.localizedString(for: AppStrings.DietPlan.avgAdherence),
                        value: "\(Int(avgAdherence * 100))%",
                        icon: "percent",
                        color: .blue
                    )
                    
                    DietStatCard(
                        title: localizationManager.localizedString(for: AppStrings.DietPlan.mealsCompletedCapitalized),
                        value: "\(completedMeals)/\(totalMeals)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }
            }
        }
    }
    
    // MARK: - Off-Diet Analysis
    
    private func offDietAnalysisSection(data: DietAdherenceData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.offDietMeals))
                    .font(.headline)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("\(data.offDietCalories) \(localizationManager.localizedString(for: AppStrings.DietPlan.caloriesFromOffDiet))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                ForEach(data.offDietMeals.prefix(3), id: \.id) { meal in
                    OffDietMealRow(meal: meal)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
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

// MARK: - Preview

#Preview {
    let viewModel = MyDietViewModel()
    
    MyDietView(viewModel: viewModel)
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self, Meal.self])
}
