//
//  MealsListSheet.swift
//  playground
//
//  CalAI Clone - Full screen view for displaying meals on a selected date
//

import SwiftUI

struct MealsListSheet: View {
    let selectedDate: Date
    let repository: MealRepository
    let onDismiss: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var meals: [Meal] = []
    @State private var isLoading = true
    @State private var error: Error?
    
    private var totalCalories: Int {
        meals.reduce(0) { $0 + $1.totalCalories }
    }
    
    private var totalProtein: Double {
        meals.reduce(0) { $0 + $1.totalMacros.proteinG }
    }
    
    private var totalCarbs: Double {
        meals.reduce(0) { $0 + $1.totalMacros.carbsG }
    }
    
    private var totalFat: Double {
        meals.reduce(0) { $0 + $1.totalMacros.fatG }
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            content
                .background(Color(.systemGroupedBackground))
                .navigationTitle(formattedSelectedDate)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarContent
                }
        }
        .task {
            await loadMeals()
        }
    }
    
    // MARK: - Private Views
    
    @ViewBuilder
    private var content: some View {
        if isLoading {
            loadingView
        } else if meals.isEmpty {
            emptyView
        } else {
            mealsListContent
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(localizationManager.localizedString(for: AppStrings.History.loadingMeals))
                .id("loading-meals-\(localizationManager.currentLanguage)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text(localizationManager.localizedString(for: AppStrings.History.noMeals))
                .id("no-meals-\(localizationManager.currentLanguage)")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(localizationManager.localizedString(for: AppStrings.History.noMealsRecorded))
                .id("no-meals-recorded-\(localizationManager.currentLanguage)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mealsListContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Day Summary Header
                daySummaryHeader
                
                // Meals List
                mealsSection
            }
            .padding(.vertical)
        }
        .navigationDestination(for: UUID.self) { mealId in
            MealDetailView(mealId: mealId, repository: repository)
        }
    }
    
    private var daySummaryHeader: some View {
        VStack(spacing: 16) {
            // Total Calories
            VStack(spacing: 4) {
                Text("\(totalCalories)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(localizationManager.localizedString(for: AppStrings.History.totalCalories))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Macros Row
            HStack(spacing: 24) {
                MacroSummaryBadge(
                    value: totalProtein,
                    label: localizationManager.localizedString(for: AppStrings.Home.protein),
                    color: .proteinColor
                )
                
                MacroSummaryBadge(
                    value: totalCarbs,
                    label: localizationManager.localizedString(for: AppStrings.Home.carbs),
                    color: .carbsColor
                )
                
                MacroSummaryBadge(
                    value: totalFat,
                    label: localizationManager.localizedString(for: AppStrings.Home.fat),
                    color: .fatColor
                )
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }
    
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Text(localizationManager.localizedString(for: AppStrings.History.mealsCapitalized))
                    .id("meals-capitalized-\(localizationManager.currentLanguage)")
                    .font(.headline)
                
                Spacer()
                
                Text(String(format: localizationManager.localizedString(for: meals.count == 1 ? AppStrings.History.meal : AppStrings.History.mealsPlural), meals.count))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .id("meal-count-\(localizationManager.currentLanguage)")
            }
            .padding(.horizontal)
            
            // Meal Cards
            VStack(spacing: 12) {
                ForEach(meals, id: \.id) { meal in
                    NavigationLink(value: meal.id) {
                        MealCard(meal: meal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var formattedSelectedDate: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return localizationManager.localizedString(for: AppStrings.Home.today)
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return localizationManager.localizedString(for: AppStrings.Home.yesterday)
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: localizationManager.currentLanguage)
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }
    
    private func loadMeals() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            meals = try repository.fetchMeals(for: selectedDate)
        } catch {
            self.error = error
        }
    }
}

// MARK: - Macro Summary Badge

struct MacroSummaryBadge: View {
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text("\(Int(value))g")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 70)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Meal Card

struct MealCard: View {
    let meal: Meal
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        HStack(spacing: 14) {
            // Meal Image
            mealImage
            
            // Meal Info
            VStack(alignment: .leading, spacing: 6) {
                // Name and Time
                HStack {
                    Text(meal.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(meal.formattedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Calories
                Text("\(meal.totalCalories) \(localizationManager.localizedString(for: AppStrings.History.caloriesLabel))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .id("calories-label-\(localizationManager.currentLanguage)")
                
                // Macro Pills
                HStack(spacing: 8) {
                    MiniMacroPill(value: meal.totalMacros.proteinG, label: localizationManager.localizedString(for: AppStrings.Home.proteinShort), color: .proteinColor)
                    MiniMacroPill(value: meal.totalMacros.carbsG, label: localizationManager.localizedString(for: AppStrings.Home.carbsShort), color: .carbsColor)
                    MiniMacroPill(value: meal.totalMacros.fatG, label: localizationManager.localizedString(for: AppStrings.Home.fatShort), color: .fatColor)
                }
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color.gray)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private var mealImage: some View {
        Group {
            if let photoURL = meal.photoURL,
               let image = ImageStorage.shared.loadImage(from: photoURL) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "fork.knife")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
            }
        }
    }
}

// MARK: - Mini Macro Pill

struct MiniMacroPill: View {
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
            
            Text("\(Int(value))")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    
    MealsListSheet(
        selectedDate: Date(),
        repository: repository,
        onDismiss: {
            print("Dismissed")
        }
    )
}
