//
//  DietQuickSetupView.swift
//  playground
//
//  Guided setup wizard for creating diet plans with modern step-by-step UI

import SwiftUI
import SwiftData
import SDK

struct DietQuickSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var currentStep = 0
    @State private var planName = ""
    @State private var selectedTemplate: DietPlanTemplate?
    @State private var mealsData: [ScheduledMealData] = [] // Use data struct instead of @Model
    @State private var showingMealEditor = false
    @State private var editingMealData: ScheduledMealData?
    @State private var showingPaywall = false
    @State private var isSaving = false
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    private let steps: [SetupStep] = [
        SetupStep(id: 0, name: "Name", icon: "pencil"),
        SetupStep(id: 1, name: "Template", icon: "doc.text"),
        SetupStep(id: 2, name: "Meals", icon: "fork.knife"),
        SetupStep(id: 3, name: "Review", icon: "checkmark.circle")
    ]
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return !planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1: return true // Template is optional
        case 2: return !mealsData.isEmpty
        case 3: return !planName.isEmpty && !mealsData.isEmpty
        default: return true
        }
    }
    
    var body: some View {
        let _ = localizationManager.currentLanguage
        
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                modernProgressIndicator
                    .padding(.top)
                
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
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                
                // Navigation buttons
                navigationButtons
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.createDietPlan))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMealEditor) {
                ScheduledMealDataEditorView(
                    mealData: editingMealData,
                    onSave: { mealData in
                        if let editing = editingMealData,
                           let index = mealsData.firstIndex(where: { $0.id == editing.id }) {
                            mealsData[index] = mealData
                        } else {
                            mealsData.append(mealData)
                        }
                        editingMealData = nil
                        showingMealEditor = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showingPaywall) {
                SDKView(
                    model: sdk,
                    page: .splash,
                    show: paywallBinding(showPaywall: $showingPaywall, sdk: sdk),
                    backgroundColor: .white,
                    ignoreSafeArea: true
                )
            }
        }
    }
    
    // MARK: - Modern Progress Indicator
    
    private var modernProgressIndicator: some View {
        VStack(spacing: 16) {
            // Step circles with connecting lines
            HStack(spacing: 0) {
                ForEach(steps) { step in
                    if step.id > 0 {
                        // Connecting line
                        Rectangle()
                            .fill(step.id <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(height: 2)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                    
                    // Step circle
                    stepCircle(step: step)
                }
            }
            .padding(.horizontal, 24)
            
            // Current step label
            Text(steps[currentStep].name)
                .font(.headline)
                .foregroundColor(.primary)
                .animation(.easeInOut, value: currentStep)
        }
        .padding(.vertical)
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    private func stepCircle(step: SetupStep) -> some View {
        let isCompleted = step.id < currentStep
        let isCurrent = step.id == currentStep
        
        return ZStack {
            Circle()
                .fill(isCompleted ? Color.accentColor : (isCurrent ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1)))
                .frame(width: 40, height: 40)
            
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: step.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isCurrent ? .accentColor : .secondary)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
    }
    
    // MARK: - Step 1: Name
    
    private var nameStep: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                }
                .padding(.top, 40)
                
                // Title and subtitle
                VStack(spacing: 8) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.nameYourDietPlan))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.giveDietPlanName))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Input field
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.planName))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    TextField(localizationManager.localizedString(for: AppStrings.DietPlan.planNamePlaceholder), text: $planName)
                        .font(.body)
                        .padding()
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal)
                
                // Suggestions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggestions")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Weight Loss Plan", "Healthy Eating", "Muscle Building", "Balanced Diet"], id: \.self) { suggestion in
                                Button {
                                    planName = suggestion
                                    HapticManager.shared.impact(.light)
                                } label: {
                                    Text(suggestion)
                                        .font(.subheadline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(planName == suggestion ? Color.accentColor : Color(.tertiarySystemGroupedBackground))
                                        .foregroundColor(planName == suggestion ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Step 2: Template
    
    private var templateStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.chooseTemplateOptional))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.startWithTemplate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                VStack(spacing: 12) {
                    // Start from scratch option
                    TemplateOptionCard(
                        title: localizationManager.localizedString(for: AppStrings.DietPlan.startFromScratch),
                        description: "Create a completely custom meal plan",
                        icon: "square.and.pencil",
                        isSelected: selectedTemplate == nil
                    ) {
                        selectedTemplate = nil
                        mealsData = []
                        HapticManager.shared.impact(.light)
                    }
                    
                    // Template options
                    ForEach(DietPlanTemplate.allTemplates) { template in
                        TemplateOptionCard(
                            title: template.name,
                            description: template.description,
                            icon: templateIcon(for: template.name),
                            isSelected: selectedTemplate?.id == template.id
                        ) {
                            selectedTemplate = template
                            // Convert template scheduled meals to ScheduledMealData to avoid SwiftData auto-insertion
                            mealsData = template.createScheduledMeals().map { ScheduledMealData(from: $0) }
                            HapticManager.shared.impact(.light)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func templateIcon(for name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("intermittent"): return "clock"
        case let n where n.contains("protein"): return "bolt.fill"
        case let n where n.contains("mediterranean"): return "leaf.fill"
        case let n where n.contains("balanced"): return "scale.3d"
        default: return "doc.text"
        }
    }
    
    // MARK: - Step 3: Meals
    
    private var mealsStep: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.scheduleYourMeals))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(mealsData.count) meals scheduled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    editingMealData = nil
                    showingMealEditor = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            
            if mealsData.isEmpty {
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.noMealsScheduled))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.addYourFirstScheduledMeal))
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    Button {
                        editingMealData = nil
                        showingMealEditor = true
                    } label: {
                        Label(localizationManager.localizedString(for: AppStrings.DietPlan.addScheduledMeal), systemImage: "plus.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(mealsData.sorted(by: { $0.time < $1.time })) { mealData in
                            QuickSetupMealDataCard(mealData: mealData) {
                                editingMealData = mealData
                                showingMealEditor = true
                            } onDelete: {
                                withAnimation {
                                    mealsData.removeAll { $0.id == mealData.id }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Step 4: Review
    
    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                }
                .padding(.top, 20)
                
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.reviewYourPlan))
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Plan summary card
                VStack(spacing: 16) {
                    summaryRow(
                        icon: "doc.text",
                        title: localizationManager.localizedString(for: AppStrings.DietPlan.planName),
                        value: planName.isEmpty ? localizationManager.localizedString(for: AppStrings.Common.untitled) : planName
                    )
                    
                    Divider()
                    
                    summaryRow(
                        icon: "fork.knife",
                        title: localizationManager.localizedString(for: AppStrings.DietPlan.totalMeals),
                        value: "\(mealsData.count)"
                    )
                    
                    Divider()
                    
                    summaryRow(
                        icon: "calendar",
                        title: localizationManager.localizedString(for: AppStrings.DietPlan.daysActive),
                        value: uniqueDaysString
                    )
                    
                    if let template = selectedTemplate {
                        Divider()
                        
                        summaryRow(
                            icon: "doc.text",
                            title: "Template",
                            value: template.name
                        )
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                
                // Meals preview
                if !mealsData.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.scheduledMeals))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            ForEach(mealsData.sorted(by: { $0.time < $1.time }).prefix(4)) { mealData in
                                HStack {
                                    Image(systemName: mealData.category.icon)
                                        .foregroundColor(.accentColor)
                                        .frame(width: 24)
                                    
                                    Text(mealData.name)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    Text(mealData.formattedTime)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                            }
                            
                            if mealsData.count > 4 {
                                Text("+\(mealsData.count - 4) more meals")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    private func summaryRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    private var uniqueDaysString: String {
        let allDays = Set(mealsData.flatMap { $0.daysOfWeek })
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localizationManager.currentLanguage)
        guard let dayNames = formatter.shortWeekdaySymbols else { return "" }
        let sortedDays = allDays.sorted().map { dayNames[$0 - 1] }
        return sortedDays.joined(separator: ", ")
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentStep -= 1
                    }
                    HapticManager.shared.impact(.light)
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(localizationManager.localizedString(for: AppStrings.Common.back))
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            
            Button {
                if currentStep < steps.count - 1 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentStep += 1
                    }
                    HapticManager.shared.impact(.light)
                } else {
                    Task {
                        await createPlan()
                    }
                }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(currentStep < steps.count - 1 
                             ? localizationManager.localizedString(for: AppStrings.Common.next)
                             : localizationManager.localizedString(for: AppStrings.DietPlan.createDietPlan))
                        
                        if currentStep < steps.count - 1 {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canProceed && !isSaving ? Color.accentColor : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!canProceed || isSaving)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Actions
    
    private func createPlan() async {
        // Prevent double-taps from triggering multiple saves
        guard !isSaving else { return }
        
        // Check premium subscription before saving
        guard isSubscribed else {
            showingPaywall = true
            HapticManager.shared.notification(.warning)
            return
        }
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            // Convert mealsData to data tuples
            let mealTuples = mealsData.map { data in
                (name: data.name, category: data.category, time: data.time, daysOfWeek: data.daysOfWeek)
            }
            
            // Use repository to create plan
            try dietPlanRepository.createDietPlan(
                name: planName,
                description: selectedTemplate?.description,
                isActive: true,
                dailyCalorieGoal: nil,
                scheduledMeals: mealTuples
            )
            
            // Schedule reminders before dismissing
            let reminderService = MealReminderService.shared(context: modelContext)
            do {
                try await reminderService.requestAuthorization()
                try await reminderService.scheduleAllReminders()
            } catch {
                print("⚠️ [DietQuickSetupView] Failed to schedule reminders: \(error)")
                // Continue - reminders are not critical for plan creation
            }
            
            NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
            HapticManager.shared.notification(.success)
            dismiss()
        } catch {
            print("❌ [DietQuickSetupView] Failed to create plan: \(error)")
            // Show error to user if needed
            HapticManager.shared.notification(.error)
        }
    }
    
    // MARK: - Paywall View
    
    private var paywallView: some View {
        SDKView(
            model: sdk,
            page: .splash,
            show: paywallBinding(showPaywall: $showingPaywall, sdk: sdk),
            backgroundColor: .white,
            ignoreSafeArea: true
        )
    }
}

// MARK: - Supporting Types

private struct SetupStep: Identifiable {
    let id: Int
    let name: String
    let icon: String
}

// MARK: - Template Option Card

struct TemplateOptionCard: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.5))
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Setup Meal Data Card (works with ScheduledMealData struct)

struct QuickSetupMealDataCard: View {
    let mealData: ScheduledMealData
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var categoryColor: Color {
        switch mealData.category {
        case .breakfast: return .orange
        case .lunch: return .green
        case .dinner: return .blue
        case .snack: return .purple
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: mealData.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(mealData.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Label(mealData.formattedTime, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(mealData.dayNames)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Quick Setup Meal Card (for backward compatibility with ScheduledMeal @Model)

struct QuickSetupMealCard: View {
    let meal: ScheduledMeal
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var categoryColor: Color {
        switch meal.category {
        case .breakfast: return .orange
        case .lunch: return .green
        case .dinner: return .blue
        case .snack: return .purple
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: meal.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Label(meal.formattedTime, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(meal.dayNames)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    DietQuickSetupView()
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self])
}
