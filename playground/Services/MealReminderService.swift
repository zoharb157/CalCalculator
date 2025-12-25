//
//  MealReminderService.swift
//  playground
//
//  Service for scheduling and managing meal reminders
//

import Foundation
import UserNotifications
import SwiftData

@MainActor
final class MealReminderService {
    private let repository: DietPlanRepository
    private let mealRepository: MealRepository
    
    init(repository: DietPlanRepository, mealRepository: MealRepository) {
        self.repository = repository
        self.mealRepository = mealRepository
    }
    
    /// Create a shared instance (requires context)
    static func shared(context: ModelContext) -> MealReminderService {
        let dietRepo = DietPlanRepository(context: context)
        let mealRepo = MealRepository(context: context)
        return MealReminderService(repository: dietRepo, mealRepository: mealRepo)
    }
    
    // MARK: - Notification Authorization
    
    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        
        if !granted {
            throw MealReminderError.authorizationDenied
        }
    }
    
    // MARK: - Schedule Reminders
    
    /// Schedule all reminders for active diet plans
    func scheduleAllReminders() async throws {
        // Remove all existing notifications first
        await cancelAllReminders()
        
        let activePlans = try repository.fetchActiveDietPlans()
        
        for plan in activePlans {
            for scheduledMeal in plan.scheduledMeals {
                try await scheduleReminder(for: scheduledMeal)
            }
        }
    }
    
    /// Schedule reminder for a specific scheduled meal
    /// This schedules all future occurrences for the meal
    func scheduleReminder(for scheduledMeal: ScheduledMeal) async throws {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: scheduledMeal.time)
        let minute = calendar.component(.minute, from: scheduledMeal.time)
        
        // Schedule for each day of the week that the meal is scheduled
        for dayOfWeek in scheduledMeal.daysOfWeek {
            // Calculate next occurrence for this day
            let today = calendar.component(.weekday, from: now)
            var daysUntilNext = (dayOfWeek - today + 7) % 7
            
            // If today is the scheduled day and time hasn't passed, schedule for today
            if dayOfWeek == today {
                var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
                todayComponents.hour = hour
                todayComponents.minute = minute
                if let todayTime = calendar.date(from: todayComponents), todayTime > now {
                    daysUntilNext = 0
                } else {
                    daysUntilNext = 7 // Next week
                }
            } else if daysUntilNext == 0 {
                daysUntilNext = 7 // Next week
            }
            
            // Calculate the date for this occurrence
            guard let scheduledDate = calendar.date(byAdding: .day, value: daysUntilNext, to: now) else {
                continue
            }
            
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
            dateComponents.hour = hour
            dateComponents.minute = minute
            
            guard let scheduledTime = calendar.date(from: dateComponents) else {
                continue
            }
            
            // Get expected calories from template if available
            let expectedCalories = scheduledMeal.mealTemplate?.expectedCalories
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Time for \(scheduledMeal.name)"
            if let calories = expectedCalories {
                content.body = "Take a photo to verify it matches \(calories) calories"
            } else {
                content.body = "It's time for your \(scheduledMeal.category.displayName.lowercased()) meal. Take a photo to verify."
            }
            content.sound = .default
            content.categoryIdentifier = "MEAL_REMINDER"
            var userInfo: [String: Any] = [
                "scheduledMealId": scheduledMeal.id.uuidString,
                "mealName": scheduledMeal.name,
                "category": scheduledMeal.category.rawValue
            ]
            if let calories = expectedCalories {
                userInfo["expectedCalories"] = calories
            }
            content.userInfo = userInfo
            
            // Create repeating trigger (weekly)
            var triggerComponents = DateComponents()
            triggerComponents.weekday = dayOfWeek
            triggerComponents.hour = hour
            triggerComponents.minute = minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
            
            // Create unique identifier for this day/time combination
            let identifier = "meal_reminder_\(scheduledMeal.id.uuidString)_\(dayOfWeek)"
            
            // Remove any existing notification with this identifier first
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            // Schedule
            try await center.add(request)
            
            print("📅 Scheduled recurring reminder for \(scheduledMeal.name) on day \(dayOfWeek) at \(hour):\(String(format: "%02d", minute))")
        }
    }
    
    /// Cancel all meal reminders
    func cancelAllReminders() async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        let mealReminderIds = pendingRequests
            .filter { $0.content.categoryIdentifier == "MEAL_REMINDER" }
            .map { $0.identifier }
        
        center.removePendingNotificationRequests(withIdentifiers: mealReminderIds)
    }
    
    /// Cancel reminders for a specific scheduled meal
    func cancelReminders(for scheduledMeal: ScheduledMeal) async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        let mealReminderIds = pendingRequests
            .filter { $0.identifier.contains(scheduledMeal.id.uuidString) }
            .map { $0.identifier }
        
        center.removePendingNotificationRequests(withIdentifiers: mealReminderIds)
    }
    
    // MARK: - Handle Notification Actions
    
    /// Handle when user taps on a meal reminder notification
    func handleMealReminderNotification(userInfo: [AnyHashable: Any]) -> MealReminderAction? {
        guard let scheduledMealIdString = userInfo["scheduledMealId"] as? String,
              let scheduledMealId = UUID(uuidString: scheduledMealIdString),
              let mealName = userInfo["mealName"] as? String,
              let categoryString = userInfo["category"] as? String,
              let category = MealCategory(rawValue: categoryString) else {
            return nil
        }
        
        return MealReminderAction(
            scheduledMealId: scheduledMealId,
            mealName: mealName,
            category: category
        )
    }
}

/// Action data for meal reminder notifications
struct MealReminderAction: Identifiable {
    let id = UUID()
    let scheduledMealId: UUID
    let mealName: String
    let category: MealCategory
}

enum MealReminderError: LocalizedError {
    case authorizationDenied
    case schedulingFailed
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Notification permission was denied. Please enable notifications in Settings."
        case .schedulingFailed:
            return "Failed to schedule meal reminder."
        }
    }
}

