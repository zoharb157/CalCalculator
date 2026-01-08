//
//  HomeViewModel.swift
//  playground
//
//  View model for HomeView
//

import SwiftUI
import SwiftData
import ActivityKit

/// Represents a single day in the week header
/// Contains all data needed to display a day in the scrollable week days header
struct WeekDay: Identifiable {
    let id = UUID()
    let date: Date
    let dayName: String       // Localized day name (e.g., "Sun", "Mon", etc.)
    let dayNumber: Int        // Day of month (1-31)
    let isToday: Bool         // Whether this day is today
    let isSelected: Bool      // Whether this day is currently selected by the user
    let progress: Double      // Calorie progress (0.0 to 1.0+, can exceed 1.0 if over goal)
    let summary: DaySummary?  // Optional day summary containing meal and calorie data
    let caloriesConsumed: Int // Total calories consumed on this day
    let calorieGoal: Int      // Calorie goal for this day
    let hasMeals: Bool        // Whether any meals were logged on this day
    
    /// Calories consumed over the daily goal
    /// Returns 0 if under goal, otherwise returns the excess amount
    var caloriesOverGoal: Int {
        max(0, caloriesConsumed - calorieGoal)
    }
    
    /// Whether the progress ring should be dotted (no meals logged)
    /// Dotted rings indicate days with no logged meals
    var isDotted: Bool {
        !hasMeals
    }
    
    /// Progress ring color based on calories over goal
    /// - Green: Less than 100 calories over goal (0-99 over)
    /// - Yellow: 100-200 calories over goal (moderately over)
    /// - Red: More than 200 calories over goal (significantly over)
    /// - Gray: No meals logged (used with dotted ring)
    var progressColor: Color {
        if !hasMeals {
            return .gray
        }
        
        switch caloriesOverGoal {
        case 0..<100:
            return .green
        case 100...200:
            return .yellow
        default:
            return .red
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
    var isInitialLoad = true // Track if this is the first load
    var hasDataLoaded = false // Track if data has been loaded for animations
    var error: Error?
    
    // MARK: - Selected Day State
    /// Currently selected date in the week header (defaults to today)
    var selectedDate: Date = Date()
    
    // MARK: - Burned/Rollover Calories State
    /// Today's burned calories (cached for performance)
    var todaysBurnedCalories: Int = 0
    /// Burned calories for the currently selected date (used when viewing historical dates)
    var selectedDateBurnedCalories: Int = 0
    /// Exercise count for the currently selected date (used when viewing historical dates)
    var selectedDateExercisesCount: Int = 0
    /// Rollover calories from yesterday (unused calories that carry over to today)
    var rolloverCaloriesFromYesterday: Int = 0
    
    // MARK: - Error State
    var showError = false
    var errorMessage: String?
    
    // MARK: - UserDefaults Keys
    /// Keys for persisting rollover and burned calories between app launches
    /// These ensure data persists even when the app is closed and reopened
    private let rolloverCaloriesKey = "rolloverCalories_lastDate"
    private let rolloverCaloriesAmountKey = "rolloverCalories_amount"
    private let burnedCaloriesKey = "burnedCalories_lastDate"
    private let burnedCaloriesAmountKey = "burnedCalories_amount"
    
    init(
        repository: MealRepository,
        imageStorage: ImageStorage
    ) {
        self.repository = repository
        self.imageStorage = imageStorage
        // Initialize with placeholder week days so header appears immediately
        // This prevents layout shift when data loads asynchronously
        self.weekDays = buildPlaceholderWeekDays()
        // Load cached burned calories immediately (before async fetch)
        // This provides instant UI feedback while data loads
        loadCachedBurnedCalories()
    }
    
    /// Builds placeholder week days structure (appears immediately, data fills in later)
    /// Creates WeekDay entries with zero values that will be updated when real data loads
    /// This ensures the UI structure is ready before async data operations complete
    private func buildPlaceholderWeekDays() -> [WeekDay] {
        let calendar = Calendar.current
        let today = Date()
        
        // Start from today only (as requested: "בחלון של הימים להתחיל רק מהיום הנוכחי")
        let startOfRange = calendar.startOfDay(for: today)
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        dayFormatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage)
        
        return (0..<21).map { dayOffset -> WeekDay in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfRange) else {
                // Fallback to today if date calculation fails
                return WeekDay(
                    date: today,
                    dayName: dayFormatter.string(from: today),
                    dayNumber: calendar.component(.day, from: today),
                    isToday: true,
                    isSelected: calendar.isDateInToday(selectedDate),
                    progress: 0.0,
                    summary: nil,
                    caloriesConsumed: 0,
                    calorieGoal: 0,
                    hasMeals: false
                )
            }
            
            return WeekDay(
                date: date,
                dayName: dayFormatter.string(from: date),
                dayNumber: calendar.component(.day, from: date),
                isToday: calendar.isDateInToday(date),
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                progress: 0.0, // Placeholder - will be updated when data loads
                summary: nil, // Placeholder - will be updated when data loads
                caloriesConsumed: 0, // Placeholder
                calorieGoal: 0, // Placeholder
                hasMeals: false // Placeholder - will show dotted ring
            )
        }
    }
    
