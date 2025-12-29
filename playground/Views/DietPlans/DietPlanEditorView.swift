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
    
    private var isCreatingNewPlan: Bool {
        plan == nil
    }
    
    private var willReplaceExisting: Bool {
        isCreatingNewPlan && !existingActivePlans.isEmpty && existingActivePlans.first?.id != plan?.id
    }
    
    init(plan: DietPlan?, repository: DietPlanRepository) {
        self.plan = plan
        self.repository = repository
        _name = State(initialValue: plan?.name ?? "")
        _planDescription = State(initialValue: plan?.planDescription ?? "")
        _isActive = State(initialValue: plan?.isActive ?? true)
        _dailyCalorieGoal = State(initialValue: plan?.dailyCalorieGoal.map { String($0) } ?? "")
        _scheduledMeals = State(initialValue: plan?.scheduledMeals ?? [])
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if willReplaceExisting {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                            Text("Creating a new plan will replace your current active diet plan. You can only have one active diet plan at a time.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Plan Details") {
                    TextField("Plan Name", text: $name)
                    TextField("Description (optional)", text: $planDescription, axis: .vertical)
                        .lineLimit(3...6)
                    
                    HStack {
                        Text("Daily Calorie Goal")
                        Spacer()
                        TextField("Optional", text: $dailyCalorieGoal)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($isCalorieGoalFocused)
                            .keyboardDoneButton()
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
                        Text("kcal")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Active", isOn: $isActive)
                }
                
                Section("Scheduled Meals") {
                    if scheduledMeals.isEmpty {
                        Text("No meals scheduled")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(scheduledMeals) { meal in
                            ScheduledMealRow(meal: meal) {
                                editingMeal = meal
                            }
                        }
                        .onDelete(perform: deleteMeals)
                    }
                    
                    Button {
                        showingAddMeal = true
                    } label: {
                        Label("Add Scheduled Meal", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle(isCreatingNewPlan ? "Create Diet Plan" : "Edit Diet Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePlan()
                    }
                    .disabled(name.isEmpty || scheduledMeals.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddMeal) {
                ScheduledMealEditorView(
                    meal: nil,
                    onSave: { meal in
                        scheduledMeals.append(meal)
                        
                        // Schedule reminder for new meal
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
            .alert("Meals Required", isPresented: $showNoMealsAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please add at least one scheduled meal before saving the diet plan.")
            }
        }
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
        return DietPlanEditorView(plan: nil, repository: DietPlanRepository(context: container.mainContext))
            .modelContainer(container)
    } else {
        return Text("Preview unavailable")
    }
}

