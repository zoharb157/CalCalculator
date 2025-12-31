//
//  ScheduledMealEditorView.swift
//  playground
//
//  Editor for creating/editing scheduled meals
//

import SwiftUI

struct ScheduledMealEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let meal: ScheduledMeal?
    let onSave: (ScheduledMeal) -> Void
    
    @State private var name: String
    @State private var category: MealCategory
    @State private var time: Date
    @State private var selectedDays: Set<Int> // 1 = Sunday, 7 = Saturday
    
    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    init(meal: ScheduledMeal?, onSave: @escaping (ScheduledMeal) -> Void) {
        self.meal = meal
        self.onSave = onSave
        
        if let meal = meal {
            _name = State(initialValue: meal.name)
            _category = State(initialValue: meal.category)
            _time = State(initialValue: meal.time)
            _selectedDays = State(initialValue: Set(meal.daysOfWeek))
        } else {
            _name = State(initialValue: "")
            _category = State(initialValue: .breakfast)
            _time = State(initialValue: Date())
            _selectedDays = State(initialValue: [])
        }
    }
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            Form {
                Section(localizationManager.localizedString(for: AppStrings.DietPlan.mealDetails)) {
                    TextField(localizationManager.localizedString(for: AppStrings.DietPlan.mealName), text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(MealCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                }
                
                Section(localizationManager.localizedString(for: AppStrings.DietPlan.schedule)) {
                    DatePicker(localizationManager.localizedString(for: AppStrings.DietPlan.time), selection: $time, displayedComponents: .hourAndMinute)
                    
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.repeatOn))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(1...7, id: \.self) { dayOfWeek in
                        Toggle(dayNames[dayOfWeek - 1], isOn: Binding(
                            get: { selectedDays.contains(dayOfWeek) },
                            set: { isSelected in
                                if isSelected {
                                    selectedDays.insert(dayOfWeek)
                                } else {
                                    selectedDays.remove(dayOfWeek)
                                }
                            }
                        ))
                    }
                }
                
                if selectedDays.isEmpty {
                    Section {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.selectAtLeastOneDay))
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(meal == nil ? localizationManager.localizedString(for: AppStrings.DietPlan.newScheduledMeal) : localizationManager.localizedString(for: AppStrings.DietPlan.editScheduledMeal))
                .id("nav-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.save)) {
                        saveMeal()
                    }
                    .disabled(name.isEmpty || selectedDays.isEmpty)
                }
            }
        }
    }
    
    private func saveMeal() {
        let daysOfWeek = Array(selectedDays).sorted()
        
        if let existingMeal = meal {
            // Update existing meal
            existingMeal.name = name
            existingMeal.category = category
            existingMeal.time = time
            existingMeal.daysOfWeek = daysOfWeek
            onSave(existingMeal)
        } else {
            // Create new meal
            let newMeal = ScheduledMeal(
                name: name,
                category: category,
                time: time,
                daysOfWeek: daysOfWeek
            )
            onSave(newMeal)
        }
        
        dismiss()
    }
}

#Preview {
    ScheduledMealEditorView(meal: nil) { _ in }
}


