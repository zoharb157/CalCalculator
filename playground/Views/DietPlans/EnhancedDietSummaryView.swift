//
//  EnhancedDietSummaryView.swift
//  playground
//
//  Enhanced diet summary with better visualizations, trends, and insights
//

import SwiftUI
import SwiftData
import Charts

struct EnhancedDietSummaryView: View {
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activePlans: [DietPlan]
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var selectedDate = Date()
    @State private var selectedTimeRange: DietTimeRange = .week
    @State private var adherenceData: DietAdherenceData?
    @State private var weeklyAdherence: [DailyAdherence] = []
    @State private var isLoading = false
    @State private var showingInsights = false
    @State private var showingEditPlan = false
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time range selector
                    timeRangeSelector
                    
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
                .padding()
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.myDiet))
                
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
                    }
                }
            }
            .onChange(of: selectedDate) { _, _ in
                loadAdherenceData()
            }
            .onChange(of: selectedTimeRange) { _, _ in
                loadWeeklyAdherence()
            }
            .task {
                loadAdherenceData()
                loadWeeklyAdherence()
            }
            .sheet(isPresented: $showingInsights) {
                DietInsightsView(activePlans: activePlans, repository: dietPlanRepository)
            }
            .sheet(isPresented: $showingEditPlan) {
                if let plan = activePlans.first {
                    DietPlanEditorView(plan: plan, repository: dietPlanRepository)
                }
            }
        }
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return Picker(localizationManager.localizedString(for: AppStrings.DietPlan.timeRange), selection: $selectedTimeRange) {
            ForEach(DietTimeRange.allCases, id: \.self) { range in
                Text(localizationManager.localizedString(for: range.localizedKey))
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
        .id("time-range-picker-\(localizationManager.currentLanguage)")
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
    
    // MARK: - Trend Chart
    
    private var adherenceTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                // Create a meal from the scheduled meal template or basic meal
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
                
                // Save the meal
                let mealRepository = MealRepository(context: modelContext)
                try mealRepository.saveMeal(meal)
                
                // Mark reminder as completed
                if let reminder = try dietPlanRepository.fetchMealReminder(
                    by: scheduledMeal.id,
                    for: Date()
                ) {
                    try dietPlanRepository.updateMealReminderCompletion(reminder, completedMealId: meal.id)
                } else {
                    // Create new reminder if it doesn't exist
                    let reminder = MealReminder(
                        scheduledMealId: scheduledMeal.id,
                        reminderDate: Date(),
                        wasCompleted: true,
                        completedMealId: meal.id,
                        completedAt: Date()
                    )
                    try dietPlanRepository.saveMealReminder(reminder)
                }
                
                // Evaluate goal achievement if template exists
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
                
                // Reload data to reflect the change
                loadAdherenceData()
            } catch {
                print("Failed to complete meal: \(error)")
                HapticManager.shared.notification(.error)
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
    
    // MARK: - Weekly Stats
    
    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    .id("off-diet-calories-\(localizationManager.currentLanguage)")
                
                ForEach(data.offDietMeals.prefix(3), id: \.id) { meal in
                    OffDietMealRow(meal: meal)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadAdherenceData() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                adherenceData = try dietPlanRepository.getDietAdherence(
                    for: selectedDate,
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
        // Calculate consecutive days with perfect or good adherence
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for _ in 0..<30 { // Check last 30 days
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
                // If we can't load data for a day, break the streak
                break
            }
            
            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                break
            }
            currentDate = previousDate
        }
        
        return "\(streak) days"
    }
    
    private func bestDayString() -> String {
        guard let bestDay = weeklyAdherence.max(by: { $0.completionRate < $1.completionRate }) else {
            return "N/A"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: bestDay.date)
    }
    
    private func generateTip() -> String {
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
}

// MARK: - Supporting Views

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.headline)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ScheduledMealCard: View {
    let meal: ScheduledMeal
    let isCompleted: Bool
    let isMissed: Bool
    let goalAchieved: Bool
    let goalMissed: Bool
    var onTap: (() -> Void)? = nil
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return Button(action: {
            onTap?()
        }) {
            HStack(spacing: 12) {
                Image(systemName: meal.category.icon)
                    .foregroundColor(isCompleted ? .green : (isMissed ? .red : .gray))
                    .font(.title3)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Label(meal.formattedTime, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if isCompleted && goalMissed {
                            Text(localizationManager.localizedString(for: AppStrings.DietPlan.goalNotMet))
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                                .id("goal-not-met-\(localizationManager.currentLanguage)")
                        }
                    }
                }
                
                Spacer()
                
                if isCompleted {
                    if goalAchieved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if goalMissed {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                } else if isMissed {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                } else {
                    // Show tap indicator for incomplete meals
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(isCompleted) // Disable if already completed
    }
}

struct InsightCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct DietStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct OffDietMealRow: View {
    let meal: Meal
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(meal.totalCalories) \(localizationManager.localizedString(for: AppStrings.DietPlan.calories))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .id("meal-calories-\(localizationManager.currentLanguage)")
            }
            
            Spacer()
            
            Text(meal.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct DailyAdherence: Identifiable {
    let id = UUID()
    let date: Date
    let completionRate: Double
    let completedMeals: Int
    let totalMeals: Int
    let goalAchievementRate: Double
}

#Preview {
    EnhancedDietSummaryView()
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self])
}

