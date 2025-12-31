//
//  QuickLogView.swift
//  playground
//
//  Streamlined quick food and exercise logging interface
//

import SwiftUI
import SwiftData

enum QuickLogType: String, CaseIterable {
    case food = "food"
    case exercise = "exercise"

    var displayName: String {
        switch self {
        case .food: return "Food"
        case .exercise: return "Exercise"
        }
    }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .exercise: return "figure.run"
        }
    }

    var color: Color {
        switch self {
        case .food: return .green
        case .exercise: return .orange
        }
    }
}

struct QuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var selectedType: QuickLogType = .food
    @State private var viewModel: LogExperienceViewModel
    @State private var repository: MealRepository

    // Food quick log state
    @State private var foodDescription: String = ""
    @State private var quickCalories: String = ""

    // Exercise quick log state
    @State private var exerciseDescription: String = ""
    @State private var exerciseCalories: String = ""
    @State private var exerciseDuration: String = "30"

    @State private var isLogging = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    init() {
        let persistence = PersistenceController.shared
        let repository = MealRepository(context: persistence.mainContext)
        _viewModel = State(initialValue: LogExperienceViewModel(repository: repository))
        _repository = State(initialValue: repository)
    }

    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            VStack(spacing: 0) {
                // Type Selector
                typeSelector

                // Content based on selected type
                ScrollView {
                    VStack(spacing: 24) {
                        if selectedType == .food {
                            foodQuickLogContent
                        } else {
                            exerciseQuickLogContent
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)

                // Save Button
                logButton
            }
            .navigationTitle(LocalizationManager.shared.localizedString(for: "Quick Save"))
                .id("quick-save-title-\(LocalizationManager.shared.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .alert("Saved Successfully!", isPresented: $showSuccess) {
                Button(localizationManager.localizedString(for: AppStrings.Common.ok)) {
                    dismiss()
                }
            } message: {
                Text(
                    selectedType == .food
                        ? "Your food has been logged."
                        : "Your exercise has been logged.")
            }
            .alert("Error", isPresented: $showError) {
                Button(localizationManager.localizedString(for: AppStrings.Common.ok)) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Type Selector

    private var typeSelector: some View {
        HStack(spacing: 0) {
            ForEach(QuickLogType.allCases, id: \.self) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedType = type
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: type.icon)
                        Text(type.displayName)
                    }
                    .font(.headline)
                    .foregroundColor(selectedType == type ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedType == type ? type.color : Color.clear)
                    )
                }
            }
        }
        .padding(4)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 16)
    }

    // MARK: - Food Quick Log Content

    private var foodQuickLogContent: some View {
        VStack(spacing: 20) {
            // Description input
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizationManager.shared.localizedString(for: "What did you eat?"))
                    .id("what-did-you-eat-\(LocalizationManager.shared.currentLanguage)")
                    .font(.headline)

                TextField(
                    "e.g., Chicken salad with dressing", text: $foodDescription, axis: .vertical
                )
                .textFieldStyle(.plain)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .lineLimit(2...4)
            }

            // Quick calories input
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizationManager.shared.localizedString(for: "Estimated Calories"))
                    .id("estimated-calories-\(LocalizationManager.shared.currentLanguage)")
                    .font(.headline)

                HStack {
                    TextField("0", text: $quickCalories)
                        .keyboardType(.numberPad)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 120)
                        .keyboardDoneButton()

                    Text(localizationManager.localizedString(for: AppStrings.Food.kcal))
                        .id("kcal-food-\(localizationManager.currentLanguage)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Quick presets
            VStack(alignment: .leading, spacing: 12) {
                Text(localizationManager.localizedString(for: AppStrings.Food.quickPresets))
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    QuickPresetButton(title: localizationManager.localizedString(for: AppStrings.Food.lightSnack), calories: 150) {
                        quickCalories = "150"
                        if foodDescription.isEmpty {
                            foodDescription = localizationManager.localizedString(for: AppStrings.Food.lightSnack)
                        }
                    }

                    QuickPresetButton(title: localizationManager.localizedString(for: AppStrings.Food.smallMeal), calories: 350) {
                        quickCalories = "350"
                        if foodDescription.isEmpty {
                            foodDescription = localizationManager.localizedString(for: AppStrings.Food.smallMeal)
                        }
                    }

                    QuickPresetButton(title: localizationManager.localizedString(for: AppStrings.Food.regularMeal), calories: 550) {
                        quickCalories = "550"
                        if foodDescription.isEmpty {
                            foodDescription = localizationManager.localizedString(for: AppStrings.Food.regularMeal)
                        }
                    }

                    QuickPresetButton(title: localizationManager.localizedString(for: AppStrings.Food.largeMeal), calories: 800) {
                        quickCalories = "800"
                        if foodDescription.isEmpty {
                            foodDescription = localizationManager.localizedString(for: AppStrings.Food.largeMeal)
                        }
                    }
                }
            }

            // Category selector
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizationManager.shared.localizedString(for: "Category"))
                    .id("category-\(LocalizationManager.shared.currentLanguage)")
                    .font(.headline)

                Picker("Category", selection: $viewModel.selectedCategory) {
                    ForEach(MealCategory.allCases, id: \.self) { category in
                        Label(category.displayName, systemImage: category.icon)
                            .tag(category)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Exercise Quick Log Content

    private var exerciseQuickLogContent: some View {
        VStack(spacing: 20) {
            // Exercise description
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizationManager.shared.localizedString(for: "What exercise did you do?"))
                    .id("what-exercise-\(LocalizationManager.shared.currentLanguage)")
                    .font(.headline)

                TextField(
                    "e.g., Morning jog, Weight training", text: $exerciseDescription,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .lineLimit(2...4)
            }

            // Duration input
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizationManager.shared.localizedString(for: AppStrings.Exercise.duration))
                    .id("duration-\(LocalizationManager.shared.currentLanguage)")
                    .font(.headline)

                HStack {
                    TextField("30", text: $exerciseDuration)
                        .keyboardType(.numberPad)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                        .keyboardDoneButton()

                    Text(LocalizationManager.shared.localizedString(for: "minutes"))
                        .id("minutes-\(LocalizationManager.shared.currentLanguage)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Calories burned input
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizationManager.shared.localizedString(for: "Calories Burned"))
                    .id("calories-burned-\(LocalizationManager.shared.currentLanguage)")
                    .font(.headline)

                HStack {
                    TextField("0", text: $exerciseCalories)
                        .keyboardType(.numberPad)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 120)
                        .keyboardDoneButton()

                    Text(localizationManager.localizedString(for: AppStrings.Food.kcal))
                        .id("kcal-food-\(localizationManager.currentLanguage)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Quick exercise presets
            VStack(alignment: .leading, spacing: 12) {
                Text(localizationManager.localizedString(for: AppStrings.Food.quickPresets))
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    ExercisePresetButton(
                        title: localizationManager.localizedString(for: AppStrings.Exercise.walk), icon: "figure.walk", duration: 30, calories: 120
                    ) {
                        exerciseDescription = localizationManager.localizedString(for: AppStrings.Exercise.walk)
                        exerciseDuration = "30"
                        exerciseCalories = "120"
                    }

                    ExercisePresetButton(
                        title: localizationManager.localizedString(for: AppStrings.Exercise.run), icon: "figure.run", duration: 30, calories: 300
                    ) {
                        exerciseDescription = localizationManager.localizedString(for: AppStrings.Exercise.run)
                        exerciseDuration = "30"
                        exerciseCalories = "300"
                    }

                    ExercisePresetButton(
                        title: localizationManager.localizedString(for: AppStrings.Exercise.weights), icon: "dumbbell.fill", duration: 45, calories: 200
                    ) {
                        exerciseDescription = localizationManager.localizedString(for: AppStrings.Exercise.weights)
                        exerciseDuration = "45"
                        exerciseCalories = "200"
                    }

                    ExercisePresetButton(
                        title: localizationManager.localizedString(for: AppStrings.Exercise.cycling), icon: "bicycle", duration: 30, calories: 250
                    ) {
                        exerciseDescription = localizationManager.localizedString(for: AppStrings.Exercise.cycling)
                        exerciseDuration = "30"
                        exerciseCalories = "250"
                    }
                }
            }
        }
    }

    // MARK: - Save Button

    private var logButton: some View {
        Button {
            Task {
                await logEntry()
            }
        } label: {
            HStack {
                if isLogging {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text(selectedType == .food ? localizationManager.localizedString(for: AppStrings.Food.saveFood) : localizationManager.localizedString(for: AppStrings.Exercise.saveExercise))
                        .id("save-button-\(localizationManager.currentLanguage)")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isValid ? selectedType.color : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!isValid || isLogging)
        .padding()
    }

    // MARK: - Validation

    private var isValid: Bool {
        if selectedType == .food {
            return !foodDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && Int(quickCalories) != nil
                && (Int(quickCalories) ?? 0) > 0
        } else {
            return !exerciseDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && Int(exerciseCalories) != nil
                && (Int(exerciseCalories) ?? 0) > 0
        }
    }

    // MARK: - Log Entry

    private func logEntry() async {
        isLogging = true
        defer { isLogging = false }

        if selectedType == .food {
            let entry = FoodLogEntry(
                name: foodDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                calories: Int(quickCalories) ?? 0,
                proteinG: 0,
                carbsG: 0,
                fatG: 0,
                source: .quickAdd
            )

            let success = await viewModel.saveFoodEntry(entry)
            if success {
                HapticManager.shared.notification(.success)
                showSuccess = true
            }
        } else {
            // Save exercise using repository pattern with proper error handling
            do {
                let exercise = Exercise(
                    type: .manual,
                    calories: Int(exerciseCalories) ?? 0,
                    duration: Int(exerciseDuration) ?? 30,
                    intensity: .medium,
                    notes: exerciseDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                // Use repository for consistent saving
                try repository.saveExercise(exercise)
                
                // Notify that an exercise was saved
                NotificationCenter.default.post(name: .exerciseSaved, object: nil)
                
                HapticManager.shared.notification(.success)
                showSuccess = true
            } catch {
                errorMessage = "Failed to save exercise: \(error.localizedDescription)"
                showError = true
                HapticManager.shared.notification(.error)
                print("❌ Error saving exercise: \(error)")
            }
        }
    }
}

// MARK: - Quick Preset Button

struct QuickPresetButton: View {
    let title: String
    let calories: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)

                Text("\(calories) cal")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Preset Button

struct ExercisePresetButton: View {
    let title: String
    let icon: String
    let duration: Int
    let calories: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.orange)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)

                Text("\(duration)min • \(calories)cal")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickLogView()
}
