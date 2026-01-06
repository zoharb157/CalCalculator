//
//  DietPlanEditorView.swift
//  playground
//
//  Editor for creating/editing diet plans
//

import SwiftUI
import SwiftData

struct DietPlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var existingActivePlans: [DietPlan]
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    let plan: DietPlan?
    let repository: DietPlanRepository
    
    @State private var name: String
    @State private var planDescription: String
    @State private var isActive: Bool
    @State private var dailyCalorieGoal: String
    @State private var scheduledMeals: [ScheduledMeal]
    @State private var showingAddMeal = false
    @State private var editingMeal: ScheduledMeal?
    @State private var showNoMealsAlert = false
    @FocusState private var isCalorieGoalFocused: Bool
    
    // Computed macros from calorie goal
    private var calculatedMacros: (proteinG: Double, carbsG: Double, fatG: Double) {
        guard let calories = Int(dailyCalorieGoal), calories > 0 else {
            return (proteinG: 0, carbsG: 0, fatG: 0)
        }
        return DietPlanCalculator.calculateMacros(from: calories)
    }
    
    private var isCreatingNewPlan: Bool {
        plan == nil
    }
    
    private var willReplaceExisting: Bool {
        isCreatingNewPlan && !existingActivePlans.isEmpty && existingActivePlans.first?.id != plan?.id
    }
    
    init(plan: DietPlan?, repository: DietPlanRepository) {
        self.plan = plan
        self.repository = repository
        
        // If creating new plan, calculate recommended calories from user profile
        // If editing existing plan, use existing value or calculate if empty
        let initialCalorieGoal: String
        if let existingPlan = plan, let existingGoal = existingPlan.dailyCalorieGoal {
            initialCalorieGoal = String(existingGoal)
        } else {
            // Calculate from user profile for new plans
            // This may use fallback values (2000 cal) if user profile is incomplete
            let (calories, _, _, _) = DietPlanCalculator.calculateFromUserProfile(UserProfileRepository.shared)
            initialCalorieGoal = String(calories)
            print("✅ [DietPlanEditorView] Calculated initial calorie goal: \(calories) cal")
        }
        
        _name = State(initialValue: plan?.name ?? "")
        _planDescription = State(initialValue: plan?.planDescription ?? "")
        _isActive = State(initialValue: plan?.isActive ?? true)
        _dailyCalorieGoal = State(initialValue: initialCalorieGoal)
        _scheduledMeals = State(initialValue: plan?.scheduledMeals ?? [])
    }
    
    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle(localizationManager.localizedString(for: isCreatingNewPlan ? AppStrings.DietPlan.createDietPlan : AppStrings.DietPlan.editDietPlan))
                .id("nav-title-\(localizationManager.currentLanguage)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(localizationManager.localizedString(for: AppStrings.Common.save)) {
                            savePlan()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || scheduledMeals.isEmpty)
                        .fontWeight(.semibold)
                    }
                }
                .sheet(isPresented: $showingAddMeal) {
                    ScheduledMealEditorView(
                        meal: nil,
                        onSave: { meal in
                            scheduledMeals.append(meal)
                            Task {
                                let reminderService = MealReminderService.shared(context: modelContext)
                                do {
                                    try await reminderService.requestAuthorization()
                                    try await reminderService.scheduleReminder(for: meal)
                                } catch {
                                    print("⚠️ Failed to schedule reminder for new meal: \(error)")
                                }
                            }
                        }
                    )
                }
                .sheet(item: $editingMeal) { meal in
                    ScheduledMealEditorView(
                        meal: meal,
                        onSave: { updatedMeal in
                            if let index = scheduledMeals.firstIndex(where: { $0.id == meal.id }) {
                                scheduledMeals[index] = updatedMeal
                            }
                        }
                    )
                }
                .alert(localizationManager.localizedString(for: AppStrings.DietPlan.noMealsAlert), isPresented: $showNoMealsAlert) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.ok), role: .cancel) {}
                } message: {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.addAtLeastOneMeal))
                }
        }
    }
    
    @ViewBuilder
    private var formContent: some View {
        Form {
                if willReplaceExisting {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                            Text(localizationManager.localizedString(for: AppStrings.DietPlan.creatingNewPlanWillReplace))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(localizationManager.localizedString(for: AppStrings.DietPlan.planDetails)) {
                    TextField(localizationManager.localizedString(for: AppStrings.DietPlan.planName), text: $name)
                        .submitLabel(.next)
                    TextField(localizationManager.localizedString(for: AppStrings.DietPlan.descriptionOptional), text: $planDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .submitLabel(.done)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(localizationManager.localizedString(for: AppStrings.DietPlan.dailyCalorieGoal))
                            Spacer()
                            HStack(spacing: 4) {
                                TextField("", text: $dailyCalorieGoal, prompt: Text("0"))
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 90)
                                    .focused($isCalorieGoalFocused)
                                    .onChange(of: dailyCalorieGoal) { oldValue, newValue in
                                        // Filter out non-numeric characters
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered != newValue {
                                            dailyCalorieGoal = filtered
                                            return
                                        }
                                        
                                        // Validate calorie goal range (0-10000)
                                        if let value = Int(filtered), value < 0 {
                                            dailyCalorieGoal = "0"
                                        } else if let value = Int(filtered), value > 10000 {
                                            dailyCalorieGoal = "10000"
                                        } else if !filtered.isEmpty && Int(filtered) == nil {
                                            // Invalid input - revert to old value
                                            dailyCalorieGoal = oldValue
                                        }
                                    }
                                Text(localizationManager.localizedString(for: AppStrings.Food.kcal))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Show calculated macros when calorie goal is set
                        if let calories = Int(dailyCalorieGoal), calories > 0 {
                            let macros = calculatedMacros
                            VStack(alignment: .leading, spacing: 6) {
                                Text(localizationManager.localizedString(for: AppStrings.DietPlan.calculatedMacros))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 16) {
                                    MacroInfo(
                                        label: "Protein",
                                        value: "\(Int(macros.proteinG))g",
                                        color: .blue
                                    )
                                    MacroInfo(
                                        label: "Carbs",
                                        value: "\(Int(macros.carbsG))g",
                                        color: .orange
                                    )
                                    MacroInfo(
                                        label: "Fat",
                                        value: "\(Int(macros.fatG))g",
                                        color: .purple
                                    )
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    Toggle(localizationManager.localizedString(for: AppStrings.DietPlan.active), isOn: $isActive)
                }
                
                Section(localizationManager.localizedString(for: AppStrings.DietPlan.scheduledMeals)) {
                    if scheduledMeals.isEmpty {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.noMealsScheduled))
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(Array(scheduledMeals)) { meal in
                            ScheduledMealRow(meal: meal) {
                                editingMeal = meal
                            }
                        }
                        .onDelete(perform: deleteMeals)
                    }
                    
                    Button {
                        showingAddMeal = true
                    } label: {
                        Label(localizationManager.localizedString(for: AppStrings.DietPlan.addScheduledMeal), systemImage: "plus.circle")
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
    }
    
    private func savePlan() {
        // Validate that at least one meal is scheduled
        guard !scheduledMeals.isEmpty else {
            showNoMealsAlert = true
            HapticManager.shared.notification(.error)
            return
        }
        
        do {
            // Parse calorie goal
            let calorieGoal = dailyCalorieGoal.isEmpty ? nil : Int(dailyCalorieGoal)
            
            if let existingPlan = plan {
                // Update existing plan
                existingPlan.name = name
                existingPlan.planDescription = planDescription.isEmpty ? nil : planDescription
                existingPlan.isActive = isActive
                existingPlan.dailyCalorieGoal = calorieGoal
                existingPlan.scheduledMeals = scheduledMeals
            } else {
                // Create new plan
                let newPlan = DietPlan(
                    name: name,
                    planDescription: planDescription.isEmpty ? nil : planDescription,
                    isActive: isActive,
                    dailyCalorieGoal: calorieGoal,
                    scheduledMeals: scheduledMeals
                )
                try repository.saveDietPlan(newPlan)
            }
            
            // Request notification permission and reschedule all reminders
            Task {
                let reminderService = MealReminderService.shared(context: modelContext)
                
                // Request authorization if not already granted
                do {
                    try await reminderService.requestAuthorization()
                } catch {
                    print("⚠️ Notification authorization failed: \(error)")
                    // Continue anyway - user can enable in settings
                }
                
                // Schedule all reminders
                do {
                    try await reminderService.scheduleAllReminders()
                    print("✅ All meal reminders scheduled successfully")
                } catch {
                    print("⚠️ Failed to schedule reminders: \(error)")
                }
            }
            
            // Post notification that diet plan changed
            NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
            
            // Show success notification
            HapticManager.shared.notification(.success)
            
            dismiss()
        } catch let error as DietPlanError {
            // Handle specific diet plan errors
            if case .noMeals = error {
                showNoMealsAlert = true
                HapticManager.shared.notification(.error)
            } else {
                print("Failed to save diet plan: \(error)")
            }
        } catch {
            print("Failed to save diet plan: \(error)")
        }
    }
    
    private func deleteMeals(at offsets: IndexSet) {
        let mealsToDelete = offsets.map { scheduledMeals[$0] }
        
        // Cancel reminders for deleted meals
        Task {
            let reminderService = MealReminderService.shared(context: modelContext)
            for meal in mealsToDelete {
                await reminderService.cancelReminders(for: meal)
            }
            
            // Reschedule all reminders after deletion
            try? await reminderService.scheduleAllReminders()
        }
        
        scheduledMeals.remove(atOffsets: offsets)
    }
}

// MARK: - Macro Info View

struct MacroInfo: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Scheduled Meal Row

struct ScheduledMealRow: View {
    let meal: ScheduledMeal
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: meal.category.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Label(meal.formattedTime, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(meal.dayNames, systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    if let container = try? ModelContainer(for: DietPlan.self, ScheduledMeal.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)) {
        DietPlanEditorView(plan: nil, repository: DietPlanRepository(context: container.mainContext))
            .modelContainer(container)
    } else {
        Text(LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.previewUnavailable))
    }
}

