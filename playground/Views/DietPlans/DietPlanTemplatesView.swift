//
//  DietPlanTemplatesView.swift
//  playground
//
//  Pre-built diet plan templates for quick setup
//

import SwiftUI
import SwiftData
import SDK

struct DietPlanTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    let onTemplateSelected: (DietPlanTemplate) -> Void
    
    @State private var selectedTemplate: DietPlanTemplate?
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
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
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.dietPlanTemplates))
                
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
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
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
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
                    Label("\(template.meals.count) \(localizationManager.localizedString(for: AppStrings.Food.meals))", systemImage: "fork.knife")
                        
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(template.difficulty.localizedName, systemImage: "gauge")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .id("difficulty-\(localizationManager.currentLanguage)")
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
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var customizing = false
    @State private var showingPaywall = false
    @State private var isSaving = false
    
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
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.scheduledMeals))
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
                        Task {
                            await useTemplate()
                        }
                    } label: {
                        Label(localizationManager.localizedString(for: AppStrings.DietPlan.useThisTemplate), systemImage: "checkmark.circle.fill")
                            
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
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.templatePreview))
                
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        dismiss()
                    }
                    
                }
            }
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
    
    private func useTemplate() async {
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
            // Convert template meals to data tuples
            let mealData = template.meals.map { meal in
                let daysOfWeek = meal.days.map { dayName -> Int in
                    let days = ["Sun": 1, "Mon": 2, "Tue": 3, "Wed": 4, "Thu": 5, "Fri": 6, "Sat": 7]
                    return days[dayName] ?? 1
                }
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                let time = formatter.date(from: meal.time) ?? Date()
                
                return (name: meal.name, category: meal.category, time: time, daysOfWeek: daysOfWeek)
            }
            
            // Use repository to create plan
            let plan = try dietPlanRepository.createDietPlan(
                name: template.name,
                description: template.description,
                isActive: true,
                dailyCalorieGoal: nil,
                scheduledMeals: mealData
            )
            
            // Schedule reminders before calling onUse
            let reminderService = MealReminderService.shared(context: modelContext)
            do {
                try await reminderService.requestAuthorization()
                try await reminderService.scheduleAllReminders()
            } catch {
                AppLogger.forClass("DietPlanTemplatesView").warning("Failed to schedule reminders", error: error)
                // Continue - reminders are not critical for plan creation
            }
            
            onUse(plan)
        } catch {
            AppLogger.forClass("DietPlanTemplatesView").error("Failed to create plan from template", error: error)
            HapticManager.shared.notification(.error)
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
        
        var localizedName: String {
            let localizationManager = LocalizationManager.shared
            switch self {
            case .easy: return localizationManager.localizedString(for: AppStrings.DietPlan.difficultyEasy)
            case .medium: return localizationManager.localizedString(for: AppStrings.DietPlan.difficultyMedium)
            case .hard: return localizationManager.localizedString(for: AppStrings.DietPlan.difficultyAdvanced)
            }
        }
    }
    
    /// Creates standalone ScheduledMeal objects without a parent DietPlan.
    /// Use this to avoid SwiftData auto-insertion issues.
    func createScheduledMeals() -> [ScheduledMeal] {
        return meals.map { templateMeal in
            let daysOfWeek = templateMeal.days.map { dayNameToInt($0) }
            let time = parseTime(templateMeal.time)
            
            return ScheduledMeal(
                name: templateMeal.name,
                category: templateMeal.category,
                time: time,
                daysOfWeek: daysOfWeek
            )
        }
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

