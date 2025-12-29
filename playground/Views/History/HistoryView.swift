//
//  HistoryView.swift
//  playground
//
//  CalAI Clone - Meal history view with modern UI
//

import SwiftUI

struct HistoryView: View {

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
            .id("history-nav-\(localizationManager.currentLanguage)")
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
            Text(localizationManager.localizedString(for: "Loading history..."))
                .id("loading-history-\(localizationManager.currentLanguage)")
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
                .id("no-history-\(localizationManager.currentLanguage)")
                .font(.title2)
                .fontWeight(.semibold)

            Text(localizationManager.localizedString(for: AppStrings.History.historyDescription))
                .id("history-desc-\(localizationManager.currentLanguage)")
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
                .id("no-results-\(localizationManager.currentLanguage)")
                .font(.title2)
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

                    Text(
                        isSubscribed
                            ? "Schedule repetitive meals and track adherence"
                            : "Subscribe to create diet plans with scheduled meals"
                    )
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


// MARK: - Time Filter Enum

enum HistoryTimeFilter: String, CaseIterable {
    case week = "1W"
    case twoWeeks = "2W"
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "1Y"
    case all = "All"
    
    var displayName: String {
        switch self {
        case .week: return "Last 7 Days"
        case .twoWeeks: return "Last 2 Weeks"
        case .month: return "Last Month"
        case .threeMonths: return "Last 3 Months"
        case .sixMonths: return "Last 6 Months"
        case .year: return "Last Year"
        case .all: return "All Time"
        }
    }
    
    var shortName: String {
        return self.rawValue
    }
    
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .twoWeeks:
            return calendar.date(byAdding: .day, value: -14, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: now) ?? now
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .all:
            return calendar.date(byAdding: .year, value: -100, to: now) ?? now
        }
    }
}

// MARK: - Stats Summary Card

struct StatsSummaryCard: View {
    let daysCount: Int
    let totalMeals: Int
    let totalCalories: Int
    let averageCalories: Int
    let timeFilter: HistoryTimeFilter
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizationManager.localizedString(for: AppStrings.Home.summary))
                        .font(.headline)
                        .foregroundColor(.primary)
                        .id("summary-label-\(localizationManager.currentLanguage)")
                    
                    Text(timeFilter.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(.blue.opacity(0.7))
            }
            
            Divider()
            
            HStack(spacing: 0) {
                StatItem(value: "\(daysCount)", label: "Days", color: .blue)
                
                Divider()
                    .frame(height: 40)
                
                StatItem(value: "\(totalMeals)", label: "Meals", color: .green)
                
                Divider()
                    .frame(height: 40)
                
                StatItem(value: formatNumber(totalCalories), label: "Total Cal", color: .orange)
                
                Divider()
                    .frame(height: 40)
                
                StatItem(value: formatNumber(averageCalories), label: "Avg/Day", color: .purple)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 10000 {
            return String(format: "%.1fk", Double(number) / 1000)
        }
        return "\(number)"
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Day Summary Card

struct DaySummaryCard: View {
    let summary: DaySummary
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with date
            headerSection
            
            Divider()
                .padding(.horizontal)
            
            // Content
            contentSection
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(dateString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Meal count badge
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.caption)
                Text("\(summary.mealCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding()
    }
    
    private var contentSection: some View {
        HStack(spacing: 0) {
            // Calories - Primary focus
            caloriesSection
            
            // Vertical divider
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)
                .padding(.vertical, 12)
            
            // Macros
            macrosSection
        }
        .padding(.vertical, 12)
    }
    
    private var caloriesSection: some View {
        VStack(spacing: 4) {
            Text("\(summary.totalCalories)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("calories")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var macrosSection: some View {
        HStack(spacing: 16) {
            MacroPill(value: summary.totalProteinG, label: "Protein", color: .proteinColor)
            MacroPill(value: summary.totalCarbsG, label: "Carbs", color: .carbsColor)
            MacroPill(value: summary.totalFatG, label: "Fat", color: .fatColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Helper Properties
    
    private var dayName: String {
        if Calendar.current.isDateInToday(summary.date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(summary.date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: summary.date)
        }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: summary.date)
    }
}

// MARK: - Macro Pill

struct MacroPill: View {
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(value))g")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Helper Types

struct SelectedDate: Identifiable {
    let id = UUID()
    let date: Date
}

// MARK: - Filter Tag

struct FilterTag: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
    }
}

//#Preview {
//    let persistence = PersistenceController.shared
//    let repository = MealRepository(context: persistence.mainContext)
//    let viewModel = HistoryViewModel(repository: repository)
//    
//    HistoryView(viewModel: viewModel, repository: repository)
//}
