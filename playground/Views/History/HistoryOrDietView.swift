//
//  HistoryOrDietView.swift
//  playground
//
//  Shows History or Diet view based on whether user has an active diet plan
//

import Charts
import SDK
import SwiftData
import SwiftUI

struct HistoryOrDietView: View {
    @Bindable var viewModel: HistoryViewModel
    let repository: MealRepository
    let tabName: String

    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(\.modelContext) private var modelContext
    @Environment(TheSDK.self) private var sdk
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activeDietPlans:
        [DietPlan]
    @State private var showingCreateDiet = false
    @State private var showingPaywall = false
    @State private var showingWelcome = false

    private var hasActiveDiet: Bool {
        !activeDietPlans.isEmpty
    }

    // Picker tabs
    private enum TopTab: String, CaseIterable, Identifiable {
        case dietPlan, history
        var id: String { rawValue }
        var title: String {
            switch self {
            case .dietPlan:
                return LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.myDiet)
            case .history:
                return LocalizationManager.shared.localizedString(for: AppStrings.History.title)
            }
        }
    }

    @State private var selectedTab: TopTab = .dietPlan

    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return Group {
            if hasActiveDiet && isSubscribed {
                VStack(spacing: 0) {
                    Picker("Select View", selection: $selectedTab) {
                        ForEach(TopTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding([.horizontal, .top])

                    if selectedTab == .dietPlan {
                        DietView(
                            viewModel: viewModel,
                            repository: repository
                        )
                        .navigationTitle(
                            localizationManager.localizedString(for: AppStrings.DietPlan.myDiet)
                        )
                        .id("my-diet-nav-\(localizationManager.currentLanguage)")
                    } else {
                        HistoryView(
                            viewModel: viewModel,
                            repository: repository,
                            isSubscribed: isSubscribed,
                            hasActiveDiet: hasActiveDiet,
                            onCreateDiet: {
                                if isSubscribed {
                                    showingCreateDiet = true
                                } else {
                                    showingPaywall = true
                                }
                            }
                        )
                    }
                }
            } else {
                // Show history with option to create diet (no picker)
                HistoryView(
                    viewModel: viewModel,
                    repository: repository,
                    isSubscribed: isSubscribed,
                    hasActiveDiet: hasActiveDiet,
                    onCreateDiet: {
                        if isSubscribed {
                            showingCreateDiet = true
                        } else {
                            showingPaywall = true
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingCreateDiet) {
            DietPlansListView()
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            SDKView(
                model: sdk,
                page: .splash,
                show: $showingPaywall,
                backgroundColor: .white,
                ignoreSafeArea: true
            )
        }
        .overlay {
            if showingWelcome {
                DietWelcomeView(isPresented: $showingWelcome)
            }
        }
        .onChange(of: hasActiveDiet) { oldValue, newValue in
            // Show welcome when user first creates a diet plan
            if newValue && !oldValue && !UserSettings.shared.hasSeenDietWelcome {
                showingWelcome = true
                UserSettings.shared.hasSeenDietWelcome = true
            }
        }
        .onAppear {
            // Show welcome if user has active diet but hasn't seen it yet
            if hasActiveDiet && !UserSettings.shared.hasSeenDietWelcome {
                showingWelcome = true
                UserSettings.shared.hasSeenDietWelcome = true
            }
        }
    }
}

// MARK: - Combined Diet and History View

struct CombinedDietAndHistoryView: View {
    @Bindable var viewModel: HistoryViewModel
    let repository: MealRepository
    let isSubscribed: Bool
    let hasActiveDiet: Bool
    let onCreateDiet: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var selectedDate: SelectedDate?
    @State private var searchText: String = ""
    @State private var selectedTimeFilter: HistoryTimeFilter = .all
    @State private var showingFilterSheet = false
    
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
                formatter.locale = Locale(identifier: localizationManager.currentLanguage)
                formatter.dateStyle = .medium
                let dateString = formatter.string(from: summary.date).lowercased()
                
                formatter.dateFormat = "EEEE"
                let dayName = formatter.string(from: summary.date).lowercased()
                
                formatter.dateFormat = "MMMM"
                let monthName = formatter.string(from: summary.date).lowercased()
                
                return dateString.contains(lowercasedSearch) ||
                       dayName.contains(lowercasedSearch) ||
                       monthName.contains(lowercasedSearch)
            }
        }
        
        return summaries
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                content
                
                // Diet creation prompt at bottom
                if !hasActiveDiet {
                    dietPromptCard
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.History.title))
                
            .background(Color(.systemGroupedBackground))
            .searchable(text: $searchText, prompt: Text(localizationManager.localizedString(for: AppStrings.History.searchByDateDayMonth)))
                
            .refreshable {
                await viewModel.loadData()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !hasActiveDiet {
                        Button {
                            onCreateDiet()
                        } label: {
                            Image(systemName: "calendar.badge.plus")
                        }
                    } else {
                        filterMenuButton
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
            .task {
                await viewModel.loadData()
            }
        }
    }
    
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
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingView
        } else if viewModel.showError {
            errorView
        } else if viewModel.allDaySummaries.isEmpty {
            emptyStateView
        } else if filteredSummaries.isEmpty {
            noResultsView
        } else {
            historyList
        }
    }
    
    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if !filteredSummaries.isEmpty {
                    StatsSummaryCard(
                        daysCount: filteredSummaries.count,
                        totalMeals: totalMeals,
                        totalCalories: totalCalories,
                        averageCalories: averageCalories,
                        timeFilter: selectedTimeFilter
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                ForEach(filteredSummaries, id: \.id) { summary in
                    DaySummaryCard(summary: summary)
                        .onTapGesture {
                            HapticManager.shared.impact(.light)
                            selectedDate = SelectedDate(date: summary.date)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .padding(.bottom, hasActiveDiet ? 8 : 100) // Extra padding for diet prompt
            .animation(.easeInOut(duration: 0.2), value: filteredSummaries.count)
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
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text(localizationManager.localizedString(for: AppStrings.History.loadingHistory))
                
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var errorView: some View {
        if viewModel.showError, let error = viewModel.error {
            FullScreenErrorView(
                error: error,
                retry: {
                    Task {
                        await viewModel.loadData()
                    }
                },
                dismiss: {
                    viewModel.showError = false
                }
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text(localizationManager.localizedString(for: AppStrings.History.noHistoryYet))
                
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(localizationManager.localizedString(for: AppStrings.History.historyDescription))
                
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(localizationManager.localizedString(for: AppStrings.History.noResults))
                
                .font(.title2)
                .fontWeight(.semibold)
            
            if !searchText.isEmpty {
                Text(localizationManager.localizedString(for: "No entries found for \"%@\"", arguments: searchText))
                    
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(localizationManager.localizedString(for: AppStrings.History.noEntriesFound))
                    
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
                    
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var dietPromptCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isSubscribed ? localizationManager.localizedString(for: AppStrings.History.createYourDietPlan) : localizationManager.localizedString(for: AppStrings.History.unlockDietPlans))
                        
                        .font(.headline)
                    
                    Text(isSubscribed 
                        ? localizationManager.localizedString(for: AppStrings.History.scheduleRepetitiveMeals)
                        : localizationManager.localizedString(for: AppStrings.History.subscribeToCreateDietPlans))
                        
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Button {
                onCreateDiet()
            } label: {
                HStack {
                    if !isSubscribed {
                        Image(systemName: "crown.fill")
                    }
                    Text(isSubscribed ? localizationManager.localizedString(for: AppStrings.History.createDietPlan) : localizationManager.localizedString(for: AppStrings.History.subscribeCreate))
                        
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSubscribed ? Color.blue : Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
    }
}

// MARK: - Combined Diet and History View

struct CombinedDietAndHistoryView: View {
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
                formatter.locale = Locale(identifier: localizationManager.currentLanguage)
                formatter.dateStyle = .medium
                let dateString = formatter.string(from: summary.date).lowercased()
                
                formatter.dateFormat = "EEEE"
                let dayName = formatter.string(from: summary.date).lowercased()
                
                formatter.dateFormat = "MMMM"
                let monthName = formatter.string(from: summary.date).lowercased()
                
                return dateString.contains(lowercasedSearch) ||
                       dayName.contains(lowercasedSearch) ||
                       monthName.contains(lowercasedSearch)
            }
        }
        
        return summaries
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Diet Summary Section
                    dietSummarySection
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // History Section
                    historySection
                }
                .padding()
            }
                .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.myDiet))
                    
            .searchable(text: $searchText, prompt: Text(localizationManager.localizedString(for: AppStrings.History.searchByDateDayMonth)))
                
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        Button {
                            if let plan = activePlans.first {
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
            .task {
                await viewModel.loadData()
                loadAdherenceData()
                loadWeeklyAdherence()
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // Reload data when language changes to ensure all localized strings update
                Task {
                    await viewModel.loadData()
                    loadAdherenceData()
                    loadWeeklyAdherence()
                }
            }
        }
    }
    
    // MARK: - Diet Summary Section
    
    private var dietSummarySection: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(spacing: 24) {
            // Time range selector
            Picker(localizationManager.localizedString(for: AppStrings.DietPlan.timeRange), selection: $selectedTimeRange) {
                ForEach(DietTimeRange.allCases, id: \.self) { range in
                    Text(localizationManager.localizedString(for: range.localizedKey))
                        .tag(range)
                }
            }
            .pickerStyle(.segmented)
            .id("time-range-picker-\(localizationManager.currentLanguage)")
            
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
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.adherence))
                        .font(.headline)
                        .foregroundColor(.secondary)
                        
                    
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
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: data.completionRate)
                }
                .frame(width: 80, height: 80)
            }
            
            // Quick stats
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
    
    private func adherenceColor(_ rate: Double) -> Color {
        switch rate {
        case 0.9...1.0: return .green
        case 0.7..<0.9: return .orange
        default: return .red
        }
    }
    
    private var adherenceTrendChart: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.adherenceTrend))
                
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
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(alignment: .leading, spacing: 12) {
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
            ForEach(Array(0..<sortedMeals.count), id: \.self) { index in
                let meal = sortedMeals[index]
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
                            completeMeal(meal)
                        }
                    }
                )
            }
        }
    }
    
    private func completeMeal(_ scheduledMeal: ScheduledMeal) {
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
                
                if let reminder = try dietPlanRepository.fetchMealReminder(
                    by: scheduledMeal.id,
                    for: Date()
                ) {
                    try dietPlanRepository.updateMealReminderCompletion(reminder, completedMealId: meal.id)
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
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.insights))
                
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                InsightCard(
                    icon: "flame.fill",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.streak),
                    value: calculateStreak(),
                    color: .orange
                )
                
                
                InsightCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.bestDay),
                    value: bestDayString(),
                    color: .green
                )
                
                
                InsightCard(
                    icon: "lightbulb.fill",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.tip),
                    value: generateTip(),
                    color: .blue
                )
                
            }
        }
    }
    
    private var weeklyStatsSection: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.weeklyStatistics))
                
                .font(.headline)
                .padding(.horizontal)
            
            if weeklyAdherence.isEmpty {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.noDataAvailable))
                    
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                let avgAdherence = weeklyAdherence.map { $0.completionRate }.reduce(0, +) / Double(weeklyAdherence.count)
                let totalMeals = weeklyAdherence.reduce(0) { $0 + $1.totalMeals }
                let completedMeals = weeklyAdherence.reduce(0) { $0 + $1.completedMeals }
                
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
    
    private func offDietAnalysisSection(data: DietAdherenceData) -> some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(alignment: .leading, spacing: 12) {
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
        Task {
            let calendar = Calendar.current
            let startDate = selectedTimeRange.startDate
            let endDate = Date()
            
            var adherence: [DailyAdherence] = []
            
            var currentDate = startDate
            while currentDate <= endDate {
                do {
                    let data = try dietPlanRepository.getDietAdherence(
                        for: currentDate,
                        activePlans: activePlans
                    )
                    
                    adherence.append(DailyAdherence(
                        date: currentDate,
                        completionRate: data.completionRate,
                        completedMeals: data.completedMeals.count,
                        totalMeals: data.scheduledMeals.count,
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
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
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
            
            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                break
            }
            currentDate = previousDate
        }
        
        return "\(streak) \(localizationManager.localizedString(for: AppStrings.DietPlan.days))"
    }
    
    private func bestDayString() -> String {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        guard let bestDay = weeklyAdherence.max(by: { $0.completionRate < $1.completionRate }) else {
            return localizationManager.localizedString(for: AppStrings.DietPlan.notAvailable)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: localizationManager.currentLanguage)
        return formatter.string(from: bestDay.date)
    }
    
    private func generateTip() -> String {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        guard let data = adherenceData else {
            return localizationManager.localizedString(for: AppStrings.DietPlan.startTrackingForTips)
        }
        
        if data.completionRate < 0.5 {
            return localizationManager.localizedString(for: AppStrings.DietPlan.trySettingReminders)
        } else if data.offDietCalories > 500 {
            return localizationManager.localizedString(for: AppStrings.DietPlan.planAheadOffDiet)
        } else if data.completionRate >= 0.9 {
            return localizationManager.localizedString(for: AppStrings.DietPlan.greatJobKeepConsistency)
        } else {
            return localizationManager.localizedString(for: AppStrings.DietPlan.doingWellSmallImprovements)
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
    
    private var historySection: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text(localizationManager.localizedString(for: AppStrings.History.title))
                    
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // History Content
            if viewModel.isLoading {
                loadingHistoryView
            } else if viewModel.showError {
                errorHistoryView
            } else if viewModel.allDaySummaries.isEmpty {
                emptyHistoryView
            } else if filteredSummaries.isEmpty {
                noResultsView
            } else {
                historyList
            }
        }
    }
    
    private var historyList: some View {
        VStack(spacing: 16) {
            if !filteredSummaries.isEmpty {
                StatsSummaryCard(
                    daysCount: filteredSummaries.count,
                    totalMeals: totalMeals,
                    totalCalories: totalCalories,
                    averageCalories: averageCalories,
                    timeFilter: selectedTimeFilter
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            ForEach(filteredSummaries, id: \.id) { summary in
                DaySummaryCard(summary: summary)
                    .onTapGesture {
                        HapticManager.shared.impact(.light)
                        selectedDate = SelectedDate(date: summary.date)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: filteredSummaries.count)
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
    
    @ViewBuilder
    private var loadingHistoryView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text(localizationManager.localizedString(for: AppStrings.History.loadingHistory))
                
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    @ViewBuilder
    private var errorHistoryView: some View {
        if viewModel.showError, let error = viewModel.error {
            FullScreenErrorView(
                error: error,
                retry: {
                    Task {
                        await viewModel.loadData()
                    }
                },
                dismiss: {
                    viewModel.showError = false
                }
            )
        }
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(localizationManager.localizedString(for: AppStrings.History.noHistoryYet))
                
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(localizationManager.localizedString(for: AppStrings.History.historyDescription))
                
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            
            Text(localizationManager.localizedString(for: AppStrings.History.noResults))
                
                .font(.title3)
                .fontWeight(.semibold)
            
            if !searchText.isEmpty {
                Text(localizationManager.localizedString(for: "No entries found for \"%@\"", arguments: searchText))
                    
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(localizationManager.localizedString(for: AppStrings.History.noEntriesFound))
                    
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
                    
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = HistoryViewModel(repository: repository)

    HistoryOrDietView(viewModel: viewModel, repository: repository, tabName: "History")
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self, Meal.self])
}
