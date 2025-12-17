//
//  ResultsView.swift
//  playground
//
//  CalAI Clone - Meal analysis results with editable ingredients
//

import SwiftUI

struct ResultsView: View {
    @Bindable var viewModel: ScanViewModel
    @State private var resultsVM: ResultsViewModel
    @State private var editingMealName = false
    @State private var mealNameText: String
    @Environment(\.dismiss) private var dismiss
    
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
            MealItem(name: "Chicken shawarma", portion: 180, unit: "g", calories: 320, proteinG: 35, carbsG: 3, fatG: 18),
            MealItem(name: "Rice", portion: 150, unit: "g", calories: 190, proteinG: 4, carbsG: 41, fatG: 1)
        ]
    )
    
    ResultsView(viewModel: viewModel, meal: meal)
}
