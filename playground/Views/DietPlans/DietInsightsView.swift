//
//  DietInsightsView.swift
//  playground
//
//  Deep insights and analytics for diet plans
//

import SwiftUI
import SwiftData
import Charts

struct DietInsightsView: View {
    let activePlans: [DietPlan]
    let repository: DietPlanRepository
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var insights: DietInsights?
    @State private var isLoading = true
    @State private var selectedPeriod: InsightPeriod = .month
    
    enum InsightPeriod: String, CaseIterable {
        case week = "Last Week"
        case month = "Last Month"
        case threeMonths = "Last 3 Months"
        
        var localizedKey: String {
            switch self {
            case .week: return AppStrings.Progress.last7Days
            case .month: return AppStrings.Progress.lastMonth
            case .threeMonths: return AppStrings.Progress.last3Months
            }
        }
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            Group {
                if isLoading {
                    ProgressView(localizationManager.localizedString(for: AppStrings.DietPlan.analyzingYourDiet))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id("analyzing-diet-\(localizationManager.currentLanguage)")
                } else if let insights = insights {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Period selector
                            Picker(localizationManager.localizedString(for: AppStrings.DietPlan.period), selection: $selectedPeriod) {
                                ForEach(InsightPeriod.allCases, id: \.self) { period in
                                    Text(localizationManager.localizedString(for: period.localizedKey)).tag(period)
                                }
                            }
                            .id("period-picker-\(localizationManager.currentLanguage)")
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            
                            // Overall score
                            overallScoreCard(insights: insights)
                            
                            // Adherence trend
                            adherenceTrendSection(insights: insights)
                            
                            // Meal completion by category
                            categoryCompletionSection(insights: insights)
                            
                            // Time-based patterns
                            timePatternsSection(insights: insights)
                            
                            // Recommendations
                            recommendationsSection(insights: insights)
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        localizationManager.localizedString(for: AppStrings.DietPlan.noInsightsAvailable),
                        systemImage: "chart.bar",
                        description: Text(localizationManager.localizedString(for: AppStrings.DietPlan.startFollowingDietPlan))
                    )
                    .id("no-insights-\(localizationManager.currentLanguage)")
                }
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.dietInsights))
                
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                        dismiss()
                    }
                }
            }
            .task {
                await loadInsights()
            }
            .onChange(of: selectedPeriod) { _, _ in
                Task {
                    await loadInsights()
                }
            }
        }
    }
    
    // MARK: - Overall Score Card
    
    private func overallScoreCard(insights: DietInsights) -> some View {
        VStack(spacing: 16) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.overallDietScore))
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("\(insights.overallScore)")
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(scoreColor(insights.overallScore))
            
            Text(scoreDescription(insights.overallScore))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Breakdown
            HStack(spacing: 20) {
                ScoreBreakdown(
                    label: localizationManager.localizedString(for: AppStrings.DietPlan.adherence),
                    value: Int(insights.avgAdherence * 100),
                    color: .green
                )
                
                ScoreBreakdown(
                    label: localizationManager.localizedString(for: AppStrings.DietPlan.consistency),
                    value: Int(insights.consistencyScore * 100),
                    color: .blue
                )
                
                ScoreBreakdown(
                    label: localizationManager.localizedString(for: AppStrings.DietPlan.planning),
                    value: Int(insights.planningScore * 100),
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private func scoreDescription(_ score: Int) -> String {
        switch score {
        case 80...100: return localizationManager.localizedString(for: AppStrings.DietPlan.excellentDoingGreat)
        case 60..<80: return localizationManager.localizedString(for: AppStrings.DietPlan.goodProgressKeepItUp)
        case 40..<60: return localizationManager.localizedString(for: AppStrings.DietPlan.roomForImprovement)
        default: return localizationManager.localizedString(for: AppStrings.DietPlan.letsGetBackOnTrack)
        }
    }
    
    // MARK: - Adherence Trend
    
    private func adherenceTrendSection(insights: DietInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.adherenceTrend))
                .font(.headline)
            
            Chart(insights.dailyAdherence) { day in
                LineMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Adherence", day.completionRate)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Adherence", day.completionRate)
                )
                .foregroundStyle(.blue.opacity(0.2))
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 200)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Category Completion
    
    private func categoryCompletionSection(insights: DietInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.completionByMealType))
                .font(.headline)
            
            ForEach(insights.categoryStats.sorted(by: { $0.completionRate > $1.completionRate }), id: \.category) { stat in
                CategoryStatRow(stat: stat)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Time Patterns
    
    private func timePatternsSection(insights: DietInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.timePatterns))
                .font(.headline)
            
            VStack(spacing: 12) {
                PatternCard(
                    icon: "clock.fill",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.bestTime),
                    value: insights.bestTimeSlot ?? "N/A",
                    color: .green
                )
                
                PatternCard(
                    icon: "calendar.badge.exclamationmark",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.mostChallengingDay),
                    value: insights.mostChallengingDay ?? "N/A",
                    color: .orange
                )
                
                PatternCard(
                    icon: "arrow.trending.up",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.improvementTrend),
                    value: insights.improvementTrend,
                    color: .blue
                )
            }
        }
    }
    
    // MARK: - Recommendations
    
    private func recommendationsSection(insights: DietInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.personalizedRecommendations))
                .font(.headline)
            
            ForEach(insights.recommendations, id: \.id) { recommendation in
                RecommendationCard(recommendation: recommendation)
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadInsights() async {
        isLoading = true
        defer { isLoading = false }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: endDate) ?? endDate
        
        var dailyAdherence: [DailyAdherence] = []
        var categoryStats: [CategoryStat] = []
        var timeSlotCompletions: [String: Int] = [:]
        var dayCompletions: [String: Int] = [:]
        
        var currentDate = startDate
        while currentDate <= endDate {
            do {
                let data = try repository.getDietAdherence(
                    for: currentDate,
                    activePlans: activePlans
                )
                
                dailyAdherence.append(DailyAdherence(
                    date: currentDate,
                    completionRate: data.completionRate,
                    completedMeals: data.completedMeals.count,
                    totalMeals: data.scheduledMeals.count,
                    goalAchievementRate: data.goalAchievementRate
                ))
                
                // Track by category
                for meal in data.scheduledMeals {
                    if categoryStats.first(where: { $0.category == meal.category }) == nil {
                        categoryStats.append(CategoryStat(
                            category: meal.category,
                            scheduled: 0,
                            completed: 0
                        ))
                    }
                    
                    if let index = categoryStats.firstIndex(where: { $0.category == meal.category }) {
                        categoryStats[index].scheduled += 1
                        if data.completedMeals.contains(meal.id) {
                            categoryStats[index].completed += 1
                        }
                    }
                }
                
                // Track by time slot
                for meal in data.scheduledMeals {
                    let hour = calendar.component(.hour, from: meal.time)
                    let timeSlot = hour < 12 ? localizationManager.localizedString(for: AppStrings.DietPlan.morning) : (hour < 17 ? localizationManager.localizedString(for: AppStrings.DietPlan.afternoon) : localizationManager.localizedString(for: AppStrings.DietPlan.evening))
                    timeSlotCompletions[timeSlot, default: 0] += data.completedMeals.contains(meal.id) ? 1 : 0
                }
                
                // Track by day of week
                let dayName = calendar.component(.weekday, from: currentDate)
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: localizationManager.currentLanguage)
                let dayNames = ["", formatter.shortWeekdaySymbols[0], formatter.shortWeekdaySymbols[1], formatter.shortWeekdaySymbols[2], formatter.shortWeekdaySymbols[3], formatter.shortWeekdaySymbols[4], formatter.shortWeekdaySymbols[5], formatter.shortWeekdaySymbols[6]]
                let dayKey = dayNames[dayName]
                dayCompletions[dayKey, default: 0] += data.completedMeals.count
                
            } catch {
                print("Failed to load insights for \(currentDate): \(error)")
            }
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        // Calculate insights
        let avgAdherence = dailyAdherence.isEmpty ? 0 : dailyAdherence.map { $0.completionRate }.reduce(0, +) / Double(dailyAdherence.count)
        
        // Consistency (variance in adherence)
        let variance = dailyAdherence.isEmpty ? 0 : dailyAdherence.map { pow($0.completionRate - avgAdherence, 2) }.reduce(0, +) / Double(dailyAdherence.count)
        let consistencyScore = max(0, min(1, 1 - variance))
        
        // Planning score (how many days had scheduled meals)
        let daysWithMeals = dailyAdherence.filter { $0.totalMeals > 0 }.count
        let planningScore = Double(daysWithMeals) / Double(dailyAdherence.count)
        
        // Overall score
        let overallScore = Int((avgAdherence * 0.5 + consistencyScore * 0.3 + planningScore * 0.2) * 100)
        
        // Best time slot
        let bestTimeSlot = timeSlotCompletions.max(by: { $0.value < $1.value })?.key
        
        // Most challenging day
        let mostChallengingDay = dayCompletions.min(by: { $0.value < $1.value })?.key
        
        // Improvement trend
        let improving = LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.improving)
        let declining = LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.declining)
        let stable = LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.stable)
        let insufficientData = LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.insufficientData)
        
        let improvement: String
        if dailyAdherence.count >= 14 {
            // Compare last 7 days with previous 7 days
            let recentAdherence = dailyAdherence.suffix(7).map { $0.completionRate }
            let olderAdherence = dailyAdherence.suffix(14).prefix(7).map { $0.completionRate }
            let recentAvg = recentAdherence.isEmpty ? 0 : recentAdherence.reduce(0, +) / Double(recentAdherence.count)
            let olderAvg = olderAdherence.isEmpty ? 0 : olderAdherence.reduce(0, +) / Double(olderAdherence.count)
            improvement = recentAvg > olderAvg ? improving : (recentAvg < olderAvg ? declining : stable)
        } else if dailyAdherence.count >= 7 {
            // Only 7 days of data - compare last 3 with first 3
            let recentAdherence = dailyAdherence.suffix(3).map { $0.completionRate }
            let olderAdherence = dailyAdherence.prefix(3).map { $0.completionRate }
            let recentAvg = recentAdherence.isEmpty ? 0 : recentAdherence.reduce(0, +) / Double(recentAdherence.count)
            let olderAvg = olderAdherence.isEmpty ? 0 : olderAdherence.reduce(0, +) / Double(olderAdherence.count)
            improvement = recentAvg > olderAvg ? improving : (recentAvg < olderAvg ? declining : stable)
        } else {
            improvement = insufficientData
        }
        
        // Generate recommendations
        var recommendations: [Recommendation] = []
        
        if avgAdherence < 0.7 {
            recommendations.append(Recommendation(
                id: UUID(),
                title: LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.improveAdherence),
                description: LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.adherenceBelow70),
                priority: .high,
                icon: "bell.fill"
            ))
        }
        
        if let worstCategory = categoryStats.min(by: { $0.completionRate < $1.completionRate }),
           worstCategory.completionRate < 0.6 {
            recommendations.append(Recommendation(
                id: UUID(),
                title: String(format: LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.focusOnCategory), worstCategory.category.displayName),
                description: String(format: LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.youAreMissing), worstCategory.category.displayName.lowercased()),
                priority: .medium,
                icon: worstCategory.category.icon
            ))
        }
        
        if consistencyScore < 0.7 {
            recommendations.append(Recommendation(
                id: UUID(),
                title: LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.buildConsistency),
                description: LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.adherenceVaries),
                priority: .medium,
                icon: "calendar.badge.clock"
            ))
        }
        
        if recommendations.isEmpty {
            recommendations.append(Recommendation(
                id: UUID(),
                title: LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.keepItUp),
                description: LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.doingGreatContinue),
                priority: .low,
                icon: "star.fill"
            ))
        }
        
        await MainActor.run {
            insights = DietInsights(
                overallScore: overallScore,
                avgAdherence: avgAdherence,
                consistencyScore: consistencyScore,
                planningScore: planningScore,
                dailyAdherence: dailyAdherence,
                categoryStats: categoryStats,
                bestTimeSlot: bestTimeSlot,
                mostChallengingDay: mostChallengingDay,
                improvementTrend: improvement,
                recommendations: recommendations
            )
        }
    }
}

