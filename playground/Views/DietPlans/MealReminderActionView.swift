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
    
    @State private var showingFoodOptions = false
    @State private var showingScanView = false
    @State private var showingLogFoodView = false
    @State private var showingQuickLogView = false
    @State private var showingTextLogView = false
    @State private var selectedMeal: Meal?
    @State private var action: ReminderAction = .save
    
    private var mealRepository: MealRepository {
        MealRepository(context: modelContext)
    }
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    private var scanViewModel: ScanViewModel {
        ScanViewModel(
            repository: mealRepository,
            analysisService: CaloriesAPIService(),
            imageStorage: .shared,
            overrideCategory: category
        )
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
                        showingFoodOptions = true
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
                        showingFoodOptions = true
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
            .sheet(isPresented: $showingFoodOptions) {
                foodOptionsSheet
            }
            .sheet(isPresented: $showingScanView) {
                ScanView(
                    viewModel: scanViewModel,
                    onMealSaved: {
                        showingScanView = false
                        markMealAsCompleted()
                        dismiss()
                    },
                    onDismiss: {
                        showingScanView = false
                    }
                )
            }
            .sheet(isPresented: $showingLogFoodView) {
                LogFoodView()
                    .onDisappear {
                        // Check if meal was logged and mark as completed
                        checkAndMarkCompleted()
                    }
            }
            .sheet(isPresented: $showingQuickLogView) {
                QuickLogView()
                    .onDisappear {
                        checkAndMarkCompleted()
                    }
            }
            .sheet(isPresented: $showingTextLogView) {
                TextFoodLogView()
                    .onDisappear {
                        checkAndMarkCompleted()
                    }
            }
        }
    }
    
    // MARK: - Food Options Sheet
    
    private var foodOptionsSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.addFood))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.scanOrSelectPhoto))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Options Grid
                VStack(spacing: 16) {
                    // Scan with Camera - Primary option
                    Button {
                        showingFoodOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingScanView = true
                        }
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizationManager.localizedString(for: AppStrings.Home.scanFood))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(localizationManager.localizedString(for: AppStrings.DietPlan.openCameraToScan))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                    
                    // Manual Food Log
                    Button {
                        showingFoodOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingLogFoodView = true
                        }
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.green, .mint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "list.bullet.clipboard")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizationManager.localizedString(for: AppStrings.Food.logFood))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(localizationManager.localizedString(for: AppStrings.Food.searchOrCreate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                    
                    // Quick Log
                    Button {
                        showingFoodOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingQuickLogView = true
                        }
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange, .yellow],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizationManager.localizedString(for: AppStrings.Food.quickSave))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(localizationManager.localizedString(for: AppStrings.Food.quickSaveDescription))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                    
                    // Text Log
                    Button {
                        showingFoodOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingTextLogView = true
                        }
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple, .indigo],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "text.bubble.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizationManager.localizedString(for: AppStrings.Food.textLog))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(localizationManager.localizedString(for: AppStrings.Food.textLogDescription))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        showingFoodOptions = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Helper Methods
    
    private func markMealAsCompleted() {
        Task {
            do {
                let reminder = try dietPlanRepository.fetchMealReminder(
                    by: scheduledMealId,
                    for: Date()
                )
                if let reminder = reminder {
                    try dietPlanRepository.updateMealReminderCompletion(reminder, completedMealId: nil)
                }
                HapticManager.shared.notification(.success)
            } catch {
                print("Failed to mark meal as completed: \(error)")
            }
        }
    }
    
    private func checkAndMarkCompleted() {
        // Mark the scheduled meal as completed when returning from food logging
        markMealAsCompleted()
        dismiss()
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
                NotificationCenter.default.post(name: .foodLogged, object: meal.id)
                
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