    // MARK: - Data Loading
    
    /// Loads all home screen data with optimized loading strategy
    /// Critical data (today's summary, meals) loads first for immediate UI display
    /// Background data (week summaries, exercises) loads asynchronously without blocking
    func loadData() async {
        let startTime = Date()
        print("🟢 [HomeViewModel] loadData() started")
        
        // Mark that we're loading (UI can show immediately with empty state)
        // This allows the view to render while data is being fetched
        isInitialLoad = true
        
        // Load critical data first (today's summary and recent meals) - show UI immediately
        // This ensures users see content as quickly as possible
        await loadCriticalData()
        
        let criticalDataTime = Date().timeIntervalSince(startTime)
        print("🟢 [HomeViewModel] Critical data loaded in \(String(format: "%.3f", criticalDataTime))s")
        
        // Mark initial load complete (allows animations and transitions)
        isInitialLoad = false
        
        // Load less critical data in background (non-blocking)
        // Week summaries and exercises can load progressively without blocking the UI
        Task { @MainActor in
            await self.loadBackgroundData()
        }
    }

    /// Refreshes today's data, invalidating cache if the day has changed
    /// Called when user pulls to refresh or when data needs to be updated
    func refreshTodayData() async {
        let startTime = Date()
        print("🟢 [HomeViewModel] refreshTodayData() started")
        
        // Check if day changed and invalidate cache if needed
        // This ensures burned calories cache is cleared when a new day starts
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let lastCachedDate = UserDefaults.standard.object(forKey: burnedCaloriesKey) as? Date,
           !calendar.isDate(lastCachedDate, inSameDayAs: today) {
            // Day changed - clear old cache to prevent stale data
            todaysBurnedCalories = 0
            UserDefaults.standard.removeObject(forKey: burnedCaloriesKey)
            UserDefaults.standard.removeObject(forKey: burnedCaloriesAmountKey)
        }
        
        await fetchData()
        let elapsed = Date().timeIntervalSince(startTime)
        print("🟢 [HomeViewModel] refreshTodayData() completed in \(String(format: "%.3f", elapsed))s")
    }
    
