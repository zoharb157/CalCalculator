//
//  QuickMealActionView.swift
//  playground
//
//  Quick action view for meal reminders with improved UX
//

import SwiftUI
import SwiftData

struct QuickMealActionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    let scheduledMealId: UUID
    let mealName: String
    let category: MealCategory
    let mealTemplate: MealTemplate?
    
    @State private var showingScan = false
    @State private var showingEdit = false
    @State private var action: QuickAction = .save
    
    private var mealRepository: MealRepository {
        MealRepository(context: modelContext)
    }
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    enum QuickAction {
        case save
        case edit
        case addNew
        case skip
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            VStack(spacing: 0) {
                // Header with meal info
                headerSection
                
                // Quick actions
                actionsSection
                
                // Meal preview (if template exists)
                if let template = mealTemplate {
                    mealPreviewSection(template: template)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingScan) {
                ScanViewPlaceholder(action: action)
            }
            .sheet(isPresented: $showingEdit) {
                EditMealView(scheduledMealId: scheduledMealId)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: category.icon)
                    .font(.system(size: 50))
                    .foregroundColor(category.color)
            }
            
            VStack(spacing: 4) {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.timeFor, arguments: mealName))
                    .font(.title2)
                    .fontWeight(.bold)
                    
                
                Text(category.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [category.color.opacity(0.1), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Primary action - Save as planned
            Button {
                saveFromTemplate()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.saveAsPlanned))
                        
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(category.color)
                .cornerRadius(12)
            }
            
            // Secondary actions
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "pencil.circle.fill",
                    title: localizationManager.localizedString(for: AppStrings.Common.edit),
                    color: .blue
                ) {
                    showingEdit = true
                }
                
                QuickActionButton(
                    icon: "plus.circle.fill",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.addFood),
                    color: .green
                ) {
                    action = .addNew
                    showingScan = true
                }
            }
            
            // Skip button
            Button {
                markAsSkipped()
            } label: {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.skipThisMeal))
                    
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
    }
    
    // MARK: - Meal Preview
    
    private func mealPreviewSection(template: MealTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.plannedMeal))
                .font(.headline)
                .padding(.horizontal)
                
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(template.templateItems, id: \.name) { item in
                    HStack {
                        Text("• \(item.name)")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(item.calories) \(localizationManager.localizedString(for: AppStrings.Progress.cal))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .id("item-cal-\(localizationManager.currentLanguage)")
                    }
                }
                
                Divider()
                
                HStack {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.total))
                        .font(.headline)
                        
                    
                    Spacer()
                    
                    Text("\(template.templateItems.reduce(0) { $0 + $1.calories }) \(localizationManager.localizedString(for: AppStrings.Progress.cal))")
                        .font(.headline)
                        .id("total-cal-\(localizationManager.currentLanguage)")
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
    
    // MARK: - Actions
    
    private func saveFromTemplate() {
        Task {
            do {
                guard let scheduledMeal = try await findScheduledMeal() else {
                    return
                }
                
                let meal: Meal
                if let template = scheduledMeal.mealTemplate {
                    meal = template.createMeal(at: Date(), category: category)
                } else {
                    meal = Meal(
                        name: mealName,
                        timestamp: Date(),
                        category: category,
                        items: []
                    )
                }
                
                try mealRepository.saveMeal(meal)
                
                // Notify other parts of the app about the new meal
                // This triggers HomeView to refresh and update widgets
                NotificationCenter.default.post(name: .foodLogged, object: nil)
                
                if let reminder = try dietPlanRepository.fetchMealReminder(
                    by: scheduledMealId,
                    for: Date()
                ) {
                    try dietPlanRepository.updateMealReminderCompletion(reminder, completedMealId: meal.id)
                }
                
                HapticManager.shared.notification(.success)
                dismiss()
            } catch {
                print("Failed to save meal: \(error)")
                HapticManager.shared.notification(.error)
            }
        }
    }
    
    private func markAsSkipped() {
        Task {
            do {
                if let reminder = try dietPlanRepository.fetchMealReminder(
                    by: scheduledMealId,
                    for: Date()
                ) {
                    try dietPlanRepository.updateMealReminderCompletion(reminder, completedMealId: nil)
                } else {
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
                print("Failed to mark as skipped: \(error)")
                HapticManager.shared.notification(.error)
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
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct ScanViewPlaceholder: View {
    let action: QuickMealActionView.QuickAction
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text(action == .addNew ? localizationManager.localizedString(for: AppStrings.DietPlan.addFood) : localizationManager.localizedString(for: AppStrings.DietPlan.editMeal))
                    .font(.title2)
                    .fontWeight(.semibold)
                    
                
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.scanOrSelectPhoto))
                    
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.addFood))
                
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        dismiss()
                    }
                    
                }
            }
        }
    }
}

struct EditMealView: View {
    let scheduledMealId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var showingScan = false
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.editMeal))
                    .font(.title2)
                    .fontWeight(.semibold)
                    
                
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.updateMeal))
                    
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button {
                    showingScan = true
                } label: {
                    Label(localizationManager.localizedString(for: AppStrings.Scanning.scanMeal), systemImage: "camera.fill")
                        
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.editMeal))
                
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        dismiss()
                    }
                    
                }
            }
            .sheet(isPresented: $showingScan) {
                ScanViewPlaceholder(action: .edit)
            }
        }
    }
}

#Preview {
    QuickMealActionView(
        scheduledMealId: UUID(),
        mealName: "Oatmeal with Berries",
        category: .breakfast,
        mealTemplate: nil
    )
}