// MARK: - Data Models

struct DietInsights {
    let overallScore: Int
    let avgAdherence: Double
    let consistencyScore: Double
    let planningScore: Double
    let dailyAdherence: [DailyAdherence]
    let categoryStats: [CategoryStat]
    let bestTimeSlot: String?
    let mostChallengingDay: String?
    let improvementTrend: String
    let recommendations: [Recommendation]
}

struct CategoryStat {
    let category: MealCategory
    var scheduled: Int
    var completed: Int
    
    var completionRate: Double {
        guard scheduled > 0 else { return 0 }
        return Double(completed) / Double(scheduled)
    }
}

struct Recommendation: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let priority: Priority
    let icon: String
    
    enum Priority {
        case high, medium, low
        
        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .blue
            }
        }
    }
}

// MARK: - Supporting Views

struct ScoreBreakdown: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CategoryStatRow: View {
    let stat: CategoryStat
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        HStack {
            Image(systemName: stat.category.icon)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(String(format: localizationManager.localizedString(for: AppStrings.DietPlan.completedOfScheduled), stat.completed, stat.scheduled))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .id("completed-stats-\(localizationManager.currentLanguage)")
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(stat.completionRate * 100))%")
                    .font(.headline)
                    .foregroundColor(completionColor(stat.completionRate))
                
                ProgressView(value: stat.completionRate)
                    .frame(width: 60)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func completionColor(_ rate: Double) -> Color {
        switch rate {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

struct PatternCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
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

struct RecommendationCard: View {
    let recommendation: Recommendation
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: recommendation.icon)
                .foregroundColor(recommendation.priority.color)
                .font(.title3)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recommendation.title)
                        .font(.headline)
                    
                    Spacer()
                    
                    Circle()
                        .fill(recommendation.priority.color)
                        .frame(width: 8, height: 8)
                }
                
                Text(recommendation.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    let container = try? ModelContainer(for: DietPlan.self)
    if let container = container {
        DietInsightsView(
            activePlans: [],
            repository: DietPlanRepository(context: container.mainContext)
        )
    } else {
        Text(LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.previewUnavailable))
    }
}

