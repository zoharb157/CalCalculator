//
//  DietPlansListView.swift
//  playground
//
//  List view for managing multiple diet plans with modern UI/UX
//

import SwiftUI
import SwiftData

struct DietPlansListView: View {
    @Query(sort: \DietPlan.createdAt, order: .reverse) private var allPlans: [DietPlan]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isSubscribed) private var isSubscribed
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var showingQuickSetup = false
    @State private var showingTemplates = false
    @State private var showingCreateFromScratch = false
    @State private var selectedPlanForEdit: DietPlan?
    @State private var showingDeleteConfirmation = false
    @State private var planToDelete: DietPlan?
    @State private var showingPaywall = false
    @State private var navigationPath = NavigationPath()
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    private var activePlan: DietPlan? {
        allPlans.first(where: { $0.isActive })
    }
    
    private var inactivePlans: [DietPlan] {
        // Filter out ALL active plans to prevent any active plan from appearing in saved plans section
        // This handles edge cases where multiple plans might be marked active temporarily
        allPlans.filter { !$0.isActive }
    }
    
    var body: some View {
        let _ = localizationManager.currentLanguage
        
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    if allPlans.isEmpty {
                        emptyStateView
                    } else {
                        // Active plan section
                        if let plan = activePlan {
                            activePlanSection(plan: plan)
                        }
                        
                        // Inactive plans section
                        if !inactivePlans.isEmpty {
                            inactivePlansSection
                        }
                        
                        // Add new plan button
                        addNewPlanSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.title))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.close)) {
                        dismiss()
                    }
                }
                
                if !allPlans.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                AppLogger.forClass("DietPlansListView").info("Quick Setup menu item tapped")
                                showingQuickSetup = true
                            } label: {
                                Label(localizationManager.localizedString(for: AppStrings.DietPlan.quickSetup), systemImage: "bolt.fill")
                            }
                            
                            Button {
                                AppLogger.forClass("DietPlansListView").info("Templates menu item tapped")
                                showingTemplates = true
                            } label: {
                                Label(localizationManager.localizedString(for: AppStrings.DietPlan.useTemplate), systemImage: "doc.on.doc.fill")
                            }
                            
                            Button {
                                AppLogger.forClass("DietPlansListView").info("Create from Scratch menu item tapped")
                                showingCreateFromScratch = true
                            } label: {
                                Label(localizationManager.localizedString(for: AppStrings.DietPlan.createFromScratch), systemImage: "pencil.and.list.clipboard")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
            }
            .navigationDestination(for: DietPlan.self) { plan in
                DietPlanEditorView(plan: plan, repository: dietPlanRepository, isEmbedded: true)
            }
            .sheet(isPresented: $showingQuickSetup) {
                DietQuickSetupView()
                    .onAppear {
                        AppLogger.forClass("DietPlansListView").info("Quick Setup sheet appeared")
                    }
            }
            .sheet(isPresented: $showingTemplates) {
                // Note: DietPlanTemplatesView already creates the plan in TemplatePreviewView.useTemplate()
                // We only need to dismiss and post notification - do NOT create another plan here
                DietPlanTemplatesView { _ in
                    // Plan was already created by TemplatePreviewView.useTemplate()
                    // Just post notification to refresh UI
                    NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
                    HapticManager.shared.notification(.success)
                }
                .onAppear {
                    AppLogger.forClass("DietPlansListView").info("Templates sheet appeared")
                }
            }
            .sheet(isPresented: $showingCreateFromScratch) {
                DietPlanEditorView(plan: nil, repository: dietPlanRepository, isEmbedded: false)
                    .onAppear {
                        AppLogger.forClass("DietPlansListView").info("Create from Scratch sheet appeared")
                    }
            }
            .onChange(of: showingQuickSetup) { oldValue, newValue in
                AppLogger.forClass("DietPlansListView").data("showingQuickSetup changed: \(oldValue) -> \(newValue)")
            }
            .onChange(of: showingTemplates) { oldValue, newValue in
                AppLogger.forClass("DietPlansListView").data("showingTemplates changed: \(oldValue) -> \(newValue)")
            }
            .onChange(of: showingCreateFromScratch) { oldValue, newValue in
                AppLogger.forClass("DietPlansListView").data("showingCreateFromScratch changed: \(oldValue) -> \(newValue)")
            }
            .sheet(item: $selectedPlanForEdit) { plan in
                DietPlanEditorView(plan: plan, repository: dietPlanRepository, isEmbedded: false)
            }
            .confirmationDialog(
                localizationManager.localizedString(for: AppStrings.DietPlan.deleteDietPlan),
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(localizationManager.localizedString(for: AppStrings.Common.delete), role: .destructive) {
                    if let plan = planToDelete {
                        deletePlan(plan)
                    }
                }
                Button(localizationManager.localizedString(for: AppStrings.Common.cancel), role: .cancel) {
                    planToDelete = nil
                }
            } message: {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.deleteConfirmation))
            }
            .fullScreenCover(isPresented: $showingPaywall) {
                SubscriptionPaywallView()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            // Illustration
            illustrationView
            
            // Text content
            VStack(spacing: 12) {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.noDietPlan))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.createDietDescription))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Creation options
            creationOptionsView
        }
        .padding(.top, 40)
    }
    
    private var illustrationView: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 160, height: 160)
            
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 120, height: 120)
            
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    mealIcon("sun.horizon.fill", color: .orange)
                    mealIcon("sun.max.fill", color: .green)
                }
                HStack(spacing: 16) {
                    mealIcon("moon.stars.fill", color: .blue)
                    mealIcon("leaf.fill", color: .purple)
                }
            }
        }
    }
    
    private func mealIcon(_ systemName: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 44, height: 44)
            
            Image(systemName: systemName)
                .font(.system(size: 20))
                .foregroundColor(color)
        }
    }
    
    private var creationOptionsView: some View {
        VStack(spacing: 12) {
            // Quick Setup - Primary action
            Button {
                AppLogger.forClass("DietPlansListView").info("Quick Setup button tapped (empty state)")
                HapticManager.shared.impact(.light)
                showingQuickSetup = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.quickSetup))
                            .font(.headline)
                        
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.quickSetupDescription))
                            .font(.caption)
                            .opacity(0.8)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            
            HStack(spacing: 12) {
                // Use Template
                CreationOptionCard(
                    icon: "doc.on.doc.fill",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.useTemplate),
                    color: .purple
                ) {
                    AppLogger.forClass("DietPlansListView").info("Templates button tapped (empty state)")
                    HapticManager.shared.impact(.light)
                    showingTemplates = true
                }
                
                // Create from Scratch
                CreationOptionCard(
                    icon: "pencil.and.list.clipboard",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.createFromScratch),
                    color: .green
                ) {
                    AppLogger.forClass("DietPlansListView").info("Create from Scratch button tapped (empty state)")
                    HapticManager.shared.impact(.light)
                    showingCreateFromScratch = true
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Active Plan Section
    
    private func activePlanSection(plan: DietPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "checkmark.circle.fill",
                title: localizationManager.localizedString(for: AppStrings.DietPlan.activePlan),
                color: .green
            )
            
            DietPlanListCard(
                plan: plan,
                isActive: true,
                onTap: {
                    navigationPath.append(plan)
                },
                onActivate: nil,
                onDeactivate: {
                    deactivatePlan(plan)
                },
                onEdit: {
                    selectedPlanForEdit = plan
                },
                onDelete: {
                    planToDelete = plan
                    showingDeleteConfirmation = true
                }
            )
        }
    }
    
    // MARK: - Inactive Plans Section
    
    private var inactivePlansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "folder.fill",
                title: localizationManager.localizedString(for: AppStrings.DietPlan.savedPlans),
                color: .secondary
            )
            
            ForEach(inactivePlans) { plan in
                DietPlanListCard(
                    plan: plan,
                    isActive: false,
                    onTap: {
                        navigationPath.append(plan)
                    },
                    onActivate: {
                        activatePlan(plan)
                    },
                    onDeactivate: nil,
                    onEdit: {
                        selectedPlanForEdit = plan
                    },
                    onDelete: {
                        planToDelete = plan
                        showingDeleteConfirmation = true
                    }
                )
            }
        }
    }
    
    // MARK: - Add New Plan Section
    
    private var addNewPlanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "plus.circle.fill",
                title: localizationManager.localizedString(for: AppStrings.DietPlan.createNewPlan),
                color: .blue
            )
            
            HStack(spacing: 12) {
                DietPlanQuickActionButton(
                    icon: "bolt.fill",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.quickSetup),
                    color: .blue
                ) {
                    AppLogger.forClass("DietPlansListView").info("Quick Setup button tapped")
                    showingQuickSetup = true
                }
                
                DietPlanQuickActionButton(
                    icon: "doc.on.doc.fill",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.useTemplate),
                    color: .purple
                ) {
                    AppLogger.forClass("DietPlansListView").info("Templates button tapped")
                    showingTemplates = true
                }
                
                DietPlanQuickActionButton(
                    icon: "pencil",
                    title: localizationManager.localizedString(for: AppStrings.DietPlan.fromScratch),
                    color: .green
                ) {
                    AppLogger.forClass("DietPlansListView").info("Create from Scratch button tapped")
                    showingCreateFromScratch = true
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private func activatePlan(_ plan: DietPlan) {
        guard isSubscribed else {
            showingPaywall = true
            HapticManager.shared.notification(.warning)
            return
        }
        
        do {
            // Use repository to activate plan (handles deactivating others)
            try dietPlanRepository.activatePlan(plan)
            
            // Reschedule reminders
            Task {
                let reminderService = MealReminderService.shared(context: modelContext)
                try? await reminderService.scheduleAllReminders()
            }
            
            NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
            HapticManager.shared.notification(.success)
        } catch {
            print("❌ [DietPlansListView] Failed to activate plan: \(error)")
            HapticManager.shared.notification(.error)
            HapticManager.shared.notification(.error)
        }
    }
    
    private func deactivatePlan(_ plan: DietPlan) {
        do {
            // Use repository to deactivate plan
            try dietPlanRepository.deactivatePlan(plan)
            
            // Cancel reminders since there's no active plan
            Task {
                let reminderService = MealReminderService.shared(context: modelContext)
                try? await reminderService.scheduleAllReminders()
            }
            
            NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
            HapticManager.shared.notification(.success)
        } catch {
            print("Failed to deactivate plan: \(error)")
            HapticManager.shared.notification(.error)
        }
    }
    
    private func deletePlan(_ plan: DietPlan) {
        do {
            try dietPlanRepository.deleteDietPlan(plan)
            
            Task {
                let reminderService = MealReminderService.shared(context: modelContext)
                try? await reminderService.scheduleAllReminders()
            }
            
            NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
            HapticManager.shared.notification(.success)
        } catch {
            print("❌ [DietPlansListView] Failed to delete diet plan: \(error)")
            HapticManager.shared.notification(.error)
        }
    }
    
    // MARK: - Paywall View
    
}

