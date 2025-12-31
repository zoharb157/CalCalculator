//
//  EditNutritionGoalsView.swift
//  playground
//
//  Edit Nutrition Goals screen with circular progress indicators and editing
//

import SwiftUI

struct EditNutritionGoalsView: View {
    
    // MARK: - Properties
    
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    // Editing states
    @State private var isEditingCalories = false
    @State private var isEditingProtein = false
    @State private var isEditingCarbs = false
    @State private var isEditingFat = false
    
    // Temporary edit values
    @State private var tempCalories: Int = 2000
    @State private var tempProtein: Double = 150
    @State private var tempCarbs: Double = 250
    @State private var tempFat: Double = 65
    
    // MARK: - Body
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    macroGoalsSection
                    autoGenerateSection
                    macroBreakdownSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.nutritionGoals))
                .id("nutrition-goals-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentValues()
            }
        }
        .sheet(isPresented: $isEditingCalories) {
            editCaloriesSheet
        }
        .sheet(isPresented: $isEditingProtein) {
            editMacroSheet(
                title: localizationManager.localizedString(for: AppStrings.Profile.proteinGoal),
                value: $tempProtein,
                range: 50...400,
                unit: "g",
                color: .red
            ) {
                viewModel.proteinGoal = tempProtein
                isEditingProtein = false
            }
        }
        .sheet(isPresented: $isEditingCarbs) {
            editMacroSheet(
                title: localizationManager.localizedString(for: AppStrings.Profile.carbsGoal),
                value: $tempCarbs,
                range: 50...500,
                unit: "g",
                color: .orange
            ) {
                viewModel.carbsGoal = tempCarbs
                isEditingCarbs = false
            }
        }
        .sheet(isPresented: $isEditingFat) {
            editMacroSheet(
                title: localizationManager.localizedString(for: AppStrings.Profile.fatGoal),
                value: $tempFat,
                range: 20...200,
                unit: "g",
                color: .blue
            ) {
                viewModel.fatGoal = tempFat
                isEditingFat = false
            }
        }
        .onChange(of: isEditingCalories) { _, newValue in
            if newValue {
                tempCalories = viewModel.calorieGoal
            }
        }
        .onChange(of: isEditingProtein) { _, newValue in
            if newValue {
                tempProtein = viewModel.proteinGoal
            }
        }
        .onChange(of: isEditingCarbs) { _, newValue in
            if newValue {
                tempCarbs = viewModel.carbsGoal
            }
        }
        .onChange(of: isEditingFat) { _, newValue in
            if newValue {
                tempFat = viewModel.fatGoal
            }
        }
    }
    
    // MARK: - Macro Goals Section
    
        @ViewBuilder
    private var macroGoalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: localizationManager.localizedString(for: AppStrings.Profile.dailyGoals))
            
            ProfileSectionCard {
                // Calories
                NutritionGoalCard(
                    icon: "flame.fill",
                    iconColor: .orange,
                    title: localizationManager.localizedString(for: AppStrings.Home.calories),
                    value: viewModel.calorieGoal,
                    unit: "cal",
                    progress: 0.75
                ) {
                    tempCalories = viewModel.calorieGoal
                    isEditingCalories = true
                }
                
                SettingsDivider()
                
                // Protein
                NutritionGoalCard(
                    icon: "fish.fill",
                    iconColor: .red,
                    title: localizationManager.localizedString(for: AppStrings.Home.protein),
                    value: Int(viewModel.proteinGoal),
                    unit: "g",
                    progress: 0.5
                ) {
                    tempProtein = viewModel.proteinGoal
                    isEditingProtein = true
                }
                
                SettingsDivider()
                
                // Carbs
                NutritionGoalCard(
                    icon: "leaf.fill",
                    iconColor: .orange,
                    title: localizationManager.localizedString(for: AppStrings.Home.carbs),
                    value: Int(viewModel.carbsGoal),
                    unit: "g",
                    progress: 0.65
                ) {
                    tempCarbs = viewModel.carbsGoal
                    isEditingCarbs = true
                }
                
                SettingsDivider()
                
                // Fat
                NutritionGoalCard(
                    icon: "drop.fill",
                    iconColor: .blue,
                    title: localizationManager.localizedString(for: AppStrings.Home.fat),
                    value: Int(viewModel.fatGoal),
                    unit: "g",
                    progress: 0.4
                ) {
                    tempFat = viewModel.fatGoal
                    isEditingFat = true
                }
            }
        }
    }
    
    // MARK: - Auto Generate Section
    
    @ViewBuilder
    private var autoGenerateSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.autoGenerateMacros()
                }
            } label: {
                HStack {
                    if viewModel.isGeneratingMacros {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(viewModel.isGeneratingMacros ? "Generating..." : "Auto-Generate Based on Goals")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: viewModel.isGeneratingMacros ? [.gray, .gray] : [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(viewModel.isGeneratingMacros)
            
            if let error = viewModel.macroGenerationError {
                Text(String(format: localizationManager.localizedString(for: AppStrings.Common.errorColon), error))
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else {
                Text(localizationManager.localizedString(for: AppStrings.Profile.calculatesOptimalMacros))
                    .id("optimal-macros-\(localizationManager.currentLanguage)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Macro Breakdown Section
    
    @ViewBuilder
    private var macroBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: localizationManager.localizedString(for: AppStrings.Profile.macroBreakdown))
            
            HStack(spacing: 12) {
                MacroBreakdownCard(
                    name: localizationManager.localizedString(for: AppStrings.Home.protein),
                    grams: Int(viewModel.proteinGoal),
                    calories: Int(viewModel.proteinGoal * 4),
                    color: .red,
                    percentage: proteinPercentage
                )
                
                MacroBreakdownCard(
                    name: localizationManager.localizedString(for: AppStrings.Home.carbs),
                    grams: Int(viewModel.carbsGoal),
                    calories: Int(viewModel.carbsGoal * 4),
                    color: .orange,
                    percentage: carbsPercentage
                )
                
                MacroBreakdownCard(
                    name: localizationManager.localizedString(for: AppStrings.Home.fat),
                    grams: Int(viewModel.fatGoal),
                    calories: Int(viewModel.fatGoal * 9),
                    color: .blue,
                    percentage: fatPercentage
                )
            }
        }
    }
    
    // MARK: - Edit Calories Sheet
    
    @ViewBuilder
    private var editCaloriesSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(tempCalories)")
                    .font(.system(size: 56, weight: .bold))
                
                Text(localizationManager.localizedString(for: AppStrings.Profile.caloriesPerDay))
                    .id("calories-per-day-\(localizationManager.currentLanguage)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Slider(
                    value: Binding(
                        get: { Double(tempCalories) },
                        set: { tempCalories = Int($0) }
                    ),
                    in: 1000...5000,
                    step: 50
                )
                .padding(.horizontal, 32)
                .tint(.orange)
                
                // Quick select buttons
                HStack(spacing: 12) {
                    ForEach([1500, 2000, 2500, 3000], id: \.self) { cal in
                        Button {
                            tempCalories = cal
                        } label: {
                            Text("\(cal)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(tempCalories == cal ? .white : .orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(tempCalories == cal ? Color.orange : Color.orange.opacity(0.15))
                                .cornerRadius(16)
                        }
                    }
                }
                
                // Recommended calories info
                VStack(spacing: 8) {
                    Text(String(format: localizationManager.localizedString(for: AppStrings.Profile.recommendedCalories), viewModel.calculateRecommendedCalories()))
                        .id("recommended-cal-\(localizationManager.currentLanguage)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Profile.basedOnProfileAndGoals))
                        .id("based-on-goals-\(localizationManager.currentLanguage)")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.top, 16)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.calorieGoal))
                .id("calorie-goal-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) { isEditingCalories = false }
                        .id("cancel-calories-\(localizationManager.currentLanguage)")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.save)) {
                        viewModel.calorieGoal = tempCalories
                        if viewModel.autoAdjustMacros {
                            Task {
                                await viewModel.autoGenerateMacros()
                            }
                        }
                        isEditingCalories = false
                    }
                    .id("save-calories-\(localizationManager.currentLanguage)")
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Edit Macro Sheet
    
    @ViewBuilder
    private func editMacroSheet(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String,
        color: Color,
        onSave: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(Int(value.wrappedValue))")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(color)
                
                Text("\(unit) per day")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Slider(value: value, in: range, step: 5)
                    .padding(.horizontal, 32)
                    .tint(color)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        isEditingProtein = false
                        isEditingCarbs = false
                        isEditingFat = false
                    }
                    .id("cancel-macros-\(localizationManager.currentLanguage)")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.save), action: onSave)
                        .id("save-macros-\(localizationManager.currentLanguage)")
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Computed Properties
    
    private var totalMacroCalories: Double {
        (viewModel.proteinGoal * 4) + (viewModel.carbsGoal * 4) + (viewModel.fatGoal * 9)
    }
    
    private var proteinPercentage: Double {
        guard totalMacroCalories > 0 else { return 0 }
        return (viewModel.proteinGoal * 4) / totalMacroCalories * 100
    }
    
    private var carbsPercentage: Double {
        guard totalMacroCalories > 0 else { return 0 }
        return (viewModel.carbsGoal * 4) / totalMacroCalories * 100
    }
    
    private var fatPercentage: Double {
        guard totalMacroCalories > 0 else { return 0 }
        return (viewModel.fatGoal * 9) / totalMacroCalories * 100
    }
    
    private func loadCurrentValues() {
        tempCalories = viewModel.calorieGoal
        tempProtein = viewModel.proteinGoal
        tempCarbs = viewModel.carbsGoal
        tempFat = viewModel.fatGoal
    }
}

// MARK: - Macro Breakdown Card

struct MacroBreakdownCard: View {
    let name: String
    let grams: Int
    let calories: Int
    let color: Color
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 8) {
            // Percentage circle
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: percentage / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(percentage))%")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
            
            Text("\(grams)g")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(calories) cal")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    EditNutritionGoalsView(viewModel: ProfileViewModel())
}
