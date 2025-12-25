//
//  DietPlanTemplatesView.swift
//  playground
//
//  Pre-built diet plan templates for quick setup
//

import SwiftUI
import SwiftData

struct DietPlanTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let onTemplateSelected: (DietPlanTemplate) -> Void
    
    @State private var selectedTemplate: DietPlanTemplate?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(DietPlanTemplate.allTemplates) { template in
                        TemplateCard(template: template) {
                            selectedTemplate = template
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Diet Plan Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedTemplate) { template in
                TemplatePreviewView(template: template) { plan in
                    onTemplateSelected(template)
                    dismiss()
                }
            }
        }
    }
}

struct TemplateCard: View {
    let template: DietPlanTemplate
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: template.icon)
                        .font(.title)
                        .foregroundColor(template.color)
                        .frame(width: 50)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(template.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                
                // Quick stats
                HStack(spacing: 16) {
                    Label("\(template.meals.count) meals", systemImage: "fork.knife")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(template.difficulty.rawValue, systemImage: "gauge")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct TemplatePreviewView: View {
    let template: DietPlanTemplate
    let onUse: (DietPlan) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var customizing = false
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: template.icon)
                                .font(.largeTitle)
                                .foregroundColor(template.color)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(template.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Meals preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scheduled Meals")
                            .font(.headline)
                        
                        ForEach(template.meals, id: \.name) { meal in
                            MealPreviewRow(meal: meal)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Use template button
                    Button {
                        useTemplate()
                    } label: {
                        Label("Use This Template", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(template.color)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Template Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func useTemplate() {
        do {
            let plan = template.createDietPlan()
            try dietPlanRepository.saveDietPlan(plan)
            
            // Schedule reminders
            Task {
                let reminderService = MealReminderService.shared(context: modelContext)
                try? await reminderService.requestAuthorization()
                try? await reminderService.scheduleAllReminders()
            }
            
            onUse(plan)
        } catch {
            print("Failed to create plan from template: \(error)")
        }
    }
}

struct MealPreviewRow: View {
    let meal: TemplateScheduledMeal
    
    var body: some View {
        HStack {
            Image(systemName: meal.category.icon)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Label(meal.time, systemImage: "clock")
                    Label(meal.days.joined(separator: ", "), systemImage: "calendar")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Template Models

struct DietPlanTemplate: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let color: Color
    let difficulty: Difficulty
    let meals: [TemplateScheduledMeal]
    
    enum Difficulty: String {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Advanced"
    }
    
    func createDietPlan() -> DietPlan {
        let scheduledMeals = meals.map { templateMeal in
            let daysOfWeek = templateMeal.days.map { dayNameToInt($0) }
            let time = parseTime(templateMeal.time)
            
            return ScheduledMeal(
                name: templateMeal.name,
                category: templateMeal.category,
                time: time,
                daysOfWeek: daysOfWeek
            )
        }
        
        return DietPlan(
            name: name,
            planDescription: description,
            isActive: true,
            scheduledMeals: scheduledMeals
        )
    }
    
    private func dayNameToInt(_ day: String) -> Int {
        let days = ["Sun": 1, "Mon": 2, "Tue": 3, "Wed": 4, "Thu": 5, "Fri": 6, "Sat": 7]
        return days[day] ?? 1
    }
    
    private func parseTime(_ timeString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        // Default to 8:00 AM if parsing fails
        if let date = formatter.date(from: timeString) {
            return date
        }
        // Fallback: create a date with 8:00 AM
        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
    
    static let allTemplates: [DietPlanTemplate] = [
        DietPlanTemplate(
            name: "Balanced 3-Meal Plan",
            description: "Three balanced meals per day with consistent timing",
            icon: "leaf.fill",
            color: .green,
            difficulty: .easy,
            meals: [
                TemplateScheduledMeal(name: "Breakfast", category: .breakfast, time: "8:00 AM", days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]),
                TemplateScheduledMeal(name: "Lunch", category: .lunch, time: "1:00 PM", days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]),
                TemplateScheduledMeal(name: "Dinner", category: .dinner, time: "7:00 PM", days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
            ]
        ),
        DietPlanTemplate(
            name: "Intermittent Fasting (16:8)",
            description: "16-hour fast with 8-hour eating window",
            icon: "clock.fill",
            color: .blue,
            difficulty: .medium,
            meals: [
                TemplateScheduledMeal(name: "First Meal", category: .lunch, time: "12:00 PM", days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]),
                TemplateScheduledMeal(name: "Second Meal", category: .dinner, time: "7:00 PM", days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
            ]
        ),
        DietPlanTemplate(
            name: "High Protein Plan",
            description: "Protein-focused meals throughout the day",
            icon: "dumbbell.fill",
            color: .orange,
            difficulty: .medium,
            meals: [
                TemplateScheduledMeal(name: "Protein Breakfast", category: .breakfast, time: "7:30 AM", days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]),
                TemplateScheduledMeal(name: "Protein Lunch", category: .lunch, time: "12:30 PM", days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]),
                TemplateScheduledMeal(name: "Protein Snack", category: .snack, time: "4:00 PM", days: ["Mon", "Tue", "Wed", "Thu", "Fri"]),
                TemplateScheduledMeal(name: "Protein Dinner", category: .dinner, time: "7:00 PM", days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
            ]
        ),
        DietPlanTemplate(
            name: "Mediterranean Style",
            description: "Mediterranean diet with varied meal times",
            icon: "sun.max.fill",
            color: .yellow,
            difficulty: .easy,
            meals: [
                TemplateScheduledMeal(name: "Mediterranean Breakfast", category: .breakfast, time: "8:30 AM", days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]),
                TemplateScheduledMeal(name: "Mediterranean Lunch", category: .lunch, time: "1:30 PM", days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]),
                TemplateScheduledMeal(name: "Mediterranean Dinner", category: .dinner, time: "7:30 PM", days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
            ]
        ),
        DietPlanTemplate(
            name: "Workday Focus",
            description: "Optimized for Monday-Friday work schedule",
            icon: "briefcase.fill",
            color: .purple,
            difficulty: .easy,
            meals: [
                TemplateScheduledMeal(name: "Morning Meal", category: .breakfast, time: "7:00 AM", days: ["Mon", "Tue", "Wed", "Thu", "Fri"]),
                TemplateScheduledMeal(name: "Lunch Break", category: .lunch, time: "12:30 PM", days: ["Mon", "Tue", "Wed", "Thu", "Fri"]),
                TemplateScheduledMeal(name: "Evening Meal", category: .dinner, time: "7:00 PM", days: ["Mon", "Tue", "Wed", "Thu", "Fri"])
            ]
        )
    ]
}

struct TemplateScheduledMeal {
    let name: String
    let category: MealCategory
    let time: String // e.g., "8:00 AM"
    let days: [String] // e.g., ["Mon", "Wed", "Fri"]
}

#Preview {
    DietPlanTemplatesView { template in
        print("Selected: \(template.name)")
    }
}

