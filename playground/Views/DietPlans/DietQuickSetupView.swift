//
//  DietQuickSetupView.swift
//  playground
//
//  Guided setup wizard for creating diet plans
//

import SwiftUI
import SwiftData

struct DietQuickSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var currentStep = 0
    @State private var planName = ""
    @State private var selectedTemplate: DietPlanTemplate?
    @State private var meals: [ScheduledMeal] = []
    @State private var showingMealEditor = false
    @State private var editingMeal: ScheduledMeal?
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    private let steps = ["Name", "Template", "Meals", "Review"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Content
                TabView(selection: $currentStep) {
                    nameStep
                        .tag(0)
                    
                    templateStep
                        .tag(1)
                    
                    mealsStep
                        .tag(2)
                    
                    reviewStep
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .disabled(true) // Manual navigation only
                
                // Navigation buttons
                navigationButtons
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.createDietPlan))
                .id("create-diet-plan-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        dismiss()
                    }
                    .id("cancel-quick-setup-\(localizationManager.currentLanguage)")
                }
            }
            .sheet(isPresented: $showingMealEditor) {
                ScheduledMealEditorView(
                    meal: editingMeal,
                    onSave: { meal in
                        if let editing = editingMeal,
                           let index = meals.firstIndex(where: { $0.id == editing.id }) {
                            meals[index] = meal
                        } else {
                            meals.append(meal)
                        }
                        editingMeal = nil
                        showingMealEditor = false
                    }
                )
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            .padding(.horizontal)
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.stepXOfY, arguments: currentStep + 1, steps.count, steps[currentStep]))
                .id("step-indicator-\(localizationManager.currentLanguage)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Steps
    
    private var nameStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "pencil")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.nameYourDietPlan))
                .font(.title2)
                .fontWeight(.bold)
                .id("name-diet-plan-\(localizationManager.currentLanguage)")
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.giveDietPlanName))
                .id("give-diet-plan-name-\(localizationManager.currentLanguage)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            TextField("e.g., Weight Loss Plan", text: $planName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var templateStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.chooseTemplateOptional))
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
                .id("choose-template-\(localizationManager.currentLanguage)")
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.startWithTemplate))
                .id("start-with-template-\(localizationManager.currentLanguage)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 12) {
                    // None option
                    Button {
                        selectedTemplate = nil
                    } label: {
                        HStack {
                            Image(systemName: selectedTemplate == nil ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedTemplate == nil ? .accentColor : .secondary)
                            
                            Text(localizationManager.localizedString(for: AppStrings.DietPlan.startFromScratch))
                                .id("start-from-scratch-\(localizationManager.currentLanguage)")
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    
                    ForEach(DietPlanTemplate.allTemplates) { template in
                        Button {
                            selectedTemplate = template
                            meals = template.createDietPlan().scheduledMeals
                        } label: {
                            HStack {
                                Image(systemName: selectedTemplate?.id == template.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedTemplate?.id == template.id ? .accentColor : .secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(template.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var mealsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.scheduleYourMeals))
                    .font(.title2)
                    .fontWeight(.bold)
                    .id("schedule-meals-\(localizationManager.currentLanguage)")
                
                Spacer()
                
                Button {
                    editingMeal = nil
                    showingMealEditor = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            
            if meals.isEmpty {
                let descriptionText = localizationManager.localizedString(for: AppStrings.DietPlan.addYourFirstScheduledMeal)
                let titleText = localizationManager.localizedString(for: AppStrings.DietPlan.noMealsScheduled)
                ContentUnavailableView(
                    titleText,
                    systemImage: "fork.knife.circle",
                    description: Text(descriptionText)
                )
                .id("no-meals-scheduled-\(localizationManager.currentLanguage)")
            } else {
                List {
                    ForEach(meals) { meal in
                        ScheduledMealRow(meal: meal) {
                            editingMeal = meal
                            showingMealEditor = true
                        }
                    }
                    .onDelete { offsets in
                        meals.remove(atOffsets: offsets)
                    }
                }
            }
        }
    }
    
    private var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.reviewYourPlan))
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .id("review-plan-\(localizationManager.currentLanguage)")
                
                // Plan summary
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.planName))
                            .font(.headline)
                            .id("plan-name-label-\(localizationManager.currentLanguage)")
                        Spacer()
                        Text(planName.isEmpty ? localizationManager.localizedString(for: AppStrings.Common.untitled) : planName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.totalMeals))
                            .font(.headline)
                            .id("total-meals-label-\(localizationManager.currentLanguage)")
                        Spacer()
                        Text("\(meals.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.daysActive))
                            .id("days-active-label-\(localizationManager.currentLanguage)")
                            .font(.headline)
                        Spacer()
                        Text(uniqueDaysString)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Meals preview
                if !meals.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.scheduledMeals))
                            .font(.headline)
                            .padding(.horizontal)
                            .id("scheduled-meals-review-\(localizationManager.currentLanguage)")
                        
                        ForEach(meals.sorted(by: { $0.time < $1.time }), id: \.id) { meal in
                            ScheduledMealRow(meal: meal) {
                                editingMeal = meal
                                showingMealEditor = true
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    private var uniqueDaysString: String {
        let allDays = Set(meals.flatMap { $0.daysOfWeek })
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sortedDays = allDays.sorted().map { dayNames[$0 - 1] }
        return sortedDays.joined(separator: ", ")
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button(localizationManager.localizedString(for: AppStrings.Common.back)) {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .id("back-quick-setup-\(localizationManager.currentLanguage)")
            }
            
            Spacer()
            
            if currentStep < steps.count - 1 {
                Button(localizationManager.localizedString(for: AppStrings.Common.next)) {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .id("next-quick-setup-\(localizationManager.currentLanguage)")
                .buttonStyle(.borderedProminent)
                .disabled(currentStep == 0 && planName.isEmpty)
            } else {
                Button(localizationManager.localizedString(for: AppStrings.DietPlan.createDietPlan)) {
                    createPlan()
                }
                .id("create-plan-btn-\(localizationManager.currentLanguage)")
                .buttonStyle(.borderedProminent)
                .disabled(planName.isEmpty || meals.isEmpty)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private func createPlan() {
        do {
            let plan = DietPlan(
                name: planName,
                planDescription: selectedTemplate?.description,
                isActive: true,
                dailyCalorieGoal: nil, // Can be set later in editor
                scheduledMeals: meals
            )
            
            try dietPlanRepository.saveDietPlan(plan)
            
            // Schedule reminders
            Task {
                let reminderService = MealReminderService.shared(context: modelContext)
                try? await reminderService.requestAuthorization()
                try? await reminderService.scheduleAllReminders()
            }
            
            NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
            
            // Show success notification
            HapticManager.shared.notification(.success)
            
            dismiss()
        } catch {
            print("Failed to create plan: \(error)")
        }
    }
}

#Preview {
    DietQuickSetupView()
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self])
}


