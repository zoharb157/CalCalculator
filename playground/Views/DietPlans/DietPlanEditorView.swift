//
//  DietPlanEditorView.swift
//  playground
//
//  Editor for creating/editing diet plans with modern UI

import SwiftUI
import SwiftData

struct DietPlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
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
    @State private var showDeleteMealConfirmation = false
    @State private var mealToDelete: ScheduledMeal?
    @State private var showingPaywall = false
    @State private var showDeclineConfirmation = false
    @FocusState private var isNameFocused: Bool
    @FocusState private var isCalorieGoalFocused: Bool
    
    private var isCreatingNewPlan: Bool {
        plan == nil
    }
    
    private var willReplaceExisting: Bool {
        isCreatingNewPlan && !existingActivePlans.isEmpty && existingActivePlans.first?.id != plan?.id
    }
    
    // Computed properties for summary
    private var totalMealsPerWeek: Int {
        scheduledMeals.reduce(0) { $0 + $1.daysOfWeek.count }
    }
    
    private var uniqueDays: Set<Int> {
        Set(scheduledMeals.flatMap { $0.daysOfWeek })
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
            ScrollView {
                VStack(spacing: 24) {
                    // Warning banner for replacement
                    if willReplaceExisting {
                        replacementWarningBanner
                    }
                    
                    // Plan details section
                    planDetailsSection
                    
                    // Quick summary card
                    if !scheduledMeals.isEmpty {
                        planSummaryCard
                    }
                    
                    // Scheduled meals section
                    scheduledMealsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isCreatingNewPlan ? localizationManager.localizedString(for: AppStrings.DietPlan.createDietPlan) : localizationManager.localizedString(for: AppStrings.DietPlan.editDietPlan))
            .id("nav-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        savePlan()
                    } label: {
                        Text(localizationManager.localizedString(for: AppStrings.Common.save))
                            .fontWeight(.semibold)
                    }
                    .disabled(name.isEmpty || scheduledMeals.isEmpty)
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
                                print("Failed to schedule reminder for new meal: \(error)")
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
            .fullScreenCover(isPresented: $showingPaywall) {
                paywallView
            }
            .paywallDismissalOverlay(
                showPaywall: $showingPaywall,
                showDeclineConfirmation: $showDeclineConfirmation
            )
            .alert(localizationManager.localizedString(for: AppStrings.DietPlan.mealsRequired), isPresented: $showNoMealsAlert) {
                Button(localizationManager.localizedString(for: AppStrings.Common.ok), role: .cancel) {}
            } message: {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.addAtLeastOneMeal))
            }
        }
    }
    
    // MARK: - Replacement Warning Banner
    
    private var replacementWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.replacingExisting))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.creatingNewPlanWillReplace))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Plan Details Section
    
    private var planDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            sectionHeader(
                title: localizationManager.localizedString(for: AppStrings.DietPlan.planDetails),
                icon: "doc.text"
            )
            
            VStack(spacing: 16) {
                // Plan name
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.planName))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    TextField(localizationManager.localizedString(for: AppStrings.DietPlan.planNamePlaceholder), text: $name)
                        .font(.body)
                        .padding()
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .focused($isNameFocused)
                }
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.descriptionOptional))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    TextField(localizationManager.localizedString(for: AppStrings.DietPlan.descriptionPlaceholder), text: $planDescription, axis: .vertical)
                        .font(.body)
                        .lineLimit(2...4)
                        .padding()
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // Calorie goal
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.dailyCalorieGoal))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        
                        TextField(localizationManager.localizedString(for: AppStrings.Common.optional), text: $dailyCalorieGoal)
                            .keyboardType(.numberPad)
                            .focused($isCalorieGoalFocused)
                            .keyboardDoneButton()
                            .onChange(of: dailyCalorieGoal) { oldValue, newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    dailyCalorieGoal = filtered
                                    return
                                }
                                if let value = Int(filtered), value < 0 {
                                    dailyCalorieGoal = "0"
                                } else if let value = Int(filtered), value > 10000 {
                                    dailyCalorieGoal = "10000"
                                } else if !filtered.isEmpty && Int(filtered) == nil {
                                    dailyCalorieGoal = oldValue
                                }
                            }
                        
                        Text(localizationManager.localizedString(for: AppStrings.Food.kcal))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // Active toggle
                HStack {
                    Label {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.active))
                            .font(.body)
                    } icon: {
                        Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isActive ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $isActive)
                        .labelsHidden()
                        .tint(.green)
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
    
    // MARK: - Plan Summary Card
    
    private var planSummaryCard: some View {
        HStack(spacing: 0) {
            summaryItem(
                value: "\(scheduledMeals.count)",
                label: localizationManager.localizedString(for: AppStrings.History.meals),
                icon: "fork.knife",
                color: .blue
            )
            
            Divider()
                .frame(height: 40)
            
            summaryItem(
                value: "\(totalMealsPerWeek)",
                label: localizationManager.localizedString(for: AppStrings.DietPlan.perWeek),
                icon: "calendar",
                color: .green
            )
            
            Divider()
                .frame(height: 40)
            
            summaryItem(
                value: "\(uniqueDays.count)/7",
                label: localizationManager.localizedString(for: AppStrings.Progress.daysCapitalized),
                icon: "clock",
                color: .orange
            )
        }
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func summaryItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Scheduled Meals Section
    
    private var scheduledMealsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header with add button
            HStack {
                sectionHeader(
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.scheduledMeals),
                    icon: "calendar.badge.clock"
                )
                
                Spacer()
                
                Button {
                    showingAddMeal = true
                    HapticManager.shared.impact(.light)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            
            if scheduledMeals.isEmpty {
                // Empty state
                emptyMealsState
            } else {
                // Meals list
                VStack(spacing: 12) {
                    ForEach(scheduledMeals.sorted(by: { $0.time < $1.time })) { meal in
                        EnhancedScheduledMealRow(meal: meal) {
                            editingMeal = meal
                        } onDelete: {
                            deleteMeal(meal)
                        }
                    }
                }
            }
        }
    }
    
    private var emptyMealsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.noMealsScheduled))
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.addYourFirstScheduledMeal))
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button {
                showingAddMeal = true
            } label: {
                Label(localizationManager.localizedString(for: AppStrings.DietPlan.addScheduledMeal), systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Actions
    
    private func savePlan() {
        guard !scheduledMeals.isEmpty else {
            showNoMealsAlert = true
            HapticManager.shared.notification(.error)
            return
        }
        
        // Check premium subscription before saving
        guard isSubscribed else {
            showingPaywall = true
            HapticManager.shared.notification(.warning)
            return
        }
        
        do {
            let calorieGoal = dailyCalorieGoal.isEmpty ? nil : Int(dailyCalorieGoal)
            
            if let existingPlan = plan {
                existingPlan.name = name
                existingPlan.planDescription = planDescription.isEmpty ? nil : planDescription
                existingPlan.isActive = isActive
                existingPlan.dailyCalorieGoal = calorieGoal
                existingPlan.scheduledMeals = scheduledMeals
            } else {
                let newPlan = DietPlan(
                    name: name,
                    planDescription: planDescription.isEmpty ? nil : planDescription,
                    isActive: isActive,
                    dailyCalorieGoal: calorieGoal,
                    scheduledMeals: scheduledMeals
                )
                try repository.saveDietPlan(newPlan)
            }
            
            Task {
                let reminderService = MealReminderService.shared(context: modelContext)
                do {
                    try await reminderService.requestAuthorization()
                } catch {
                    print("Notification authorization failed: \(error)")
                }
                do {
                    try await reminderService.scheduleAllReminders()
                } catch {
                    print("Failed to schedule reminders: \(error)")
                }
            }
            
            NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
            HapticManager.shared.notification(.success)
            dismiss()
        } catch let error as DietPlanError {
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
    
    private func deleteMeal(_ meal: ScheduledMeal) {
        Task {
            let reminderService = MealReminderService.shared(context: modelContext)
            await reminderService.cancelReminders(for: meal)
            try? await reminderService.scheduleAllReminders()
        }
        
        if let index = scheduledMeals.firstIndex(where: { $0.id == meal.id }) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                _ = scheduledMeals.remove(at: index)
            }
        }
        HapticManager.shared.notification(.success)
    }
    
    // MARK: - Paywall View
    
    private var paywallView: some View {
        SDKView(
            model: sdk,
            page: .splash,
            show: paywallBinding(
                showPaywall: $showingPaywall,
                sdk: sdk,
                showDeclineConfirmation: $showDeclineConfirmation
            ),
            backgroundColor: .white,
            ignoreSafeArea: true
        )
    }
}

// MARK: - Enhanced Scheduled Meal Row

struct EnhancedScheduledMealRow: View {
    let meal: ScheduledMeal
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: meal.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }
            
            // Meal info
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
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button {
                    onTap()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .confirmationDialog(
            "Delete Meal",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(meal.name)\"?")
        }
    }
    
    private var categoryColor: Color {
        switch meal.category {
        case .breakfast: return .orange
        case .lunch: return .green
        case .dinner: return .blue
        case .snack: return .purple
        }
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
