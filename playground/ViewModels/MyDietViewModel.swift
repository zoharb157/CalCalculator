//
//  MyDietViewModel.swift
//  playground
//
//  ViewModel for the standalone My Diet tab
//

import SwiftUI
import SwiftData

/// View model managing diet summary screen state and actions
@MainActor
@Observable
final class MyDietViewModel {
    // MARK: - Dependencies
    private var modelContext: ModelContext?
    
    // MARK: - State
    var selectedDate = Date()
    var selectedTimeRange: DietTimeRange = .week
    var adherenceData: DietAdherenceData?
    var weeklyAdherence: [DailyAdherence] = []
    var isLoading = false
    var error: Error?
    var showError = false
    
    // MARK: - Active Plans (passed from view)
    var activePlans: [DietPlan] = []
    
    // MARK: - Computed Properties
    
    private var dietPlanRepository: DietPlanRepository? {
        guard let context = modelContext else { return nil }
        return DietPlanRepository(context: context)
    }
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Configuration
    
    func configure(modelContext: ModelContext, activePlans: [DietPlan]) {
        self.modelContext = modelContext
        self.activePlans = activePlans
    }
    
    // MARK: - Data Loading
    
    func loadAdherenceData() async {
        guard let repository = dietPlanRepository else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            adherenceData = try repository.getDietAdherence(
                for: selectedDate,
                activePlans: activePlans
            )
        } catch {
            self.error = error
            self.showError = true
            print("Failed to load adherence data: \(error)")
        }
    }
    
    func loadWeeklyAdherence() async {
        guard let repository = dietPlanRepository else { return }
        
        let calendar = Calendar.current
        let startDate = selectedTimeRange.startDate
        let endDate = Date()
        
        var adherence: [DailyAdherence] = []
        
        var currentDate = startDate
        while currentDate <= endDate {
            do {
                let data = try repository.getDietAdherence(
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
        
        weeklyAdherence = adherence
    }
    
    func loadAllData() async {
        await loadAdherenceData()
        await loadWeeklyAdherence()
    }
    
    // MARK: - Meal Completion
    
    func completeMeal(_ scheduledMeal: ScheduledMeal) async {
        guard let context = modelContext,
              let repository = dietPlanRepository else { return }
        
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
            
            let mealRepository = MealRepository(context: context)
            try mealRepository.saveMeal(meal)
            
            if let reminder = try repository.fetchMealReminder(
                by: scheduledMeal.id,
                for: Date()
            ) {
                try repository.updateMealReminderCompletion(reminder, completedMealId: meal.id)
            } else {
                let reminder = MealReminder(
                    scheduledMealId: scheduledMeal.id,
                    reminderDate: Date(),
                    wasCompleted: true,
                    completedMealId: meal.id,
                    completedAt: Date()
                )
                try repository.saveMealReminder(reminder)
            }
            
            if scheduledMeal.mealTemplate != nil {
                let (achieved, deviation) = repository.evaluateMealGoalAchievement(
                    actualMeal: meal,
                    scheduledMeal: scheduledMeal
                )
                if let reminder = try repository.fetchMealReminder(
                    by: scheduledMeal.id,
                    for: Date()
                ) {
                    try repository.updateMealReminderGoalAchievement(
                        reminder,
                        goalAchieved: achieved,
                        goalDeviation: deviation
                    )
                }
            }
            
            HapticManager.shared.notification(.success)
            await loadAdherenceData()
        } catch {
            print("Failed to complete meal: \(error)")
            HapticManager.shared.notification(.error)
        }
    }
    
    // MARK: - Helper Functions
    
    func calculateStreak() -> String {
        guard let repository = dietPlanRepository else { return "0 days" }
        
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for _ in 0..<30 {
            do {
                let data = try repository.getDietAdherence(
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
        
        return "\(streak) days"
    }
    
    func bestDayString() -> String {
        guard let bestDay = weeklyAdherence.max(by: { $0.completionRate < $1.completionRate }) else {
            return "N/A"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: bestDay.date)
    }
    
    func generateTip() -> String {
        let localizationManager = LocalizationManager.shared
        
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
    
    func adherenceColor(_ rate: Double) -> Color {
        switch rate {
        case 0.9...1.0: return .green
        case 0.7..<0.9: return .orange
        default: return .red
        }
    }
}
