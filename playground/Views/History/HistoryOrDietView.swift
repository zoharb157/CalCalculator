//
//  HistoryOrDietView.swift
//  playground
//
//  Shows History or Diet view based on whether user has an active diet plan
//

import SwiftUI
import SwiftData
import SDK

struct HistoryOrDietView: View {
    @Bindable var viewModel: HistoryViewModel
    let repository: MealRepository
    let tabName: String
    
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(\.modelContext) private var modelContext
    @Environment(TheSDK.self) private var sdk
    
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activeDietPlans: [DietPlan]
    @State private var showingCreateDiet = false
    @State private var showingPaywall = false
    @State private var showingWelcome = false
    
    private var hasActiveDiet: Bool {
        !activeDietPlans.isEmpty
    }
    
    var body: some View {
        Group {
            if hasActiveDiet && isSubscribed {
                // Show enhanced diet summary when user has active diet and is subscribed
                EnhancedDietSummaryView()
                    .navigationTitle("My Diet")
            } else {
                // Show history with option to create diet
                HistoryViewWithDietOption(
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

struct HistoryViewWithDietOption: View {
    @Bindable var viewModel: HistoryViewModel
    let repository: MealRepository
    let isSubscribed: Bool
    let hasActiveDiet: Bool
    let onCreateDiet: () -> Void
    
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
            .navigationTitle("History")
            .background(Color(.systemGroupedBackground))
            .searchable(text: $searchText, prompt: "Search by date, day, or month")
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
            Text("Loading history...")
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
            
            Text("No History Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your meal history will appear here\nonce you start tracking")
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
            
            Text("No Results")
                .font(.title2)
                .fontWeight(.semibold)
            
            if !searchText.isEmpty {
                Text("No entries found for \"\(searchText)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No entries found for the selected time period")
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
                Text("Clear Filters")
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
                    Text(isSubscribed ? "Create Your Diet Plan" : "Unlock Diet Plans")
                        .font(.headline)
                    
                    Text(isSubscribed 
                        ? "Schedule repetitive meals and track adherence"
                        : "Subscribe to create diet plans with scheduled meals")
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
                    Text(isSubscribed ? "Create Diet Plan" : "Subscribe & Create")
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

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = HistoryViewModel(repository: repository)
    
    HistoryOrDietView(viewModel: viewModel, repository: repository, tabName: "History")
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self, Meal.self])
}

