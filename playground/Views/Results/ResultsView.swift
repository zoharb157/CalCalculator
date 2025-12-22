//
//  ResultsView.swift
//  playground
//
//  CalAI Clone - Meal analysis results with editable ingredients
//

import SwiftUI
import SDK

struct ResultsView: View {
    @Bindable var viewModel: ScanViewModel
    @State private var resultsVM: ResultsViewModel
    @State private var editingMealName = false
    @State private var mealNameText: String
    @State private var showingFixResult = false
    @State private var foodHintText = ""
    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk

    /// Callback to notify parent when meal is saved
    var onMealSaved: (() -> Void)?

    init(viewModel: ScanViewModel, meal: Meal, onMealSaved: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self._resultsVM = State(initialValue: ResultsViewModel(meal: meal))
        self._mealNameText = State(initialValue: meal.name)
        self.onMealSaved = onMealSaved
    }

    var body: some View {
        NavigationStack {
            contentScrollView
                .navigationTitle("Analysis Results")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarContent
                }
                .sheet(isPresented: $showingFixResult) {
                    fixResultSheet
                }
                .fullScreenCover(isPresented: $showPaywall) {
                    SDKView(
                        model: sdk,
                        page: .splash,
                        show: $showPaywall,
                        backgroundColor: .white,
                        ignoreSafeArea: true
                    )
                }
        }
    }

    // MARK: - Private Views

    private var contentScrollView: some View {
        ScrollView {
            mainContent
                .padding(.vertical)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 20) {
            heroImage
            mealNameSection
            macrosCard
            confidenceSection
            fixResultButton
            ingredientsSection
            notesSection
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        if let image = viewModel.pendingImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
        }
    }

    private var mealNameSection: some View {
        MealNameSection(
            name: $mealNameText,
            isEditing: $editingMealName,
            onSave: { resultsVM.updateMealName(mealNameText) }
        )
        .padding(.horizontal)
    }

    private var macrosCard: some View {
        TotalMacrosCard(macros: resultsVM.totalMacros)
            .padding(.horizontal)
    }

    @ViewBuilder
    private var confidenceSection: some View {
        if resultsVM.meal.confidence > 0 {
            ConfidenceIndicator(confidence: resultsVM.meal.confidence)
                .padding(.horizontal)
        }
    }

    private var fixResultButton: some View {
        Button {
            showingFixResult = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.body)
                Text("Fix Result")
                    .fontWeight(.medium)
            }
            .foregroundStyle(.blue)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.1))
            )
        }
        .padding(.horizontal)
    }

    private var fixResultSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What is this food?")
                        .font(.headline)

                    Text("Describe the food to help us analyze it more accurately.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        "e.g., Homemade chicken caesar salad", text: $foodHintText, axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .padding(.horizontal)

                    Text(
                        "Be specific about ingredients, portion sizes, or cooking methods if possible."
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal)
                }

                Spacer()

                Button {
                    submitFixResult()
                } label: {
                    HStack {
                        if viewModel.isAnalyzing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Re-analyze")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                foodHintText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.gray : Color.blue)
                    )
                    .foregroundStyle(.white)
                }
                .disabled(
                    foodHintText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.isAnalyzing
                )
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.top)
            .navigationTitle("Fix Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingFixResult = false
                        foodHintText = ""
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var ingredientsSection: some View {
        IngredientsSection(
            items: resultsVM.items,
            onUpdatePortion: { item, newPortion in
                resultsVM.updateItemPortion(item, newPortion: newPortion)
            },
            onDelete: { item in
                resultsVM.deleteItem(item)
            }
        )
        .padding(.horizontal)
    }

    @ViewBuilder
    private var notesSection: some View {
        if let notes = resultsVM.meal.notes, !notes.isEmpty {
            NotesSection(notes: notes)
                .padding(.horizontal)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                saveMeal()
            }
            .fontWeight(.semibold)
        }
    }

    private func saveMeal() {
        guard isSubscribed else {
            showPaywall = true
            return
        }
        
        resultsVM.updateMealName(mealNameText)
        viewModel.pendingMeal = resultsVM.meal

        Task {
            let success = await viewModel.savePendingMeal()
            if success {
                onMealSaved?()
                dismiss()
            }
        }
    }

    private func submitFixResult() {
        let hint = foodHintText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hint.isEmpty else { return }

        showingFixResult = false
        dismiss()

        Task {
            await viewModel.analyzeWithHint(hint)
        }

        foodHintText = ""
    }
}

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = ScanViewModel(
        repository: repository,
        analysisService: CaloriesAPIService(),
        imageStorage: .shared
    )

    let meal = Meal(
        name: "Chicken Shawarma Bowl",
        confidence: 0.78,
        notes: "Estimates vary by recipe and portion size.",
        items: [
            MealItem(
                name: "Chicken shawarma", portion: 180, unit: "g", calories: 320, proteinG: 35,
                carbsG: 3, fatG: 18),
            MealItem(
                name: "Rice", portion: 150, unit: "g", calories: 190, proteinG: 4, carbsG: 41,
                fatG: 1),
        ]
    )

    ResultsView(viewModel: viewModel, meal: meal)
}
