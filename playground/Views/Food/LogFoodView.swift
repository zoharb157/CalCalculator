//
//  LogFoodView.swift
//
//  Log Food screen with AI text analysis, manual entry, quick add, and recent foods
//

import SwiftUI

struct LogFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var viewModel: LogExperienceViewModel
    @State private var selectedTab: FoodTab = .all
    @State private var showingManualEntry = false
    @State private var showingAnalyzedResults = false
    @State private var showingVoiceLog = false
    @FocusState private var isSearchFocused: Bool

    init() {
        let persistence = PersistenceController.shared
        let repository = MealRepository(context: persistence.mainContext)
        _viewModel = State(initialValue: LogExperienceViewModel(repository: repository))
    }

    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            VStack(spacing: 0) {
                // Tabs
                tabsHeader

                // Search/Input Bar
                searchInputBar

                // Content based on state
                contentView
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Food.saveFood))
                .id("save-food-title-\(localizationManager.currentLanguage)")
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
                    .id("ok-btn-\(localizationManager.currentLanguage)")
            } message: {
                Text(viewModel.errorMessage ?? localizationManager.localizedString(for: AppStrings.Common.errorOccurred))
                    .id("error-log-food-\(localizationManager.currentLanguage)")
            }
            .alert(localizationManager.localizedString(for: AppStrings.Common.success), isPresented: $viewModel.showSuccess) {
                Button(localizationManager.localizedString(for: AppStrings.Common.ok), role: .cancel) {
                    dismiss()
                }
                .id("ok-log-food-\(localizationManager.currentLanguage)")
            } message: {
                Text(viewModel.successMessage ?? localizationManager.localizedString(for: AppStrings.Food.foodSavedSuccessfully))
                    .id("success-log-food-\(localizationManager.currentLanguage)")
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualFoodEntryView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingVoiceLog) {
                VoiceLogView()
            }
            .sheet(isPresented: $showingAnalyzedResults) {
                AnalyzedFoodsResultView(viewModel: viewModel) {
                    dismiss()
                }
            }
            .onChange(of: viewModel.analyzedFoods) { _, newFoods in
                if !newFoods.isEmpty {
                    showingAnalyzedResults = true
                }
            }
        }
    }

    // MARK: - Tabs Header

    private var tabsHeader: some View {
        HStack(spacing: 0) {
            FoodTabButton(title: localizationManager.localizedString(for: AppStrings.Food.all), isSelected: selectedTab == .all) {
                selectedTab = .all
            }
            FoodTabButton(title: localizationManager.localizedString(for: AppStrings.Food.quickAdd), isSelected: selectedTab == .quickAdd) {
                selectedTab = .quickAdd
            }
            FoodTabButton(title: localizationManager.localizedString(for: AppStrings.Food.recent), isSelected: selectedTab == .recent) {
                selectedTab = .recent
            }
            FoodTabButton(title: localizationManager.localizedString(for: AppStrings.Food.saved), isSelected: selectedTab == .savedFoods) {
                selectedTab = .savedFoods
            }
            .id("tabs-\(localizationManager.currentLanguage)")
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Search Input Bar

    private var searchInputBar: some View {
        VStack(spacing: 12) {
            // Text input
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Describe what you ate...", text: $viewModel.textInput, axis: .vertical)
                    .focused($isSearchFocused)
                    .lineLimit(1...3)
                    .submitLabel(.search)
                    .onSubmit {
                        Task {
                            await viewModel.analyzeTextInput()
                        }
                    }

                if !viewModel.textInput.isEmpty {
                    Button {
                        viewModel.textInput = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Analyze button (only show when there's text)
            if !viewModel.textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    isSearchFocused = false
                    Task {
                        await viewModel.analyzeTextInput()
                    }
                } label: {
                    HStack {
                        if viewModel.isAnalyzing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                            Text(localizationManager.localizedString(for: AppStrings.Food.analyzeWithAI))
                                .id("analyze-ai-\(localizationManager.currentLanguage)")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(viewModel.isAnalyzing)
            }

            // Category selector
            HStack {
                Text(localizationManager.localizedString(for: AppStrings.Food.categoryColon))
                    .id("category-label-\(localizationManager.currentLanguage)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Category", selection: $viewModel.selectedCategory) {
                    ForEach(MealCategory.allCases, id: \.self) { category in
                        Label(category.displayName, systemImage: category.icon)
                            .tag(category)
                    }
                }
                .pickerStyle(.menu)

                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isAnalyzing {
            analyzingView
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case .all:
                        quickAddSection
                        recentFoodsSection
                    case .quickAdd:
                        quickAddGridSection
                    case .recent:
                        recentFoodsFullSection
                    case .savedFoods:
                        savedFoodsSection
                    default:
                        quickAddSection
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)

            // Bottom action buttons
            actionButtons
        }
    }

    // MARK: - Analyzing View

    private var analyzingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView(value: viewModel.analysisProgress)
                .progressViewStyle(.linear)
                .frame(width: 200)

            Text(localizationManager.localizedString(for: AppStrings.Food.analyzingYourFood))
                .id("analyzing-food-\(localizationManager.currentLanguage)")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(localizationManager.localizedString(for: AppStrings.Food.usingAIToIdentifyCalories))
                .id("ai-identify-\(localizationManager.currentLanguage)")
                .font(.subheadline)
                .foregroundColor(Color(.tertiaryLabel))

            Spacer()
        }
        .padding()
    }

    // MARK: - Quick Add Section

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.Food.quickAdd))
                .id("quick-add-\(localizationManager.currentLanguage)")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(QuickAddFood.commonFoods.prefix(6)) { food in
                    QuickAddFoodButton(food: food) {
                        Task {
                            let success = await viewModel.quickAddFood(food)
                            if success {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    private var quickAddGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.Food.commonFoods))
                .id("common-foods-\(localizationManager.currentLanguage)")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(QuickAddFood.commonFoods) { food in
                    QuickAddFoodButton(food: food) {
                        Task {
                            let success = await viewModel.quickAddFood(food)
                            if success {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Foods Section

    private var recentFoodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.recentFoods.isEmpty {
                Text(localizationManager.localizedString(for: AppStrings.Food.recentFoods))
                    .id("recent-foods-\(localizationManager.currentLanguage)")
                    .font(.headline)

                ForEach(viewModel.recentFoods.prefix(5)) { food in
                    RecentFoodRow(food: food, isSaved: viewModel.isSaved(food)) {
                        Task {
                            let success = await viewModel.saveFoodEntry(food)
                            if success {
                                dismiss()
                            }
                        }
                    } onSave: {
                        if viewModel.isSaved(food) {
                            viewModel.removeFromFavorites(food)
                        } else {
                            viewModel.saveToFavorites(food)
                        }
                    }
                }
            }
        }
    }

    private var recentFoodsFullSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.recentFoods.isEmpty {
                emptyStateView(
                    icon: "clock",
                    title: localizationManager.localizedString(for: AppStrings.Food.noRecentFoods),
                    message: "Foods you log will appear here for quick access"
                )
            } else {
                Text(localizationManager.localizedString(for: AppStrings.Food.recentFoods))
                    .id("recent-foods-\(localizationManager.currentLanguage)")
                    .font(.headline)

                ForEach(viewModel.recentFoods) { food in
                    RecentFoodRow(food: food, isSaved: viewModel.isSaved(food)) {
                        Task {
                            let success = await viewModel.saveFoodEntry(food)
                            if success {
                                dismiss()
                            }
                        }
                    } onSave: {
                        if viewModel.isSaved(food) {
                            viewModel.removeFromFavorites(food)
                        } else {
                            viewModel.saveToFavorites(food)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Saved Foods Section

    private var savedFoodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.savedFoods.isEmpty {
                emptyStateView(
                    icon: "bookmark",
                    title: localizationManager.localizedString(for: AppStrings.Food.noSavedFoods),
                    message: "Tap the bookmark icon on any food to save it here"
                )
            } else {
                Text(localizationManager.localizedString(for: AppStrings.Food.savedFoods))
                    .id("saved-foods-\(localizationManager.currentLanguage)")
                    .font(.headline)

                ForEach(viewModel.savedFoods) { food in
                    RecentFoodRow(food: food, isSaved: true) {
                        Task {
                            let success = await viewModel.saveFoodEntry(food)
                            if success {
                                dismiss()
                            }
                        }
                    } onSave: {
                        viewModel.removeFromFavorites(food)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showingManualEntry = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text(localizationManager.localizedString(for: AppStrings.Food.manual))
                        .id("manual-\(localizationManager.currentLanguage)")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }

            Button {
                showingVoiceLog = true
            } label: {
                HStack {
                    Image(systemName: "mic.fill")
                    Text(localizationManager.localizedString(for: AppStrings.Food.voice))
                        .id("voice-\(localizationManager.currentLanguage)")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - Food Tab Enum

enum FoodTab {
    case all
    case quickAdd
    case myFoods
    case myMeals
    case savedFoods
    case recent
}

// MARK: - Tab Button

struct FoodTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)

                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Quick Add Food Button

struct QuickAddFoodButton: View {
    let food: QuickAddFood
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(food.emoji)
                    .font(.title)

                Text(food.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("\(food.calories) cal")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Food Row

struct RecentFoodRow: View {
    let food: FoodLogEntry
    let isSaved: Bool
    let onAdd: () -> Void
    let onSave: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("\(food.calories) \(localizationManager.localizedString(for: AppStrings.Progress.cal))")
                        .id("cal-food-\(localizationManager.currentLanguage)")
                    Text("•")
                    Text("\(localizationManager.localizedString(for: AppStrings.Home.proteinShort)): \(food.proteinG.formattedMacro)g")
                        .id("protein-food-\(localizationManager.currentLanguage)")
                    Text("•")
                    Text("\(localizationManager.localizedString(for: AppStrings.Home.carbsShort)): \(food.carbsG.formattedMacro)g")
                        .id("carbs-food-\(localizationManager.currentLanguage)")
                    Text("•")
                    Text("\(localizationManager.localizedString(for: AppStrings.Home.fatShort)): \(food.fatG.formattedMacro)g")
                        .id("fat-food-\(localizationManager.currentLanguage)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundColor(isSaved ? .yellow : .gray)
            }

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Manual Food Entry View

struct ManualFoodEntryView: View {
    @Bindable var viewModel: LogExperienceViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: ManualEntryField?
    @ObservedObject private var localizationManager = LocalizationManager.shared

    enum ManualEntryField {
        case name, calories, protein, carbs, fat, portion
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localizationManager.localizedString(for: AppStrings.Food.foodDetails)) {
                    TextField("Food name", text: $viewModel.manualFoodName)
                        .focused($focusedField, equals: .name)

                    HStack {
                        Text(localizationManager.localizedString(for: AppStrings.Food.portion))
                            .id("portion-\(localizationManager.currentLanguage)")
                        Spacer()
                        TextField("1", text: $viewModel.manualPortion)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .focused($focusedField, equals: .portion)

                        Picker("", selection: $viewModel.manualUnit) {
                            Text(localizationManager.localizedString(for: AppStrings.Food.serving)).tag("serving")
                                .id("serving-\(localizationManager.currentLanguage)")
                            Text(localizationManager.localizedString(for: AppStrings.Food.gram)).tag("g")
                                .id("gram-\(localizationManager.currentLanguage)")
                            Text(localizationManager.localizedString(for: AppStrings.Food.ounce)).tag("oz")
                                .id("ounce-\(localizationManager.currentLanguage)")
                            Text(localizationManager.localizedString(for: AppStrings.Food.cup)).tag("cup")
                                .id("cup-\(localizationManager.currentLanguage)")
                            Text(localizationManager.localizedString(for: AppStrings.Food.piece)).tag("piece")
                                .id("piece-\(localizationManager.currentLanguage)")
                        }
                        .frame(width: 100)
                    }
                }

                Section(localizationManager.localizedString(for: AppStrings.Food.nutrition)) {
                    HStack {
                        Label(localizationManager.localizedString(for: AppStrings.Home.calories), systemImage: "flame.fill")
                            .id("calories-label-\(localizationManager.currentLanguage)")
                            .foregroundColor(.orange)
                        Spacer()
                        TextField("0", text: $viewModel.manualCalories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .calories)
                        Text(localizationManager.localizedString(for: AppStrings.Food.kcal))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label(localizationManager.localizedString(for: AppStrings.Home.protein), systemImage: "p.circle.fill")
                            .id("protein-label-\(localizationManager.currentLanguage)")
                            .foregroundColor(.blue)
                        Spacer()
                        TextField("0", text: $viewModel.manualProtein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .protein)
                        Text(localizationManager.localizedString(for: AppStrings.Food.gram))
                            .id("protein-unit-\(localizationManager.currentLanguage)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label(localizationManager.localizedString(for: AppStrings.Home.carbs), systemImage: "c.circle.fill")
                            .id("carbs-label-\(localizationManager.currentLanguage)")
                            .foregroundColor(.green)
                        Spacer()
                        TextField("0", text: $viewModel.manualCarbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .carbs)
                        Text(localizationManager.localizedString(for: AppStrings.Food.gram))
                            .id("carbs-unit-\(localizationManager.currentLanguage)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label(localizationManager.localizedString(for: AppStrings.Home.fat), systemImage: "f.circle.fill")
                            .id("fat-label-\(localizationManager.currentLanguage)")
                            .foregroundColor(.purple)
                        Spacer()
                        TextField("0", text: $viewModel.manualFat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .fat)
                        Text(localizationManager.localizedString(for: AppStrings.Food.gram))
                            .id("fat-unit-\(localizationManager.currentLanguage)")
                            .foregroundColor(.secondary)
                    }
                }
                .id("nutrition-section-\(localizationManager.currentLanguage)")

                Section(localizationManager.localizedString(for: AppStrings.Food.category)) {
                    Picker(localizationManager.localizedString(for: AppStrings.Food.mealCategory), selection: $viewModel.selectedCategory) {
                        ForEach(MealCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                }
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Food.manualEntry))
                .id("manual-entry-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.save)) {
                        Task {
                            let success = await viewModel.saveManualEntry()
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isManualEntryValid)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                        focusedField = nil
                    }
                }
            }
        }
    }
}

// MARK: - Analyzed Foods Result View

struct AnalyzedFoodsResultView: View {
    @Bindable var viewModel: LogExperienceViewModel
    @Environment(\.dismiss) private var dismiss
    let onSaved: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary header
                VStack(spacing: 8) {
                    Text(localizationManager.localizedString(for: AppStrings.Results.analysisResults))
                        .font(.headline)
                        .id("analysis-results-\(localizationManager.currentLanguage)")

                    HStack(spacing: 24) {
                        VStack {
                            Text("\(viewModel.totalAnalyzedCalories)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(localizationManager.localizedString(for: AppStrings.Home.calories))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .id("calories-macro-\(localizationManager.currentLanguage)")
                        }

                        VStack {
                            Text("\(viewModel.totalAnalyzedMacros.proteinG.formattedMacro)g")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            Text(localizationManager.localizedString(for: AppStrings.Home.protein))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .id("protein-macro-\(localizationManager.currentLanguage)")
                        }

                        VStack {
                            Text("\(viewModel.totalAnalyzedMacros.carbsG.formattedMacro)g")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            Text(localizationManager.localizedString(for: AppStrings.Home.carbs))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .id("carbs-macro-\(localizationManager.currentLanguage)")
                        }

                        VStack {
                            Text("\(viewModel.totalAnalyzedMacros.fatG.formattedMacro)g")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                            Text(localizationManager.localizedString(for: AppStrings.Home.fat))
                                .id("fat-macro-\(localizationManager.currentLanguage)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding()
                .background(Color(.systemGray6))

                // Foods list
                List {
                    ForEach(viewModel.analyzedFoods) { food in
                        AnalyzedFoodRow(food: food) { multiplier in
                            viewModel.updateAnalyzedFoodPortion(food, multiplier: multiplier)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.removeAnalyzedFood(food)
                            } label: {
                                Label(localizationManager.localizedString(for: AppStrings.Common.delete), systemImage: "trash")
                                    .id("delete-analyzed-\(localizationManager.currentLanguage)")
                            }
                        }
                    }
                }
                .listStyle(.plain)

                // Save button
                Button {
                    Task {
                        let success = await viewModel.saveAnalyzedFoods()
                        if success {
                            dismiss()
                            onSaved()
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text(viewModel.analyzedFoods.count == 1 ? 
                                localizationManager.localizedString(for: AppStrings.Home.saveItem) :
                                localizationManager.localizedString(for: AppStrings.Home.saveItemsPlural, arguments: viewModel.analyzedFoods.count))
                                .id("save-items-\(localizationManager.currentLanguage)")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading || viewModel.analyzedFoods.isEmpty)
                .padding()
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Food.confirmFoods))
                .id("confirm-foods-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        viewModel.analyzedFoods = []
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Analyzed Food Row

struct AnalyzedFoodRow: View {
    let food: FoodLogEntry
    let onPortionChange: (Double) -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var portionMultiplier: Double

    init(food: FoodLogEntry, onPortionChange: @escaping (Double) -> Void) {
        self.food = food
        self.onPortionChange = onPortionChange
        _portionMultiplier = State(initialValue: food.portion)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(food.name)
                    .font(.headline)

                Spacer()

                Text("\(food.calories) cal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            HStack(spacing: 8) {
                Text("\(localizationManager.localizedString(for: AppStrings.Home.proteinShort)): \(food.proteinG.formattedMacro)g")
                    .foregroundColor(.blue)
                Text("\(localizationManager.localizedString(for: AppStrings.Home.carbsShort)): \(food.carbsG.formattedMacro)g")
                    .foregroundColor(.green)
                Text("\(localizationManager.localizedString(for: AppStrings.Home.fatShort)): \(food.fatG.formattedMacro)g")
                    .foregroundColor(.purple)
            }
            .font(.caption)

            // Portion stepper
            HStack {
                Text(localizationManager.localizedString(for: AppStrings.Food.portionColon))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .id("portion-label-\(localizationManager.currentLanguage)")

                Stepper(value: $portionMultiplier, in: 0.25...10, step: 0.25) {
                    Text("\(portionMultiplier.formattedPortion) \(food.unit)")
                        .font(.subheadline)
                }
                .onChange(of: portionMultiplier) { _, newValue in
                    onPortionChange(newValue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LogFoodView()
}
