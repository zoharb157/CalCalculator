//
//  DietPlansListView.swift
//  playground
//
//  List view for managing diet plans
//

import SwiftUI
import SwiftData

struct DietPlansListView: View {
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activePlans: [DietPlan]
    @Query(sort: \DietPlan.createdAt, order: .reverse) private var allPlans: [DietPlan]
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var showingCreatePlan = false
    @State private var showingTemplates = false
    @State private var showingQuickSetup = false
    @State private var selectedPlan: DietPlan?
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    private var hasActivePlan: Bool {
        !activePlans.isEmpty
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            Group {
                if !hasActivePlan {
                    emptyStateView
                } else {
                    dietPlanView
                }
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.title))
                
            .toolbar {
                if hasActivePlan {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            if let plan = activePlans.first {
                                selectedPlan = plan
                            }
                        } label: {
                            Label(localizationManager.localizedString(for: AppStrings.Common.edit), systemImage: "pencil")
                            
                        }
                    }
                }
            }
            .sheet(isPresented: $showingTemplates) {
                DietPlanTemplatesView { template in
                    // Template selected - create/replace plan (only one active diet allowed)
                    let plan = template.createDietPlan()
                    do {
                        try dietPlanRepository.saveDietPlan(plan)
                        Task {
                            let reminderService = MealReminderService.shared(context: modelContext)
                            try? await reminderService.requestAuthorization()
                            try? await reminderService.scheduleAllReminders()
                        }
                        NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
                        
                        // Show success notification
                        HapticManager.shared.notification(.success)
                    } catch {
                        print("Failed to create plan from template: \(error)")
                    }
                }
            }
            .sheet(isPresented: $showingQuickSetup) {
                DietQuickSetupView()
            }
            .sheet(isPresented: $showingCreatePlan) {
                // When creating, replace existing plan if any
                DietPlanEditorView(plan: activePlans.first, repository: dietPlanRepository)
            }
            .sheet(item: $selectedPlan) { plan in
                DietPlanEditorView(plan: plan, repository: dietPlanRepository)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.noDietPlan))
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.createDietDescription))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingCreatePlan = true
            } label: {
                Label(localizationManager.localizedString(for: AppStrings.DietPlan.createDietPlan), systemImage: "plus.circle.fill")
                    
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var dietPlanView: some View {
        List {
            if let plan = activePlans.first {
                DietPlanRow(plan: plan) {
                    selectedPlan = plan
                }
                
                Section {
                    Button {
                        selectedPlan = plan
                    } label: {
                        Label(localizationManager.localizedString(for: AppStrings.DietPlan.editDietPlan), systemImage: "pencil")
                            .foregroundColor(.blue)
                            
                    }
                    
                    Button(role: .destructive) {
                        deletePlan(plan)
                    } label: {
                        Label(localizationManager.localizedString(for: AppStrings.DietPlan.deleteDietPlan), systemImage: "trash")
                            .foregroundColor(.red)
                            
                    }
                } footer: {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.onlyOneActivePlan))
                        .font(.caption)
                        
                }
            }
        }
    }
    
    private func deletePlan(_ plan: DietPlan) {
        do {
            try dietPlanRepository.deleteDietPlan(plan)
            
            // Reschedule reminders after deletion
            Task {
                let reminderService = MealReminderService.shared(context: modelContext)
                try? await reminderService.scheduleAllReminders()
            }
            
            // Post notification that diet plan changed
            NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
        } catch {
            print("Failed to delete diet plan: \(error)")
        }
    }
}

struct DietPlanRow: View {
    let plan: DietPlan
    let onTap: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let description = plan.planDescription {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 12) {
                        Label("\(plan.scheduledMeals.count) \(localizationManager.localizedString(for: AppStrings.History.meals))", systemImage: "fork.knife")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                        
                        if plan.isActive {
                            Label(localizationManager.localizedString(for: AppStrings.DietPlan.active), systemImage: "checkmark.circle.fill")
                                
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Label(localizationManager.localizedString(for: AppStrings.DietPlan.inactive), systemImage: "xmark.circle.fill")
                                
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DietPlansListView()
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self])
}

