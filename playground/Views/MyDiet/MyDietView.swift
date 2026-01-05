//
//  MyDietView.swift
//  playground
//
//  Standalone My Diet tab view - NO search bar
//  Shows diet adherence, scheduled meals, and insights
//

import Charts
import SwiftUI
import SwiftData

// MARK: - MyDietView

struct MyDietView: View {
    
    // MARK: - Properties
    
    @Bindable var viewModel: MyDietViewModel
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true })
    private var activeDietPlans: [DietPlan]
    
    @State private var showingEditPlan = false
    @State private var showingInsights = false
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    // MARK: - Body
    
    var body: some View {
        let _ = localizationManager.currentLanguage
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    timeRangeSelector
                    
                    if let data = viewModel.adherenceData {
                        adherenceOverviewCard(data: data)
                    }
                    
                    if !viewModel.weeklyAdherence.isEmpty {
                        adherenceTrendChart
                    }
                    
                    if let data = viewModel.adherenceData {
                        todaysScheduleSection(data: data)
                    }
                    
                    insightsSection
                    weeklyStatsSection
                    
                    if let data = viewModel.adherenceData, data.offDietCalories > 0 {
                        offDietAnalysisSection(data: data)
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
            if let plan = activeDietPlans.first {
                DietPlanEditorView(plan: plan, repository: dietPlanRepository)
            }
        }
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
        .onChange(of: activeDietPlans) { _, newPlans in
            viewModel.activePlans = newPlans
            Task {
                await viewModel.loadAllData()
            }
        }
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
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
}

// MARK: - Preview

#Preview {
    let viewModel = MyDietViewModel()
    
    MyDietView(viewModel: viewModel)
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self, Meal.self])
}
