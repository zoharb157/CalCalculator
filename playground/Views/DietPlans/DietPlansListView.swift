//
//  DietPlansListView.swift
//  playground
//
//  List view for managing diet plans
//

import SwiftUI
import SwiftData

struct DietPlansListView: View {
    @Query(sort: \DietPlan.createdAt, order: .reverse) private var dietPlans: [DietPlan]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingCreatePlan = false
    @State private var showingTemplates = false
    @State private var showingQuickSetup = false
    @State private var selectedPlan: DietPlan?
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if dietPlans.isEmpty {
                    emptyStateView
                } else {
                    dietPlansList
                }
            }
            .navigationTitle("Diet Plans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingCreatePlan = true
                        } label: {
                            Label("Create Custom Plan", systemImage: "plus")
                        }
                        
                        Button {
                            showingTemplates = true
                        } label: {
                            Label("Use Template", systemImage: "doc.text")
                        }
                        
                        Button {
                            showingQuickSetup = true
                        } label: {
                            Label("Quick Setup", systemImage: "wand.and.stars")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingTemplates) {
                DietPlanTemplatesView { template in
                    // Template selected - create plan
                    let plan = template.createDietPlan()
                    do {
                        try dietPlanRepository.saveDietPlan(plan)
                        Task {
                            let reminderService = MealReminderService.shared(context: modelContext)
                            try? await reminderService.requestAuthorization()
                            try? await reminderService.scheduleAllReminders()
                        }
                        NotificationCenter.default.post(name: .dietPlanChanged, object: nil)
                    } catch {
                        print("Failed to create plan from template: \(error)")
                    }
                }
            }
            .sheet(isPresented: $showingQuickSetup) {
                DietQuickSetupView()
            }
            .sheet(isPresented: $showingCreatePlan) {
                DietPlanEditorView(plan: nil, repository: dietPlanRepository)
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
            
            Text("No Diet Plans")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create a diet plan to schedule repetitive meals and track your adherence")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingCreatePlan = true
            } label: {
                Label("Create Diet Plan", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var dietPlansList: some View {
        List {
            ForEach(dietPlans) { plan in
                DietPlanRow(plan: plan) {
                    selectedPlan = plan
                }
            }
            .onDelete(perform: deletePlans)
        }
    }
    
    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            let plan = dietPlans[index]
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
}

struct DietPlanRow: View {
    let plan: DietPlan
    let onTap: () -> Void
    
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
                        Label("\(plan.scheduledMeals.count) meals", systemImage: "fork.knife")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if plan.isActive {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Label("Inactive", systemImage: "xmark.circle.fill")
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