// MARK: - Diet Plan List Card

struct DietPlanListCard: View {
    let plan: DietPlan
    let isActive: Bool
    let onTap: () -> Void
    let onActivate: (() -> Void)?
    let onDeactivate: (() -> Void)?
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var totalMealsPerWeek: Int {
        plan.scheduledMeals.reduce(0) { $0 + $1.daysOfWeek.count }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        if isActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                
                                Text(localizationManager.localizedString(for: AppStrings.DietPlan.active).uppercased())
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    
                    // Plan name
                    Text(plan.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    // Description
                    if let description = plan.planDescription, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Stats
                    HStack(spacing: 16) {
                        Label("\(plan.scheduledMeals.count) \(localizationManager.localizedString(for: AppStrings.History.meals))", systemImage: "fork.knife")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("\(totalMealsPerWeek)/\(localizationManager.localizedString(for: AppStrings.DietPlan.week))", systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let calories = plan.dailyCalorieGoal {
                            Label("\(calories) kcal", systemImage: "flame.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            Divider()
                .padding(.horizontal)
            
            // Action buttons
            HStack(spacing: 0) {
                if !isActive, let onActivate = onActivate {
                    actionButton(
                        icon: "checkmark.circle",
                        title: localizationManager.localizedString(for: AppStrings.DietPlan.activate),
                        color: .green,
                        action: onActivate
                    )
                    
                    Divider()
                        .frame(height: 24)
                }
                
                if isActive, let onDeactivate = onDeactivate {
                    actionButton(
                        icon: "pause.circle",
                        title: localizationManager.localizedString(for: AppStrings.DietPlan.deactivate),
                        color: .orange,
                        action: onDeactivate
                    )
                    
                    Divider()
                        .frame(height: 24)
                }
                
                actionButton(
                    icon: "pencil",
                    title: localizationManager.localizedString(for: AppStrings.Common.edit),
                    color: .blue,
                    action: onEdit
                )
                
                Divider()
                    .frame(height: 24)
                
                actionButton(
                    icon: "trash",
                    title: localizationManager.localizedString(for: AppStrings.Common.delete),
                    color: .red,
                    action: onDelete
                )
            }
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isActive ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
    
    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Diet Plan Quick Action Button

struct DietPlanQuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            AppLogger.forClass("DietPlanQuickActionButton").info("Button tapped: \(title)")
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Views

struct CreationOptionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DietPlansListView()
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self])
}