    /// Selects a specific date and loads its data
    /// Updates the week days header to reflect the selection and loads data for that date
    /// - Parameter date: The date to select (will be normalized to start of day)
    func selectDay(_ date: Date) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Only reload if date actually changed (prevents unnecessary work)
        if !calendar.isDate(selectedDate, inSameDayAs: normalizedDate) {
            selectedDate = normalizedDate
            
            // Update week days to reflect new selection
            Task { @MainActor in
                // Rebuild week days with new selected date (fetch 3 weeks for scrolling)
                // This updates the visual selection indicator in the week header
                if let weekSummaries = try? repository.fetchWeekSummaries() {
                    let newWeekDays = buildWeekDays(from: weekSummaries, selectedDate: selectedDate)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        weekDays = newWeekDays
                    }
                }
                
                // Load data for the newly selected date
                await loadDataForSelectedDate()
            }
        }
    }
    
    /// Loads data for the currently selected date
    /// Fetches summary, meals, and exercises for the selected date
    /// Uses different methods for today vs historical dates for optimal performance
    private func loadDataForSelectedDate() async {
        let startTime = Date()
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: selectedDate)
        let isToday = calendar.isDateInToday(targetDate)
        
        print("🟢 [HomeViewModel] loadDataForSelectedDate() started for: \(selectedDate) (normalized: \(targetDate), isToday: \(isToday))")
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load summary for selected date - use appropriate method based on whether it's today
            // fetchTodaySummary() is optimized for today's data, fetchDaySummary() for historical dates
            let summary: DaySummary?
            if isToday {
                summary = try repository.fetchTodaySummary()
            } else {
                summary = try repository.fetchDaySummary(for: targetDate)
            }
            todaysSummary = summary
            
            // Load meals for selected date (normalized to start of day)
            // Sorted by timestamp descending (most recent first)
            let meals = try repository.fetchMeals(for: targetDate)
            recentMeals = meals.sorted { $0.timestamp > $1.timestamp }
            
            // Load exercises for selected date and calculate burned calories
            let exercises = try repository.fetchExercises(for: targetDate)
            let burned = exercises.reduce(0) { $0 + $1.calories }
            selectedDateBurnedCalories = burned
            selectedDateExercisesCount = exercises.count
            
            // Update UI with animation to provide smooth transition
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                hasDataLoaded = true
            }
            
            let totalTime = Date().timeIntervalSince(startTime)
            print("🟢 [HomeViewModel] loadDataForSelectedDate() completed in \(String(format: "%.3f", totalTime))s")
            print("🟢 [HomeViewModel] Loaded \(meals.count) meals, summary calories: \(summary?.totalCalories ?? 0) for date: \(targetDate)")
        } catch {
            let totalTime = Date().timeIntervalSince(startTime)
            print("🔴 [HomeViewModel] loadDataForSelectedDate() failed after \(String(format: "%.3f", totalTime))s: \(error)")
            self.error = error
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
    
    /// Loads critical data needed for initial UI display
    /// This data must be available immediately for the view to render properly
    /// Uses parallel async/await for optimal performance
    private func loadCriticalData() async {
        let startTime = Date()
        print("🔵 [HomeViewModel] loadCriticalData() started")
        
        // Load rollover calories immediately (fast - UserDefaults, non-blocking)
        // This is synchronous and doesn't require database access
        loadRolloverCalories()
        
        // SwiftData requires main thread, but we can run queries in parallel using async let
        // Use Task with @MainActor to allow true parallelism while staying on main thread
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            do {
                // Load summary, meals, and exercises for selected date in parallel
                // This maximizes performance by fetching all data simultaneously
                let calendar = Calendar.current
                let targetDate = calendar.startOfDay(for: self.selectedDate)
                let isToday = calendar.isDateInToday(targetDate)
                
                async let summaryTask = isToday 
                    ? try repository.fetchTodaySummary()
                    : try repository.fetchDaySummary(for: targetDate)
                async let mealsTask = try repository.fetchMeals(for: targetDate)
                async let exercisesTask = try repository.fetchExercises(for: targetDate)
                
                // Wait for all parallel tasks to complete
                let summary = try await summaryTask
                let meals = try await mealsTask
                let exercises = try await exercisesTask
                
                // Calculate burned calories and count for selected date
                let burned = exercises.reduce(0) { $0 + $1.calories }
                self.selectedDateBurnedCalories = burned
                self.selectedDateExercisesCount = exercises.count
                
                // Update UI with animation to provide smooth transition
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.todaysSummary = summary
                    self.recentMeals = meals.sorted { $0.timestamp > $1.timestamp }
                    self.hasDataLoaded = true
                }
                
                // Update Live Activity if enabled (only for today, not historical dates)
                if isToday {
                    self.updateLiveActivityIfNeeded()
                }
                
                let totalTime = Date().timeIntervalSince(startTime)
                print("🟢 [HomeViewModel] loadCriticalData() completed in \(String(format: "%.3f", totalTime))s")
            } catch {
                let totalTime = Date().timeIntervalSince(startTime)
                print("🔴 [HomeViewModel] loadCriticalData() failed after \(String(format: "%.3f", totalTime))s: \(error)")
                self.error = error
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
        
        // Return immediately - UI shows with empty state while data loads in background
        // This provides instant feedback to the user
        print("🟢 [HomeViewModel] loadCriticalData() returned immediately (loading in background)")
    }
    
    /// Loads background data that can be displayed progressively
    /// This data is less critical and can load after the initial UI is shown
    /// Includes week summaries for the week header and today's exercises
    private func loadBackgroundData() async {
        let startTime = Date()
        print("🟡 [HomeViewModel] loadBackgroundData() started")
        
        // SwiftData requires main thread, but we can run queries in parallel using async let
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            do {
                // Fetch week summaries and exercises in parallel (both on main thread but truly parallel)
                // Fetch 3 weeks of data for scrollable week days header
                async let weekSummariesTask = try repository.fetchWeekSummaries()
                async let exercisesTask = try repository.fetchTodaysExercises()
                
                // Wait for both parallel tasks to complete
                let weekSummaries = try await weekSummariesTask
                let exercises = try await exercisesTask
                let burned = exercises.reduce(0) { $0 + $1.calories }
                
                // Update burned calories and cache it for persistence
                self.todaysBurnedCalories = burned
                self.cacheBurnedCalories(burned)
                
                // Build week days and calculate rollover (fast operations, no database access)
                let newWeekDays = self.buildWeekDays(from: weekSummaries, selectedDate: self.selectedDate)
                self.calculateAndStoreRollover(weekSummaries: weekSummaries)
                
                // Update UI with animation to provide smooth transition
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.weekDays = newWeekDays
                }
                
                let totalTime = Date().timeIntervalSince(startTime)
                print("🟢 [HomeViewModel] loadBackgroundData() completed in \(String(format: "%.3f", totalTime))s")
            } catch {
                print("  ⚠️ [HomeViewModel] Failed to load background data: \(error)")
                // Don't show error for background data - it's not critical for initial display
                // The UI can function without this data, it just won't show week progress initially
            }
        }
    }

    private func fetchData() async {
        let startTime = Date()
        print("🟢 [HomeViewModel] fetchData() started")
        
        do {
            let summaryStart = Date()
            todaysSummary = try repository.fetchTodaySummary()
            print("  ✅ Today's summary: \(Date().timeIntervalSince(summaryStart))s")
            
            let mealsStart = Date()
            recentMeals = try repository.fetchRecentMeals()
            print("  ✅ Recent meals: \(Date().timeIntervalSince(mealsStart))s")
            
            // Fetch week summaries and build week days (3 weeks for scrolling)
            let weekStart = Date()
            let weekSummaries = try repository.fetchWeekSummaries()
            print("  ✅ Week summaries: \(Date().timeIntervalSince(weekStart))s")
            
            let buildStart = Date()
            weekDays = buildWeekDays(from: weekSummaries, selectedDate: selectedDate)
            print("  ✅ Week days built: \(Date().timeIntervalSince(buildStart))s")
            
            // Fetch burned calories for today
            let burnedStart = Date()
            await fetchTodaysBurnedCalories()
            print("  ✅ Burned calories: \(Date().timeIntervalSince(burnedStart))s")
            
            // Load rollover calories
            let rolloverStart = Date()
            loadRolloverCalories()
            print("  ✅ Rollover loaded: \(Date().timeIntervalSince(rolloverStart))s")
            
            // Calculate and store rollover for tomorrow (based on yesterday's data)
            let rolloverCalcStart = Date()
            calculateAndStoreRollover(weekSummaries: weekSummaries)
            print("  ✅ Rollover calculated: \(Date().timeIntervalSince(rolloverCalcStart))s")
            
            let totalTime = Date().timeIntervalSince(startTime)
            print("🟢 [HomeViewModel] fetchData() completed in \(String(format: "%.3f", totalTime))s")
        } catch {
            let totalTime = Date().timeIntervalSince(startTime)
            print("🔴 [HomeViewModel] fetchData() failed after \(String(format: "%.3f", totalTime))s: \(error)")
            self.error = error
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
    
    // MARK: - Burned Calories
    
    /// Loads cached burned calories from UserDefaults (for immediate display on app start)
    /// This provides instant UI feedback while the database query runs in the background
    /// Cache is validated to ensure it's for today before using it
    private func loadCachedBurnedCalories() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check if burned calories were cached for today
        if let lastCachedDate = defaults.object(forKey: burnedCaloriesKey) as? Date {
            if calendar.isDate(lastCachedDate, inSameDayAs: today) {
                // Use cached value if it's for today (valid cache)
                todaysBurnedCalories = defaults.integer(forKey: burnedCaloriesAmountKey)
                print("✅ [HomeViewModel] Loaded cached burned calories: \(todaysBurnedCalories) cal")
            } else {
                // Cache is for a different day, clear it to prevent stale data
                todaysBurnedCalories = 0
                defaults.removeObject(forKey: burnedCaloriesKey)
                defaults.removeObject(forKey: burnedCaloriesAmountKey)
            }
        } else {
            // No cache available - will be populated when data loads
            todaysBurnedCalories = 0
        }
    }
    
    /// Caches today's burned calories to UserDefaults for persistence between app runs
    /// This ensures burned calories are available immediately on next app launch
    /// - Parameter calories: The burned calories amount to cache
    private func cacheBurnedCalories(_ calories: Int) {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Store both the date and amount for validation on next load
        defaults.set(today, forKey: burnedCaloriesKey)
        defaults.set(calories, forKey: burnedCaloriesAmountKey)
    }
    
    /// Fetches today's burned calories from the database
    /// Note: This is now handled in loadBackgroundData() directly for better performance
    /// Keeping for compatibility but it's called from background thread
    private func fetchTodaysBurnedCalories() async {
        // Implementation moved to loadBackgroundData() for better code organization
    }
    
    // MARK: - Rollover Calories
    
    /// Loads rollover calories from UserDefaults
    /// Rollover calories are unused calories from yesterday that carry over to today
    /// Only valid if stored date is yesterday (expires after one day)
    private func loadRolloverCalories() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check if rollover was stored for yesterday (meaning it applies to today)
        if let lastStoredDate = defaults.object(forKey: rolloverCaloriesKey) as? Date {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            
            // If the stored date is yesterday, use the rollover amount
            // This ensures rollover only applies for one day
            if calendar.isDate(lastStoredDate, inSameDayAs: yesterday) {
                rolloverCaloriesFromYesterday = defaults.integer(forKey: rolloverCaloriesAmountKey)
            } else {
                // Rollover expired (more than 1 day old) - don't use it
                rolloverCaloriesFromYesterday = 0
            }
        } else {
            // No rollover stored - user didn't have unused calories yesterday
            rolloverCaloriesFromYesterday = 0
        }
    }
    
    /// Calculates and stores rollover calories based on yesterday's unused calories
    /// Rollover is capped at 200 calories maximum to prevent excessive calorie accumulation
    /// - Parameter weekSummaries: Dictionary of day summaries used to find yesterday's data
    private func calculateAndStoreRollover(weekSummaries: [Date: DaySummary]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get yesterday's summary to calculate unused calories
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let yesterdaySummary = weekSummaries[calendar.startOfDay(for: yesterday)] else {
            // No yesterday data available - can't calculate rollover
            return
        }
        
        let calorieGoal = UserSettings.shared.calorieGoal
        let yesterdayConsumed = yesterdaySummary.totalCalories
        let unused = calorieGoal - yesterdayConsumed
        
        // Cap rollover at 200 calories max to prevent excessive calorie accumulation
        // Only positive unused calories roll over (if over goal, no rollover)
        let rolloverAmount = min(200, max(0, unused))
        
        // Store for today to use (stored with yesterday's date for validation)
        let defaults = UserDefaults.standard
        defaults.set(yesterday, forKey: rolloverCaloriesKey)
        defaults.set(rolloverAmount, forKey: rolloverCaloriesAmountKey)
        
        rolloverCaloriesFromYesterday = rolloverAmount
    }
    
    /// Builds WeekDay array for multiple weeks (scrollable week header)
    /// Builds 3 weeks total: 1 week before today, current week, 1 week after today
    /// This provides enough data for smooth scrolling in the week header
    /// - Parameters:
    ///   - summaries: Dictionary of day summaries keyed by date
    ///   - selectedDate: The currently selected date (affects isSelected property)
    /// Builds week days array starting from the first day of app installation (onboarding completion date)
    /// Shows all days from the first day of installation until today, plus 1 week forward from today
    /// Even if there's no data for some days, they will still be displayed
    /// - Parameters:
    ///   - summaries: Dictionary of day summaries keyed by date
    ///   - selectedDate: The currently selected date (affects isSelected property)
    /// - Returns: Array of WeekDay structs ready for display, sorted by date (oldest first)
    func buildWeekDays(from summaries: [Date: DaySummary], selectedDate: Date) -> [WeekDay] {
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        let calorieGoalValue = effectiveCalorieGoal
        let calorieGoalDouble = Double(calorieGoalValue)
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        dayFormatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage)
        
        var days: [WeekDay] = []
        
        // Get the first day of app installation (onboarding completion date)
        let settings = UserSettings.shared
        let firstDayStart: Date
        
        if let onboardingDate = settings.onboardingCompletedDate {
            // Start from the day onboarding was completed (first day of app installation)
            firstDayStart = calendar.startOfDay(for: onboardingDate)
        } else {
            // Fallback: if onboarding date is not set, use today
            firstDayStart = todayStart
        }
        
        // Calculate end date: today + 1 week forward
        guard let endDate = calendar.date(byAdding: .day, value: 7, to: todayStart) else {
            // Fallback: just show today if date calculation fails
            let weekDay = WeekDay(
                date: today,
                dayName: dayFormatter.string(from: today),
                dayNumber: calendar.component(.day, from: today),
                isToday: true,
                isSelected: calendar.isDate(today, inSameDayAs: selectedDate),
                progress: 0,
                summary: nil,
                caloriesConsumed: 0,
                calorieGoal: calorieGoalValue,
                hasMeals: false
            )
            return [weekDay]
        }
        
        // Build days from the first day of installation until today + 1 week forward
        // This includes all days, even if there's no data for them
        var currentDate = firstDayStart
        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            let summary = summaries[dayStart] // May be nil if no data exists for this day
            let caloriesConsumed = summary?.totalCalories ?? 0
            let caloriesDouble = Double(caloriesConsumed)
            let progress = calorieGoalDouble > 0 ? caloriesDouble / calorieGoalDouble : 0
            let hasMeals = (summary?.mealCount ?? 0) > 0
            
            let weekDay = WeekDay(
                date: currentDate,
                dayName: dayFormatter.string(from: currentDate),
                dayNumber: calendar.component(.day, from: currentDate),
                isToday: calendar.isDateInToday(currentDate),
                isSelected: calendar.isDate(currentDate, inSameDayAs: selectedDate),
                progress: progress,
                summary: summary,
                caloriesConsumed: caloriesConsumed,
                calorieGoal: calorieGoalValue,
                hasMeals: hasMeals
            )
            
            days.append(weekDay)
            
            // Move to next day
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return days
    }

    // MARK: - Meal Management

    /// Deletes a meal and its associated image, then refreshes today's data
    /// Also updates Live Activity if enabled
    /// - Parameter meal: The meal to delete
    func deleteMeal(_ meal: Meal) async {
        do {
            // Delete associated image from storage
            // This prevents orphaned image files from accumulating
            if let photoURL = meal.photoURL {
                imageStorage.deleteImage(at: photoURL)
            }

            try repository.deleteMeal(meal)
            await refreshTodayData()
            
            // Update Live Activity to reflect the deleted meal
            updateLiveActivityIfNeeded()

            HapticManager.shared.notification(.success)
        } catch {
            self.error = error
            self.errorMessage = error.localizedDescription
            self.showError = true
            HapticManager.shared.notification(.error)
        }
    }
    
    // MARK: - Exercise Management
    
    /// Refreshes today's burned calories from the database
    /// Called when exercises are added/removed to update the calorie goal adjustment
    /// Also updates selected date burned calories if viewing today
    func refreshBurnedCalories() async {
        do {
            let calendar = Calendar.current
            let isToday = calendar.isDateInToday(selectedDate)
            
            if isToday {
                // If viewing today, update both today's and selected date's burned calories
                let exercises = try repository.fetchTodaysExercises()
                let burned = exercises.reduce(0) { $0 + $1.calories }
                await MainActor.run {
                    self.todaysBurnedCalories = burned
                    self.selectedDateBurnedCalories = burned
                    self.selectedDateExercisesCount = exercises.count
                    self.cacheBurnedCalories(burned) // Cache for persistence
                    print("✅ [HomeViewModel] Refreshed burned calories: \(burned) cal")
                }
            } else {
                // If viewing a different date, update that date's burned calories
                let targetDate = calendar.startOfDay(for: selectedDate)
                let exercises = try repository.fetchExercises(for: targetDate)
                let burned = exercises.reduce(0) { $0 + $1.calories }
                await MainActor.run {
                    self.selectedDateBurnedCalories = burned
                    self.selectedDateExercisesCount = exercises.count
                    print("✅ [HomeViewModel] Refreshed burned calories for selected date: \(burned) cal")
                }
            }
        } catch {
            print("⚠️ [HomeViewModel] Failed to refresh burned calories: \(error)")
        }
    }
    
    // MARK: - Live Activity
    
    /// Updates Live Activity if it's enabled in user preferences
    /// Live Activity displays calorie and macro progress on the Lock Screen and Dynamic Island
    /// Only updates if the feature is enabled and available on the device
    func updateLiveActivityIfNeeded() {
        // Check if Live Activity is enabled in user preferences
        guard UserProfileRepository.shared.getLiveActivity() else {
            // If disabled, end any active activity to clean up
            if #available(iOS 16.1, *) {
                LiveActivityManager.shared.endActivity()
            }
            return
        }
        
        // Check if ActivityKit is available (requires iOS 16.1+)
        guard #available(iOS 16.1, *) else {
            return
        }
        
        guard LiveActivityManager.shared.isAvailable else {
            print("⚠️ [HomeViewModel] Live Activity is not available on this device")
            return
        }
        
        // Get current nutrition data from today's summary
        let summary = todaysSummary
        let caloriesConsumed = summary?.totalCalories ?? 0
        let calorieGoal = effectiveCalorieGoal // Includes burned calories and rollover if enabled
        let proteinG = summary?.totalProteinG ?? 0
        let carbsG = summary?.totalCarbsG ?? 0
        let fatG = summary?.totalFatG ?? 0
        
        // Get macro goals from user settings
        let settings = UserSettings.shared
        let proteinGoal = settings.proteinGoal
        let carbsGoal = settings.carbsGoal
        let fatGoal = settings.fatGoal
        
        // Update Live Activity with current nutrition data
        LiveActivityManager.shared.updateActivity(
            caloriesConsumed: caloriesConsumed,
            calorieGoal: calorieGoal,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            proteinGoal: proteinGoal,
            carbsGoal: carbsGoal,
            fatGoal: fatGoal
        )
    }

    // MARK: - Computed Properties
    
    /// Base calorie goal from user settings (without any adjustments)
    var baseCalorieGoal: Int {
        UserSettings.shared.calorieGoal
    }
    
    /// Effective calorie goal accounting for burned and rollover calories
    /// This is the actual goal displayed to the user (base + adjustments)
    /// Uses selected date's burned calories when viewing different dates
    var effectiveCalorieGoal: Int {
        var goal = baseCalorieGoal
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(selectedDate)
        
        // Add burned calories if setting is enabled
        // Use selected date's burned calories when viewing different dates
        // This ensures historical dates show correct adjusted goals
        if UserProfileRepository.shared.getAddBurnedCalories() {
            let burned = isToday ? todaysBurnedCalories : selectedDateBurnedCalories
            goal += burned
        }
        
        // Add rollover calories if setting is enabled (only applies to today)
        // Rollover is yesterday's unused calories, so it doesn't apply to historical dates
        if UserProfileRepository.shared.getRolloverCalories() && isToday {
            goal += rolloverCaloriesFromYesterday
        }
        
        return goal
    }
    
    /// Calories remaining for the day (using effective goal)
    /// Returns 0 if over goal (doesn't show negative remaining)
    var remainingCalories: Int {
        let consumed = todaysSummary?.totalCalories ?? 0
        return max(0, effectiveCalorieGoal - consumed)
    }
    
    /// Calorie progress ratio (0.0 to 1.0+, can exceed 1.0 if over goal)
    /// Uses effective goal which includes burned calories and rollover adjustments
    var calorieProgress: Double {
        let goal = Double(effectiveCalorieGoal)
        let consumed = Double(todaysSummary?.totalCalories ?? 0)
        guard goal > 0 else { return 0 }
        return consumed / goal
    }
    
    /// Whether burned calories are being added to the calorie goal
    var isBurnedCaloriesEnabled: Bool {
        UserProfileRepository.shared.getAddBurnedCalories()
    }
    
    /// Whether rollover calories are being used
    var isRolloverCaloriesEnabled: Bool {
        UserProfileRepository.shared.getRolloverCalories()
    }
    
    /// Description of goal adjustments for display - clearly shows added vs subtracted calories
    /// Examples: "+150 burned", "+50 rollover", "+150 burned, +50 rollover"
    /// Uses selected date's burned calories when viewing different dates
    /// Returns nil if no adjustments are active
    var goalAdjustmentDescription: String? {
        var adjustments: [String] = []
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(selectedDate)
        
        // Added calories (positive adjustments)
        // Use selected date's burned calories when viewing different dates
        let burned = isToday ? todaysBurnedCalories : selectedDateBurnedCalories
        if isBurnedCaloriesEnabled && burned > 0 {
            adjustments.append("+\(burned) burned")
        }
        
        // Rollover only applies to today (yesterday's unused calories)
        if isRolloverCaloriesEnabled && isToday && rolloverCaloriesFromYesterday > 0 {
            adjustments.append("+\(rolloverCaloriesFromYesterday) rollover")
        }
        
        // Note: Currently only positive adjustments exist, but structure supports negative ones
        // If we add negative adjustments in the future (e.g., deficit mode), they would appear with "-" prefix
        
        return adjustments.isEmpty ? nil : adjustments.joined(separator: ", ")
    }
}
