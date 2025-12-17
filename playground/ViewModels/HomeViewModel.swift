//
//  HomeViewModel.swift
//  playground
//
//  View model for HomeView
//

import SwiftUI
import SwiftData

/// Represents a day in the week header
struct WeekDay: Identifiable {
    let id = UUID()
    let date: Date
    let dayName: String       // "Sun", "Mon", etc.
    let dayNumber: Int        // 1-31
    let isToday: Bool
    let progress: Double      // 0.0 to 1.0+ (calorie progress)
    let summary: DaySummary?
    
    /// Progress color based on calorie consumption
    var progressColor: Color {
        if progress > 1 {
            return .red
        } else if progress >= 0.8 {
            return .green
        } else if progress >= 0.5 {
            return .orange
        } else {
            return .black
        }
    }
}

/// View model managing home screen state and actions
@MainActor
@Observable
final class HomeViewModel {
    // MARK: - Dependencies
    private let repository: MealRepository
    private let imageStorage: ImageStorage
    
    // MARK: - State
    var todaysSummary: DaySummary?
    var recentMeals: [Meal] = []
    var weekDays: [WeekDay] = []
    var isLoading = false
    var error: Error?
    
    // MARK: - Error State
    var showError = false
    var errorMessage: String?
    
    init(
        repository: MealRepository,
        imageStorage: ImageStorage
    ) {
        self.repository = repository
        self.imageStorage = imageStorage
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        await fetchData()
    }

    func refreshTodayData() async {
        await fetchData()
    }

    private func fetchData() async {
        do {
            todaysSummary = try repository.fetchTodaySummary()
            recentMeals = try repository.fetchRecentMeals()
            
            // Fetch week summaries and build week days
            let weekSummaries = try repository.fetchCurrentWeekSummaries()
            weekDays = buildWeekDays(from: weekSummaries)
        } catch {
            self.error = error
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
    
    /// Build WeekDay array for the current week (Sun-Sat)
    private func buildWeekDays(from summaries: [Date: DaySummary]) -> [WeekDay] {
        let calendar = Calendar.current
        let today = Date()
        let calorieGoal = Double(UserSettings.shared.calorieGoal)
        
        // Get the start of the week (Sunday)
        let weekday = calendar.component(.weekday, from: today)
        guard let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: calendar.startOfDay(for: today)) else {
            return []
        }
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        
        var days: [WeekDay] = []
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else { continue }
            
            let dayStart = calendar.startOfDay(for: date)
            let summary = summaries[dayStart]
            let calories = Double(summary?.totalCalories ?? 0)
            let progress = calorieGoal > 0 ? calories / calorieGoal : 0
            
            let weekDay = WeekDay(
                date: date,
                dayName: dayFormatter.string(from: date),
                dayNumber: calendar.component(.day, from: date),
                isToday: calendar.isDateInToday(date),
                progress: progress,
                summary: summary
            )
            
            days.append(weekDay)
        }
        
        return days
    }

    // MARK: - Meal Management

    func deleteMeal(_ meal: Meal) async {
        do {
            // Delete associated image
            if let photoURL = meal.photoURL {
                imageStorage.deleteImage(at: photoURL)
            }

            try repository.deleteMeal(meal)
            await refreshTodayData()

            HapticManager.shared.notification(.success)
        } catch {
            self.error = error
            self.errorMessage = error.localizedDescription
            self.showError = true
            HapticManager.shared.notification(.error)
        }
    }

    // MARK: - Computed Properties
    
    var remainingCalories: Int {
        let goal = UserSettings.shared.calorieGoal
        let consumed = todaysSummary?.totalCalories ?? 0
        return max(0, goal - consumed)
    }
    
    var calorieProgress: Double {
        let goal = Double(UserSettings.shared.calorieGoal)
        let consumed = Double(todaysSummary?.totalCalories ?? 0)
        return consumed / goal
    }
}
