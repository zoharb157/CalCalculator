//
//  DietPlanEditorView.swift
//  playground
//
//  Editor for creating/editing diet plans with modern UI

import SwiftUI
import SwiftData
// import SDK  // Commented out - using native StoreKit 2 paywall

/// Lightweight struct to hold meal data without SwiftData auto-insertion
struct ScheduledMealData: Identifiable {
    let id: UUID
    var name: String
    var category: MealCategory
    var time: Date
    var daysOfWeek: [Int]
    
    init(id: UUID = UUID(), name: String, category: MealCategory, time: Date, daysOfWeek: [Int]) {
        self.id = id
        self.name = name
        self.category = category
        self.time = time
        self.daysOfWeek = daysOfWeek
    }
    
    init(from meal: ScheduledMeal) {
        self.id = meal.id
        self.name = meal.name
        self.category = meal.category
        self.time = meal.time
        self.daysOfWeek = meal.daysOfWeek
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var dayNames: String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return daysOfWeek.sorted().map { dayNames[$0 - 1] }.joined(separator: ", ")
    }
}

struct DietPlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isSubscribed) private var isSubscribed
    // @Environment(TheSDK.self) private var sdk  // Commented out - using native StoreKit 2 paywall
    @Query(sort: \DietPlan.createdAt) private var allDietPlans: [DietPlan]
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    let plan: DietPlan?
    let repository: DietPlanRepository
    let isEmbedded: Bool // True when pushed in NavigationStack, false when presented as sheet
    
    @State private var name: String
    @State private var planDescription: String
    @State private var isActive: Bool
    @State private var dailyCalorieGoal: String
    @State private var scheduledMealsData: [ScheduledMealData] // Use data struct instead of @Model
    @State private var showingAddMeal = false
    @State private var editingMealData: ScheduledMealData?
    @State private var showNoMealsAlert = false
    @State private var showDeleteMealConfirmation = false
    @State private var mealDataToDelete: ScheduledMealData?
    @State private var showingPaywall = false
    @State private var showDeclineConfirmation = false
    @State private var isSaving = false
    @FocusState private var isNameFocused: Bool
    @FocusState private var isCalorieGoalFocused: Bool
    
    private var isCreatingNewPlan: Bool {
        plan == nil
    }
    
    private var hasOtherActivePlan: Bool {
        allDietPlans.contains { $0.isActive && $0.id != plan?.id }
    }
    
    private var willReplaceExisting: Bool {
        isCreatingNewPlan && isActive && hasOtherActivePlan
    }
    
    // Computed properties for summary
    private var totalMealsPerWeek: Int {
        scheduledMealsData.reduce(0) { $0 + $1.daysOfWeek.count }
    }
    
    private var uniqueDays: Set<Int> {
        Set(scheduledMealsData.flatMap { $0.daysOfWeek })
    }
    
    init(plan: DietPlan?, repository: DietPlanRepository, isEmbedded: Bool = false) {
        self.plan = plan
        self.repository = repository
        self.isEmbedded = isEmbedded
        _name = State(initialValue: plan?.name ?? "")
        _planDescription = State(initialValue: plan?.planDescription ?? "")
        _isActive = State(initialValue: plan?.isActive ?? true)
        _dailyCalorieGoal = State(initialValue: plan?.dailyCalorieGoal.map { String($0) } ?? "")
        // Convert ScheduledMeal @Model objects to lightweight data structs to avoid SwiftData auto-insertion
        _scheduledMealsData = State(initialValue: plan?.scheduledMeals.map { ScheduledMealData(from: $0) } ?? [])
    }
    
    var body: some View {
        let content = ScrollView {
            VStack(spacing: 24) {
                // Warning banner for replacement
                if willReplaceExisting {
                    replacementWarningBanner
                }
                
                // Plan details section
                planDetailsSection
                
                // Quick summary card
                if !scheduledMealsData.isEmpty {
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
            if !isEmbedded {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        await savePlan()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(localizationManager.localizedString(for: AppStrings.Common.save))
                            .fontWeight(.semibold)
                    }
                }
                .disabled(name.isEmpty || scheduledMealsData.isEmpty || isSaving)
            }
        }
        .sheet(isPresented: $showingAddMeal) {
            ScheduledMealDataEditorView(
                mealData: nil,
                onSave: { mealData in
                    scheduledMealsData.append(mealData)
                }
            )
        }
        .sheet(item: $editingMealData) { mealData in
            ScheduledMealDataEditorView(
                mealData: mealData,
                onSave: { updatedMealData in
                    if let index = scheduledMealsData.firstIndex(where: { $0.id == mealData.id }) {
                        scheduledMealsData[index] = updatedMealData
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            // Native StoreKit 2 paywall - replacing SDK paywall
            NativePaywallView { subscribed in
                showingPaywall = false
                if subscribed {
                    // User subscribed - reset limits
                    AnalysisLimitManager.shared.resetAnalysisCount()
                    MealSaveLimitManager.shared.resetMealSaveCount()
                    ExerciseSaveLimitManager.shared.resetExerciseSaveCount()
                    NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
                } else {
                    showDeclineConfirmation = true
                }
            }
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
        
        // Wrap in NavigationStack only if presented as sheet
        if isEmbedded {
            content
        } else {
            NavigationStack {
                content
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
                value: "\(scheduledMealsData.count)",
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
            
            if scheduledMealsData.isEmpty {
                // Empty state
                emptyMealsState
            } else {
                // Meals list
                VStack(spacing: 12) {
                    ForEach(scheduledMealsData.sorted(by: { $0.time < $1.time })) { mealData in
                        EnhancedScheduledMealDataRow(mealData: mealData) {
                            editingMealData = mealData
                        } onDelete: {
                            deleteMealData(mealData)
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
    
    private func savePlan() async {
        // Prevent double-taps from triggering multiple saves
        guard !isSaving else { return }
        
        guard !scheduledMealsData.isEmpty else {
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
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            let calorieGoal = dailyCalorieGoal.isEmpty ? nil : Int(dailyCalorieGoal)
            
            // Convert scheduledMealsData to meal data tuples
            let mealData = scheduledMealsData.map { data in
                (name: data.name, category: data.category, time: data.time, daysOfWeek: data.daysOfWeek)
            }
            
            if let existingPlan = plan {
                // Update existing plan using repository
                try repository.updateDietPlan(
                    existingPlan,
                    name: name,
                    description: planDescription.isEmpty ? nil : planDescription,
                    isActive: isActive,
                    dailyCalorieGoal: calorieGoal,
                    scheduledMeals: mealData
                )
            } else {
                // Create new plan using repository
                try repository.createDietPlan(
                    name: name,
                    description: planDescription.isEmpty ? nil : planDescription,
                    isActive: isActive,
                    dailyCalorieGoal: calorieGoal,
                    scheduledMeals: mealData
                )
            }
            
            // Schedule reminders
            let reminderService = MealReminderService.shared(context: modelContext)
            do {
                try await reminderService.requestAuthorization()
                try await reminderService.scheduleAllReminders()
            } catch {
                AppLogger.forClass("DietPlanEditorView").warning("Failed to schedule reminders", error: error)
                // Continue - reminders are not critical for plan saving
            }
            
            NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
            HapticManager.shared.notification(.success)
            dismiss()
        } catch let error as DietPlanError {
            if case .noMeals = error {
                showNoMealsAlert = true
                HapticManager.shared.notification(.error)
            } else {
                AppLogger.forClass("DietPlanEditorView").error("Failed to save diet plan", error: error)
                HapticManager.shared.notification(.error)
            }
        } catch {
            AppLogger.forClass("DietPlanEditorView").error("Failed to save diet plan", error: error)
            HapticManager.shared.notification(.error)
        }
    }
    
    private func deleteMealData(_ mealData: ScheduledMealData) {
        if let index = scheduledMealsData.firstIndex(where: { $0.id == mealData.id }) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                _ = scheduledMealsData.remove(at: index)
            }
        }
        HapticManager.shared.notification(.success)
    }
}

// MARK: - Enhanced Scheduled Meal Data Row (works with ScheduledMealData struct)

struct EnhancedScheduledMealDataRow: View {
    let mealData: ScheduledMealData
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
                
                Image(systemName: mealData.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }
            
            // Meal info
            VStack(alignment: .leading, spacing: 4) {
                Text(mealData.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Label(mealData.formattedTime, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(mealData.dayNames, systemImage: "calendar")
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
            Text("Are you sure you want to delete \"\(mealData.name)\"?")
        }
    }
    
    private var categoryColor: Color {
        switch mealData.category {
        case .breakfast: return .orange
        case .lunch: return .green
        case .dinner: return .blue
        case .snack: return .purple
        }
    }
}

// MARK: - Scheduled Meal Data Editor View (works with ScheduledMealData struct)

struct ScheduledMealDataEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    let mealData: ScheduledMealData?
    let onSave: (ScheduledMealData) -> Void
    
    @State private var name: String
    @State private var category: MealCategory
    @State private var time: Date
    @State private var selectedDays: Set<Int> // 1 = Sunday, 7 = Saturday
    
    private let weekdays: [(id: Int, short: String, long: String)] = [
        (1, "S", "Sun"),
        (2, "M", "Mon"),
        (3, "T", "Tue"),
        (4, "W", "Wed"),
        (5, "T", "Thu"),
        (6, "F", "Fri"),
        (7, "S", "Sat")
    ]
    
    init(mealData: ScheduledMealData?, onSave: @escaping (ScheduledMealData) -> Void) {
        self.mealData = mealData
        self.onSave = onSave
        
        if let mealData = mealData {
            _name = State(initialValue: mealData.name)
            _category = State(initialValue: mealData.category)
            _time = State(initialValue: mealData.time)
            _selectedDays = State(initialValue: Set(mealData.daysOfWeek))
        } else {
            _name = State(initialValue: "")
            _category = State(initialValue: .breakfast)
            _time = State(initialValue: Date())
            _selectedDays = State(initialValue: [])
        }
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedDays.isEmpty
    }
    
    var body: some View {
        let _ = localizationManager.currentLanguage
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    mealDetailsSection
                    categorySection
                    timeSection
                    daysSection
                    quickSelectSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(mealData == nil 
                             ? localizationManager.localizedString(for: AppStrings.DietPlan.newScheduledMeal) 
                             : localizationManager.localizedString(for: AppStrings.DietPlan.editScheduledMeal))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveMeal()
                    } label: {
                        Text(localizationManager.localizedString(for: AppStrings.Common.save))
                            .fontWeight(.semibold)
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var mealDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: localizationManager.localizedString(for: AppStrings.DietPlan.mealDetails), icon: "fork.knife")
            
            VStack(alignment: .leading, spacing: 8) {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.mealName))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                TextField("e.g., Morning Oatmeal", text: $name)
                    .font(.body)
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Category", icon: "tag")
            
            HStack(spacing: 12) {
                ForEach(MealCategory.allCases, id: \.self) { cat in
                    categoryButton(cat)
                }
            }
        }
    }
    
    private func categoryButton(_ cat: MealCategory) -> some View {
        let isSelected = category == cat
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                category = cat
            }
            HapticManager.shared.impact(.light)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? categoryColor(cat) : Color(.tertiarySystemGroupedBackground))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: cat.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                Text(cat.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? categoryColor(cat) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? categoryColor(cat).opacity(0.1) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? categoryColor(cat) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func categoryColor(_ cat: MealCategory) -> Color {
        switch cat {
        case .breakfast: return .orange
        case .lunch: return .green
        case .dinner: return .blue
        case .snack: return .purple
        }
    }
    
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: localizationManager.localizedString(for: AppStrings.DietPlan.time), icon: "clock")
            
            DatePicker(
                "",
                selection: $time,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
    
    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: localizationManager.localizedString(for: AppStrings.DietPlan.repeatOn), icon: "calendar")
                
                Spacer()
                
                if !selectedDays.isEmpty {
                    Text("\(selectedDays.count) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                }
            }
            
            HStack(spacing: 8) {
                ForEach(weekdays, id: \.id) { day in
                    dayButton(day: day)
                }
            }
            
            if selectedDays.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.selectAtLeastOneDay))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }
        }
    }
    
    private func dayButton(day: (id: Int, short: String, long: String)) -> some View {
        let isSelected = selectedDays.contains(day.id)
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    selectedDays.remove(day.id)
                } else {
                    selectedDays.insert(day.id)
                }
            }
            HapticManager.shared.impact(.light)
        } label: {
            VStack(spacing: 4) {
                Text(day.short)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 44, height: 44)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var quickSelectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Select")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                quickSelectButton(title: "Weekdays", days: [2, 3, 4, 5, 6])
                quickSelectButton(title: "Weekends", days: [1, 7])
                quickSelectButton(title: "Every Day", days: [1, 2, 3, 4, 5, 6, 7])
            }
        }
    }
    
    private func quickSelectButton(title: String, days: [Int]) -> some View {
        let isSelected = Set(days) == selectedDays
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDays = Set(days)
            }
            HapticManager.shared.impact(.light)
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
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
    
    private func saveMeal() {
        let daysOfWeek = Array(selectedDays).sorted()
        
        let updatedMealData = ScheduledMealData(
            id: mealData?.id ?? UUID(),
            name: name,
            category: category,
            time: time,
            daysOfWeek: daysOfWeek
        )
        onSave(updatedMealData)
        
        HapticManager.shared.notification(.success)
        dismiss()
    }
}

// MARK: - Enhanced Scheduled Meal Row (for backward compatibility with ScheduledMeal @Model)

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
