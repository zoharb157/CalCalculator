//
//  ScheduledMealEditorView.swift
//  playground
//
//  Editor for creating/editing scheduled meals with modern UI

import SwiftUI

struct ScheduledMealEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    let meal: ScheduledMeal?
    let onSave: (ScheduledMeal) -> Void
    
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
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedDays.isEmpty
    }
    
    var body: some View {
        let _ = localizationManager.currentLanguage
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Meal details section
                    mealDetailsSection
                    
                    // Category picker
                    categorySection
                    
                    // Time picker
                    timeSection
                    
                    // Days picker
                    daysSection
                    
                    // Quick select options
                    quickSelectSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(meal == nil 
                             ? localizationManager.localizedString(for: AppStrings.DietPlan.newScheduledMeal) 
                             : localizationManager.localizedString(for: AppStrings.DietPlan.editScheduledMeal))
            .id("nav-title-\(localizationManager.currentLanguage)")
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
    
    // MARK: - Meal Details Section
    
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
    
    // MARK: - Category Section
    
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
    
    // MARK: - Time Section
    
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
    
    // MARK: - Days Section
    
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
            
            // Days grid
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
    
    // MARK: - Quick Select Section
    
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
    
    private func saveMeal() {
        let daysOfWeek = Array(selectedDays).sorted()
        
        if let existingMeal = meal {
            existingMeal.name = name
            existingMeal.category = category
            existingMeal.time = time
            existingMeal.daysOfWeek = daysOfWeek
            onSave(existingMeal)
        } else {
            let newMeal = ScheduledMeal(
                name: name,
                category: category,
                time: time,
                daysOfWeek: daysOfWeek
            )
            onSave(newMeal)
        }
        
        HapticManager.shared.notification(.success)
        dismiss()
    }
}

#Preview {
    ScheduledMealEditorView(meal: nil) { _ in }
}
