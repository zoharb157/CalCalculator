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
            .navigationTitle("Create Diet Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
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
            
            Text("Step \(currentStep + 1) of \(steps.count): \(steps[currentStep])")
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
            
            Text("Name Your Diet Plan")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Give your diet plan a memorable name")
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
            Text("Choose a Template (Optional)")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            Text("Start with a template or create from scratch")
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
                            
                            Text("Start from Scratch")
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
                Text("Schedule Your Meals")
                    .font(.title2)
                    .fontWeight(.bold)
                
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
                ContentUnavailableView(
                    "No Meals Scheduled",
                    systemImage: "fork.knife.circle",
                    description: Text("Add your first scheduled meal")
                )
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
                Text("Review Your Plan")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // Plan summary
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Plan Name")
                            .font(.headline)
                        Spacer()
                        Text(planName.isEmpty ? "Untitled" : planName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Meals")
                            .font(.headline)
                        Spacer()
                        Text("\(meals.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Days Active")
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
                        Text("Scheduled Meals")
                            .font(.headline)
                            .padding(.horizontal)
                        
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
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
            }
            
            Spacer()
            
            if currentStep < steps.count - 1 {
                Button("Next") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentStep == 0 && planName.isEmpty)
            } else {
                Button("Create Plan") {
                    createPlan()
                }
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

