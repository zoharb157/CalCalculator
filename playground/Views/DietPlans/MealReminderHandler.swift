//
//  MealReminderHandler.swift
//  playground
//
//  Handles meal reminder notifications and actions
//

import SwiftUI
import SwiftData
import UserNotifications

@MainActor
struct MealReminderHandler: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @State private var showingReminderAction: MealReminderAction?
    @State private var showingVerification: MealVerificationData?
    @State private var reminderActionType: String?
    
    let scanViewModel: ScanViewModel
    
    func body(content: Content) -> some View {
        content
            .sheet(item: $showingReminderAction) { action in
                MealReminderActionView(
                    scheduledMealId: action.scheduledMealId,
                    mealName: action.mealName,
                    category: action.category,
                    actionType: reminderActionType
                )
            }
            .sheet(item: $showingVerification) { data in
                MealVerificationView(
                    scheduledMealId: data.scheduledMealId,
                    mealName: data.mealName,
                    category: data.category,
                    expectedCalories: data.expectedCalories,
                    scanViewModel: scanViewModel
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .mealReminderAction)) { notification in
                handleMealReminderNotification(notification)
            }
    }
    
    private func handleMealReminderNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let scheduledMealIdString = userInfo["scheduledMealId"] as? String,
              let scheduledMealId = UUID(uuidString: scheduledMealIdString),
              let mealName = userInfo["mealName"] as? String,
              let categoryString = userInfo["category"] as? String,
              let category = MealCategory(rawValue: categoryString),
              let actionType = userInfo["action"] as? String else {
            return
        }
        
        // Handle different actions
        switch actionType {
        case "SAVE_MEAL":
            // Save meal from template
            Task {
                await saveMealFromTemplate(scheduledMealId: scheduledMealId, category: category)
            }
        case "EDIT_MEAL", "ADD_NEW":
            // Show action view for editing/adding
            reminderActionType = actionType
            showingReminderAction = MealReminderAction(
                scheduledMealId: scheduledMealId,
                mealName: mealName,
                category: category
            )
        case "SKIP_MEAL":
            // Just mark as skipped (no action needed)
            Task {
                await markMealSkipped(scheduledMealId: scheduledMealId)
            }
        default:
            // Default: Show verification view (when user taps notification)
            let expectedCalories = userInfo["expectedCalories"] as? Int
            showingVerification = MealVerificationData(
                scheduledMealId: scheduledMealId,
                mealName: mealName,
                category: category,
                expectedCalories: expectedCalories
            )
        }
    }
    
    private func saveMealFromTemplate(scheduledMealId: UUID, category: MealCategory) async {
        do {
            let dietRepo = DietPlanRepository(context: modelContext)
            let mealRepo = MealRepository(context: modelContext)
            
            // Find the scheduled meal
            let plans = try dietRepo.fetchAllDietPlans()
            var scheduledMeal: ScheduledMeal?
            for plan in plans {
                // Safely access scheduledMeals relationship by creating a local copy first
                let scheduledMealsArray = Array(plan.scheduledMeals)
                if let meal = scheduledMealsArray.first(where: { $0.id == scheduledMealId }) {
                    scheduledMeal = meal
                    break
                }
            }
            
            guard let meal = scheduledMeal else {
                print("⚠️ Scheduled meal not found")
                return
            }
            
            // Create meal from template if available
            let newMeal: Meal
            if let template = meal.mealTemplate {
                newMeal = template.createMeal(at: Date(), category: category)
            } else {
                // Create a basic meal
                newMeal = Meal(
                    name: meal.name,
                    timestamp: Date(),
                    category: category,
                    items: []
                )
            }
            
            // Save meal
            // This automatically updates DaySummary and syncs widget data
            try mealRepo.saveMeal(newMeal)
            
            // Notify other parts of the app about the new meal
            // This triggers HomeView to refresh and update widgets
            NotificationCenter.default.post(name: .foodLogged, object: newMeal.id)
            
            // Mark reminder as completed
            if let reminder = try dietRepo.fetchMealReminder(by: scheduledMealId, for: Date()) {
                try dietRepo.updateMealReminderCompletion(reminder, completedMealId: newMeal.id)
            }
            
            HapticManager.shared.notification(.success)
        } catch {
            print("❌ Failed to save meal from reminder: \(error)")
            HapticManager.shared.notification(.error)
        }
    }
    
    private func markMealSkipped(scheduledMealId: UUID) async {
        do {
            let dietRepo = DietPlanRepository(context: modelContext)
            if let reminder = try dietRepo.fetchMealReminder(by: scheduledMealId, for: Date()) {
                // Mark as completed but with no meal (skipped)
                try dietRepo.updateMealReminderCompletion(reminder, completedMealId: nil)
            }
        } catch {
            print("⚠️ Failed to mark meal as skipped: \(error)")
        }
    }
}

/// Data for meal verification view
struct MealVerificationData: Identifiable {
    let id = UUID()
    let scheduledMealId: UUID
    let mealName: String
    let category: MealCategory
    let expectedCalories: Int?
}

extension View {
    func mealReminderHandler(scanViewModel: ScanViewModel) -> some View {
        modifier(MealReminderHandler(scanViewModel: scanViewModel))
    }
}

