//
//  TextFoodLogView.swift
//  playground
//
//  AI-powered text description food logging view
//

import SwiftUI

struct TextFoodLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.localization) private var localization
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var viewModel: LogExperienceViewModel
    @State private var inputText: String = ""
    @State private var showingResults = false
    @FocusState private var isInputFocused: Bool

    // Placeholder suggestions
    private let suggestions = [
        "2 eggs with toast and butter",
        "Chicken salad with olive oil dressing",
        "A cup of coffee with milk",
        "Grilled salmon with rice and vegetables",
        "Protein shake after workout",
        "Apple and peanut butter snack",
    ]

    init() {
        let persistence = PersistenceController.shared
        let repository = MealRepository(context: persistence.mainContext)
        _viewModel = State(initialValue: LogExperienceViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isAnalyzing {
                    analyzingView
                } else if !viewModel.analyzedFoods.isEmpty {
                    resultsView
                } else {
                    inputView
                }
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Food.describeYourFood))
                .id("describe-food-title-\(localizationManager.currentLanguage)")
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
            }
            .alert(localizationManager.localizedString(for: AppStrings.Common.error), isPresented: $viewModel.showError) {
                Button(localizationManager.localizedString(for: AppStrings.Common.ok), role: .cancel) {}
                    .id("ok-text-log-\(localizationManager.currentLanguage)")
            } message: {
                Text(viewModel.errorMessage ?? localizationManager.localizedString(for: AppStrings.Common.somethingWentWrong))
                    .id("error-message-\(localizationManager.currentLanguage)")
            }
            .alert(localizationManager.localizedString(for: AppStrings.Common.success), isPresented: $viewModel.showSuccess) {
                Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                    dismiss()
                }
                .id("done-text-log-\(localizationManager.currentLanguage)")
            } message: {
                Text(viewModel.successMessage ?? localizationManager.localizedString(for: AppStrings.Food.foodSaved))
                    .id("success-message-\(localizationManager.currentLanguage)")
            }
        }
    }

    // MARK: - Input View

    private var inputView: some View {
        VStack(spacing: 24) {
            // Header illustration
            VStack(spacing: 12) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(localization.localizedString(for: "Tell us what you ate"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(
                    localization.localizedString(for: "Describe your meal in natural language and we'll calculate the nutrition for you")
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
            .padding(.top, 20)

            // Text input
            VStack(alignment: .leading, spacing: 8) {
                TextField(localization.localizedString(for: "I had..."), text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(3...6)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .focused($isInputFocused)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isInputFocused ? Color.blue : Color.clear, lineWidth: 2)
                    )

                Text("\(inputText.count)/500")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal)

            // Suggestions
            VStack(alignment: .leading, spacing: 12) {
                Text(localizationManager.localizedString(for: AppStrings.Food.trySaying))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .id("try-saying-\(localizationManager.currentLanguage)")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            SuggestionChip(text: suggestion) {
                                inputText = suggestion
                                isInputFocused = false
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()

            // Category selector
            VStack(alignment: .leading, spacing: 8) {
                Text(localization.localizedString(for: "Meal Category"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Picker("Category", selection: $viewModel.selectedCategory) {
                    ForEach(MealCategory.allCases, id: \.self) { category in
                        Label(category.displayName, systemImage: category.icon)
                            .tag(category)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            // Analyze button
            Button {
                isInputFocused = false
                viewModel.textInput = inputText
                Task {
                    await viewModel.analyzeTextInput()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text(localizationManager.localizedString(for: AppStrings.Food.analyzeWithAI))
                    .id("analyze-ai-text-\(localizationManager.currentLanguage)")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? [.gray, .gray]
                            : [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding()
        }
    }

    // MARK: - Analyzing View

    private var analyzingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text(localizationManager.localizedString(for: AppStrings.Food.analyzingYourMeal))
                .id("analyzing-meal-text-\(localizationManager.currentLanguage)")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(localizationManager.localizedString(for: AppStrings.Food.usingAIToIdentify))
                .id("using-ai-text-\(localizationManager.currentLanguage)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Progress bar
            ProgressView(value: viewModel.analysisProgress)
                .progressViewStyle(.linear)
                .frame(width: 200)

            Text("\(Int(viewModel.analysisProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Summary header
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)

                    Text(localizationManager.localizedString(for: AppStrings.Food.analysisComplete))
                    .id("analysis-complete-\(localizationManager.currentLanguage)")
                        .font(.headline)
                }

                // Total nutrition summary
                HStack(spacing: 20) {
                    NutritionBadge(
                        value: "\(viewModel.totalAnalyzedCalories)",
                        label: "Calories",
                        color: .orange
                    )

                    NutritionBadge(
                        value: "\(viewModel.totalAnalyzedMacros.proteinG.formattedMacro)g",
                        label: "Protein",
                        color: .blue
                    )

                    NutritionBadge(
                        value: "\(viewModel.totalAnalyzedMacros.carbsG.formattedMacro)g",
                        label: "Carbs",
                        color: .green
                    )

                    NutritionBadge(
                        value: "\(viewModel.totalAnalyzedMacros.fatG.formattedMacro)g",
                        label: "Fat",
                        color: .purple
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))

            // Foods list
            List {
                Section(localizationManager.localizedString(for: AppStrings.Food.identifiedFoods)) {
                    ForEach(viewModel.analyzedFoods) { food in
                        FoodResultRow(food: food)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.removeAnalyzedFood(food)
                                } label: {
                                    Label(localizationManager.localizedString(for: AppStrings.Common.remove), systemImage: "trash")
                                        .id("remove-text-log-\(localizationManager.currentLanguage)")
                                }
                            }
                    }
                }
            }
            .listStyle(.insetGrouped)

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    Task {
                        let success = await viewModel.saveAnalyzedFoods()
                        if success {
                            // Success alert will show and dismiss
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text(localizationManager.localizedString(for: AppStrings.Food.saveMeal))
                                .id("save-meal-text-log-\(localizationManager.currentLanguage)")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(14)
                }
                .disabled(viewModel.isLoading || viewModel.analyzedFoods.isEmpty)

                Button {
                    viewModel.analyzedFoods = []
                    inputText = ""
                } label: {
                    Text(localizationManager.localizedString(for: AppStrings.Food.startOver))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .id("start-over-\(localizationManager.currentLanguage)")
                }
            }
            .padding()
        }
    }
}

// MARK: - Suggestion Chip

struct SuggestionChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Nutrition Badge

struct NutritionBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Food Result Row

struct FoodResultRow: View {
    let food: FoodLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(food.name)
                    .font(.headline)

                Spacer()

                Text("\(food.calories) cal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }

            HStack(spacing: 16) {
                MacroLabel(value: food.proteinG, label: "Protein", color: .blue)
                MacroLabel(value: food.carbsG, label: "Carbs", color: .green)
                MacroLabel(value: food.fatG, label: "Fat", color: .purple)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Macro Label

struct MacroLabel: View {
    let value: Double
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text("\(value.formattedMacro)g \(label)")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    TextFoodLogView()
}
