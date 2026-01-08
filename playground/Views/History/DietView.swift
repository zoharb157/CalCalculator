//
//  DietView.swift
//  CalCalculatorAiPlaygournd
//
//  Created by Bassam-Hillo on 29/12/2025.
//

import SwiftUI
import SwiftData
import Charts

struct DietView: View {
    @Bindable var viewModel: HistoryViewModel
    let repository: MealRepository
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activePlans: [DietPlan]

    @State private var selectedDate: SelectedDate?
    @State private var searchText: String = ""
    @State private var selectedTimeFilter: HistoryTimeFilter = .all
    @State private var showingEditPlan = false
    @State private var showingInsights = false
    @State private var showingMealVerification: ScheduledMeal?
    // ScanViewModel - computed property using repository
    private var scanViewModel: ScanViewModel {
        ScanViewModel(
            repository: repository,
            analysisService: CaloriesAPIService(),
            imageStorage: .shared
        )
    }
    
    init(
        viewModel: HistoryViewModel,
        repository: MealRepository
    ) {
        self.viewModel = viewModel
        self.repository = repository
    }

    // Diet summary state
    @State private var selectedDietDate = Date()
    @State private var selectedTimeRange: DietTimeRange = .week
    @State private var adherenceData: DietAdherenceData?
    @State private var weeklyAdherence: [DailyAdherence] = []
    @State private var isLoadingDiet = false

    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }

    private var filteredSummaries: [DaySummary] {
        var summaries = viewModel.allDaySummaries

        if selectedTimeFilter != .all {
            let cutoffDate = selectedTimeFilter.startDate
            summaries = summaries.filter { $0.date >= cutoffDate }
        }

        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            summaries = summaries.filter { summary in
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                let dateString = formatter.string(from: summary.date).lowercased()

                formatter.dateFormat = "EEEE"
                let dayName = formatter.string(from: summary.date).lowercased()

                formatter.dateFormat = "MMMM"
                let monthName = formatter.string(from: summary.date).lowercased()

                return dateString.contains(lowercasedSearch) || dayName.contains(lowercasedSearch)
                    || monthName.contains(lowercasedSearch)
            }
        }

        return summaries
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                dietSummarySection
                    .padding()
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.myDiet))
            .id("my-diet-nav-\(localizationManager.currentLanguage)")
            .searchable(text: $searchText, prompt: "Search by date, day, or month")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        Button {
                            if activePlans.first != nil {
                                showingEditPlan = true
                            }
                        } label: {
                            Image(systemName: "pencil")
                        }

                        Button {
                            showingInsights = true
                        } label: {
                            Image(systemName: "chart.bar.fill")
                        }

                        if selectedTimeFilter != .all || !searchText.isEmpty {
                            filterMenuButton
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if hasActiveFilters {
                    activeFiltersSection
                }
            }
            .fullScreenCover(item: $selectedDate) { selected in
                MealsListSheet(
                    selectedDate: selected.date,
                    repository: repository,
                    onDismiss: {
                        selectedDate = nil
                    }
                )
            }
            .sheet(isPresented: $showingEditPlan) {
                if let plan = activePlans.first {
                    DietPlanEditorView(plan: plan, repository: dietPlanRepository)
                }
            }
            .sheet(isPresented: $showingInsights) {
                DietInsightsView(activePlans: activePlans, repository: dietPlanRepository)
            }
            .sheet(item: $showingMealVerification) { scheduledMeal in
                MealVerificationView(
                    scheduledMealId: scheduledMeal.id,
                    mealName: scheduledMeal.name,
                    category: scheduledMeal.category,
                    expectedCalories: scheduledMeal.mealTemplate?.expectedCalories,
                    scanViewModel: scanViewModel
                )
            }
            .task {
                await viewModel.loadData()
                loadAdherenceData()
                loadWeeklyAdherence()
            }
        }
    }

    // MARK: - Diet Summary Section

    private var dietSummarySection: some View {
        VStack(spacing: 24) {
            // Time range selector
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(DietTimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            // Main adherence card
            if let data = adherenceData {
                adherenceOverviewCard(data: data)
            }

            // Trend chart
            if !weeklyAdherence.isEmpty {
                adherenceTrendChart
            }

            // Today's schedule
            if let data = adherenceData {
                todaysScheduleSection(data: data)
            }

            // Insights section
            insightsSection

            // Weekly stats
            weeklyStatsSection

            // Off-diet analysis
            if let data = adherenceData, data.offDietCalories > 0 {
                offDietAnalysisSection(data: data)
            }
        }
    }

    private func adherenceOverviewCard(data: DietAdherenceData) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.adherence))
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .id("adherence-card-\(localizationManager.currentLanguage)")

                    Text("\(Int(data.completionRate * 100))%")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(adherenceColor(data.completionRate))
                }

                Spacer()

                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                    Circle()
                        .trim(from: 0, to: data.completionRate)
                        .stroke(
                            adherenceColor(data.completionRate),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8), value: data.completionRate
                        )
                }
                .frame(width: 80, height: 80)
            }

            // Quick stats
            HStack(spacing: 20) {
                StatPill(
                    icon: "checkmark.circle.fill",
                    value: "\(data.completedMeals.count)",
                    label: "Completed",
                    color: .green
                )

                StatPill(
                    icon: "xmark.circle.fill",
                    value: "\(data.missedMeals.count)",
                    label: "Missed",
                    color: .red
                )

                // Safely access scheduledMeals relationship by creating a local copy first
                StatPill(
                    icon: "fork.knife",
                    value: "\(Array(data.scheduledMeals).count)",
                    label: "Scheduled",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func adherenceColor(_ rate: Double) -> Color {
        switch rate {
        case 0.9...1.0: return .green
        case 0.7..<0.9: return .orange
        default: return .red
        }
    }

    private var adherenceTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.adherenceTrend))
                .id("adherence-trend-label-\(localizationManager.currentLanguage)")
                .font(.headline)
                .padding(.horizontal)

            Chart(weeklyAdherence) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Adherence", day.completionRate)
                )
                .foregroundStyle(adherenceColor(day.completionRate).gradient)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }

    private func todaysScheduleSection(data: DietAdherenceData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.todaySchedule))
                .id("today-schedule-label-\(localizationManager.currentLanguage)")
                .font(.headline)
                .padding(.horizontal)

            // Safely access scheduledMeals relationship by creating a local copy first
            let scheduledMealsArray = Array(data.scheduledMeals)
            
            if scheduledMealsArray.isEmpty {
                ContentUnavailableView(
                    "No Meals Scheduled",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(
                        localizationManager.localizedString(
                            for: "Add meals to your diet plan to see them here"))
                )
                .frame(height: 150)
                .id("add-meals-desc-label-\(localizationManager.currentLanguage)")
            } else {
                mealCardsView(data: data, scheduledMeals: scheduledMealsArray)
            }
        }
    }

    @ViewBuilder
    private func mealCardsView(data: DietAdherenceData, scheduledMeals: [ScheduledMeal]) -> some View {
        let sortedMeals = scheduledMeals.sorted(by: { $0.time < $1.time })
        let missedMealIds = Set(data.missedMeals.map { $0.id })

        VStack(spacing: 8) {
            ForEach(Array(sortedMeals.enumerated()), id: \.offset) { index, meal in
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
                            // Show meal verification view to allow image upload and analysis
                            showingMealVerification = meal
                        } else {
                            // If completed, allow deletion
                            deleteCompletedMeal(meal)
                        }
                    }
                )
            }
        }
    }

    // Note: completeMeal now opens MealVerificationView to allow image upload and analysis
    // This provides a better UX where users can verify their meal with a photo
    private func completeMeal(_ scheduledMeal: ScheduledMeal) {
        // Show meal verification view to allow image upload and analysis
        showingMealVerification = scheduledMeal
    }
    
    // Delete a completed meal - removes the meal and marks the scheduled meal as incomplete
    private func deleteCompletedMeal(_ scheduledMeal: ScheduledMeal) {
        Task {
            do {
                // Find the meal reminder for this scheduled meal
                if let reminder = try dietPlanRepository.fetchMealReminder(
                    by: scheduledMeal.id,
                    for: Date()
                ), let completedMealId = reminder.completedMealId {
                    // Delete the completed meal from MealRepository
                    let mealRepository = MealRepository(context: modelContext)
                    if let meal = try mealRepository.fetchMeal(by: completedMealId) {
                        try mealRepository.deleteMeal(meal)
                    }
                    
                    // Update the reminder to mark as incomplete
                    try dietPlanRepository.updateMealReminderCompletion(reminder, completedMealId: nil)
                    
                    // Notify other parts of the app about the meal deletion
                    NotificationCenter.default.post(name: .foodLogged, object: nil)
                    
                    // Reload adherence data
                    loadAdherenceData()
                    await viewModel.loadData()
                    
                    HapticManager.shared.notification(.success)
                }
            } catch {
                print("Failed to delete completed meal: \(error)")
                HapticManager.shared.notification(.error)
            }
        }
    }
    
    // Legacy function - kept for reference but no longer used
    private func completeMealLegacy(_ scheduledMeal: ScheduledMeal) {
        Task {
            do {
                let meal: Meal
                if let template = scheduledMeal.mealTemplate {
                    meal = template.createMeal(at: Date(), category: scheduledMeal.category)
                } else {
                    meal = Meal(
                        name: scheduledMeal.name,
                        timestamp: Date(),
                        category: scheduledMeal.category,
                        items: []
                    )
                }

                let mealRepository = MealRepository(context: modelContext)
                try mealRepository.saveMeal(meal)
                
                // Notify other parts of the app about the new meal
                // This triggers HomeView to refresh and update widgets
                NotificationCenter.default.post(name: .foodLogged, object: nil)

                if let reminder = try dietPlanRepository.fetchMealReminder(
                    by: scheduledMeal.id,
                    for: Date()
                ) {
                    try dietPlanRepository.updateMealReminderCompletion(
                        reminder, completedMealId: meal.id)
                } else {
                    let reminder = MealReminder(
                        scheduledMealId: scheduledMeal.id,
                        reminderDate: Date(),
                        wasCompleted: true,
                        completedMealId: meal.id,
                        completedAt: Date()
                    )
                    try dietPlanRepository.saveMealReminder(reminder)
                }

                if scheduledMeal.mealTemplate != nil {
                    let (achieved, deviation) = dietPlanRepository.evaluateMealGoalAchievement(
                        actualMeal: meal,
                        scheduledMeal: scheduledMeal
                    )
                    if let reminder = try dietPlanRepository.fetchMealReminder(
                        by: scheduledMeal.id,
                        for: Date()
                    ) {
                        try dietPlanRepository.updateMealReminderGoalAchievement(
                            reminder,
                            goalAchieved: achieved,
                            goalDeviation: deviation
                        )
                    }
                }

                HapticManager.shared.notification(.success)
                loadAdherenceData()
                await viewModel.loadData()
            } catch {
                print("Failed to complete meal: \(error)")
                HapticManager.shared.notification(.error)
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.insights))
                .id("insights-label-\(localizationManager.currentLanguage)")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                InsightCard(
                    icon: "flame.fill",
                    title: "Streak",
                    value: calculateStreak(),
                    color: .orange
                )

                InsightCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Best Day",
                    value: bestDayString(),
                    color: .green
                )

                InsightCard(
                    icon: "lightbulb.fill",
                    title: "Tip",
                    value: generateTip(),
                    color: .blue
                )
            }
        }
    }

    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.weeklyStatistics))
                .id("weekly-stats-label-\(localizationManager.currentLanguage)")
                .font(.headline)
                .padding(.horizontal)

            if weeklyAdherence.isEmpty {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.noDataAvailable))
                    .id("no-data-label-\(localizationManager.currentLanguage)")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                let avgAdherence =
                    weeklyAdherence.map { $0.completionRate }.reduce(0, +)
                    / Double(weeklyAdherence.count)
                let totalMeals = weeklyAdherence.reduce(0) { $0 + $1.totalMeals }
                let completedMeals = weeklyAdherence.reduce(0) { $0 + $1.completedMeals }

                HStack(spacing: 16) {
                    DietStatCard(
                        title: "Avg Adherence",
                        value: "\(Int(avgAdherence * 100))%",
                        icon: "percent",
                        color: .blue
                    )

                    DietStatCard(
                        title: "Meals Completed",
                        value: "\(completedMeals)/\(totalMeals)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }
            }
        }
    }

    private func offDietAnalysisSection(data: DietAdherenceData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.offDietMeals))
                    .id("off-diet-meals-label-\(localizationManager.currentLanguage)")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text(
                    "\(data.offDietCalories) \(localizationManager.localizedString(for: AppStrings.DietPlan.caloriesFromOffDiet))"
                )
                .id("off-diet-calories-label-\(localizationManager.currentLanguage)")
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

    private func loadAdherenceData() {
        Task {
            isLoadingDiet = true
            defer { isLoadingDiet = false }

            do {
                adherenceData = try dietPlanRepository.getDietAdherence(
                    for: selectedDietDate,
                    activePlans: activePlans
                )
            } catch {
                print("Failed to load adherence data: \(error)")
            }
        }
    }

    private func loadWeeklyAdherence() {
        Task { @MainActor in
            let calendar = Calendar.current
            guard let startDate = selectedTimeRange.startDate else {
                weeklyAdherence = []
                return
            }
            let endDate = Date()

            var adherence: [DailyAdherence] = []
            let plans = Array(activePlans)

            var currentDate = startDate
            while currentDate <= endDate {
                do {
                    let data = try dietPlanRepository.getDietAdherence(
                        for: currentDate,
                        activePlans: plans
                    )

                    // Safely access scheduledMeals relationship by creating a local copy first
                    adherence.append(
                        DailyAdherence(
                            date: currentDate,
                            completionRate: data.completionRate,
                            completedMeals: data.completedMeals.count,
                            totalMeals: Array(data.scheduledMeals).count,
                            goalAchievementRate: data.goalAchievementRate
                        ))
                } catch {
                    print("Failed to load adherence for \(currentDate): \(error)")
                }

                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                    break
                }
                currentDate = nextDate
            }

            await MainActor.run {
                weeklyAdherence = adherence
            }
        }
    }

    private func calculateStreak() -> String {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())

        for _ in 0..<30 {
            do {
                let data = try dietPlanRepository.getDietAdherence(
                    for: currentDate,
                    activePlans: activePlans
                )
                if data.completionRate >= 0.8 {
                    streak += 1
                } else {
                    break
                }
            } catch {
                break
            }

            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate)
            else {
                break
            }
            currentDate = previousDate
        }

        return "\(streak) days"
    }

    private func bestDayString() -> String {
        guard let bestDay = weeklyAdherence.max(by: { $0.completionRate < $1.completionRate })
        else {
            return "N/A"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: bestDay.date)
    }

    private func generateTip() -> String {
        guard let data = adherenceData else {
            return "Start tracking to get personalized tips"
        }

        if data.completionRate < 0.5 {
            return "Try setting reminders 15 minutes before meal time"
        } else if data.offDietCalories > 500 {
            return "Plan ahead to avoid off-diet meals"
        } else if data.completionRate >= 0.9 {
            return "Great job! Keep up the consistency"
        } else {
            return "You're doing well! Small improvements add up"
        }
    }

    // MARK: - History Section

    private var hasActiveFilters: Bool {
        selectedTimeFilter != .all || !searchText.isEmpty
    }

    private var activeFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if selectedTimeFilter != .all {
                    FilterTag(
                        text: selectedTimeFilter.displayName,
                        onRemove: {
                            withAnimation {
                                selectedTimeFilter = .all
                            }
                        }
                    )
                }

                if !searchText.isEmpty {
                    FilterTag(
                        text: "\"\(searchText)\"",
                        onRemove: {
                            withAnimation {
                                searchText = ""
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var filterMenuButton: some View {
        Menu {
            ForEach(HistoryTimeFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTimeFilter = filter
                    }
                    HapticManager.shared.impact(.light)
                } label: {
                    HStack {
                        Text(filter.displayName)
                        if selectedTimeFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(selectedTimeFilter.shortName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.blue)
        }
    }

    private var totalCalories: Int {
        filteredSummaries.reduce(0) { $0 + $1.totalCalories }
    }

    private var totalMeals: Int {
        filteredSummaries.reduce(0) { $0 + $1.mealCount }
    }

    private var averageCalories: Int {
        guard !filteredSummaries.isEmpty else { return 0 }
        return totalCalories / filteredSummaries.count
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(localizationManager.localizedString(for: AppStrings.History.noResults))
                .id("no-results-\(localizationManager.currentLanguage)")
                .font(.title3)
                .fontWeight(.semibold)

            if !searchText.isEmpty {
                Text(
                    localizationManager.localizedString(
                        for: "No entries found for \"%@\"", arguments: searchText)
                )
                .id("no-entries-search-\(localizationManager.currentLanguage)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            } else {
                Text(localizationManager.localizedString(for: AppStrings.History.noEntriesFound))
                    .id("no-entries-period-\(localizationManager.currentLanguage)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                withAnimation {
                    searchText = ""
                    selectedTimeFilter = .all
                }
            } label: {
                Text(localizationManager.localizedString(for: AppStrings.History.clearFilters))
                    .id("clear-filters-\(localizationManager.currentLanguage)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
