//
//  MealReminderActionView.swift
//  playground
//
//  View for handling meal reminder actions (save/edit/add)
//

import SwiftUI
import SwiftData

struct MealReminderActionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    let scheduledMealId: UUID
    let mealName: String
    let category: MealCategory
    var actionType: String? = nil // "EDIT_MEAL" or "ADD_NEW"
    
    @State private var showingScan = false
    @State private var selectedMeal: Meal?
    @State private var action: ReminderAction = .save
    
    private var mealRepository: MealRepository {
        MealRepository(context: modelContext)
    }
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    enum ReminderAction {
        case save
        case edit
        case addNew
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)
                    
                    Text(String(format: localizationManager.localizedString(for: AppStrings.DietPlan.timeFor), mealName))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(category.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Action buttons
                VStack(spacing: 16) {
                    Button {
                        action = .save
                        saveFromTemplate()
                    } label: {
                        Label(localizationManager.localizedString(for: AppStrings.DietPlan.saveMealAsPlanned), systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        action = .edit
                        showingScan = true
                    } label: {
                        Label(localizationManager.localizedString(for: AppStrings.DietPlan.editAndAddItems), systemImage: "pencil.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        action = .addNew
                        showingScan = true
                    } label: {
                        Label(localizationManager.localizedString(for: AppStrings.DietPlan.addNewFood), systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        dismiss()
                    } label: {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.skip))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.mealReminder))
                
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .sheet(isPresented: $showingScan) {
                // Note: Full ScanView integration would require passing scanViewModel
                // For now, show a placeholder that can be enhanced later
                NavigationStack {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.accentColor)
                        
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.scanYourFood))
                            .font(.title2)
                            .fontWeight(.semibold)
                            
                        
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.openCameraToScan))
                            
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.addFood))
                        
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                                showingScan = false
                            }
                            
                        }
                    }
                }
            }
        }
    }
    
    private func saveFromTemplate() {
        Task {
            do {
                // Find the scheduled meal
                guard let scheduledMeal = try await findScheduledMeal() else {
                    return
                }
                
                // Create meal from template if available
                let meal: Meal
                if let template = scheduledMeal.mealTemplate {
                    meal = template.createMeal(at: Date(), category: category)
                } else {
                    // Create a basic meal
                    meal = Meal(
                        name: mealName,
                        timestamp: Date(),
                        category: category,
                        items: []
                    )
                }
                
                // Save meal
                try mealRepository.saveMeal(meal)
                
                // Notify other parts of the app about the new meal
                // This triggers HomeView to refresh and update widgets
                NotificationCenter.default.post(name: .foodLogged, object: nil)
                
                // Mark reminder as completed
                let reminder = try dietPlanRepository.fetchMealReminder(
                    by: scheduledMealId,
                    for: Date()
                )
                if let reminder = reminder {
                    try dietPlanRepository.updateMealReminderCompletion(reminder, completedMealId: meal.id)
                }
                
                HapticManager.shared.notification(.success)
                dismiss()
            } catch {
                print("Failed to save meal: \(error)")
            }
        }
    }
    
    private func findScheduledMeal() async throws -> ScheduledMeal? {
        let plans = try dietPlanRepository.fetchAllDietPlans()
        for plan in plans {
            // Safely access scheduledMeals relationship by creating a local copy first
            let scheduledMealsArray = Array(plan.scheduledMeals)
            if let meal = scheduledMealsArray.first(where: { $0.id == scheduledMealId }) {
                return meal
            }
        }
        return nil
    }
    
    private func markAsSkipped() {
        Task {
            do {
                if let reminder = try dietPlanRepository.fetchMealReminder(
                    by: scheduledMealId,
                    for: Date()
                ) {
                    // Mark as completed but with no meal (skipped)
                    try dietPlanRepository.updateMealReminderCompletion(reminder, completedMealId: nil)
                } else {
                    // Create a reminder record for skipped meal
                    let reminder = MealReminder(
                        scheduledMealId: scheduledMealId,
                        reminderDate: Date(),
                        wasCompleted: true,
                        completedMealId: nil,
                        completedAt: Date()
                    )
                    try dietPlanRepository.saveMealReminder(reminder)
                }
                
                HapticManager.shared.notification(.success)
                dismiss()
            } catch {
                print("Failed to mark meal as skipped: \(error)")
                HapticManager.shared.notification(.error)
            }
        }
    }
}

#Preview {
    MealReminderActionView(
        scheduledMealId: UUID(),
        mealName: "Oatmeal with Berries",
        category: .breakfast
    )
}

