//
//  MealDetailView.swift
//  playground
//
//  History view - Detailed meal view with modern UI design
//

import SwiftUI

struct MealDetailView: View {
    let mealId: UUID
    let repository: MealRepository
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @Environment(\.dismiss) private var dismiss
    @State private var meal: Meal?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(localizationManager.localizedString(for: AppStrings.History.mealDetails))
                        .font(.headline)
                        .id("meal-details-title-\(localizationManager.currentLanguage)")
                }
            }
            .task {
                await loadMeal()
            }
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var content: some View {
        if isLoading {
            loadingView
        } else if let meal = meal {
            mealContent(for: meal)
        } else {
            errorView
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(localizationManager.localizedString(for: AppStrings.History.loadingMealDetails))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .id("loading-meal-details-\(localizationManager.currentLanguage)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var errorView: some View {
        let errorText = localizationManager.localizedString(for: AppStrings.History.unableToLoadMealDetails)
        ContentUnavailableView(
            "Meal Not Found",
            systemImage: "exclamationmark.triangle",
            description: Text(errorText)
        )
        .id("unable-load-meal-\(localizationManager.currentLanguage)")
    }
    
    // MARK: - Meal Content
    
    private func mealContent(for meal: Meal) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                heroImageSection(for: meal)
                
                VStack(spacing: 20) {
                    mealInfoCard(for: meal)
                    macroRingsSection(for: meal)
                    ingredientsSection(for: meal)
                    
                    if let notes = meal.notes, !notes.isEmpty {
                        notesSection(notes: notes)
                    }
                }
                .padding(.horizontal)
                .padding(.top, -40) // Overlap with hero image
                .padding(.bottom, 32)
            }
        }
    }
    
    // MARK: - Hero Image Section
    
    private func heroImageSection(for meal: Meal) -> some View {
        ZStack(alignment: .bottom) {
            // Image or placeholder
            if let photoURL = meal.photoURL,
               let image = ImageStorage.shared.loadImage(from: photoURL) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                // Gradient placeholder with icon
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.green.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 300)
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(meal.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
            }
            
            // Bottom gradient overlay
            LinearGradient(
                colors: [.clear, Color(.systemBackground).opacity(0.3), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
        }
    }
    
    // MARK: - Meal Info Card
    
    private func mealInfoCard(for meal: Meal) -> some View {
        VStack(spacing: 12) {
            // Meal name and confidence
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(meal.timestamp.relativeDisplay)
                        Text("•")
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(meal.timestamp.timeDisplay)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Confidence badge
                confidenceBadge(confidence: meal.confidence)
            }
            
            // Total calories highlight
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(meal.totalCalories)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.caloriesColor)
                    Text("calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Quick macro summary pills
                HStack(spacing: 8) {
                    quickMacroPill(value: meal.totalMacros.proteinG, label: "P", color: .proteinColor)
                    quickMacroPill(value: meal.totalMacros.carbsG, label: "C", color: .carbsColor)
                    quickMacroPill(value: meal.totalMacros.fatG, label: "F", color: .fatColor)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func confidenceBadge(confidence: Double) -> some View {
        let percentage = Int(confidence * 100)
        let color: Color = confidence >= 0.8 ? .green : (confidence >= 0.5 ? .orange : .red)
        
        return HStack(spacing: 4) {
            Image(systemName: confidence >= 0.8 ? "checkmark.seal.fill" : "exclamationmark.circle.fill")
                .font(.caption)
            Text("\(percentage)%")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
    
    private func quickMacroPill(value: Double, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(value.formattedMacro)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(width: 44, height: 44)
        .background(color.opacity(0.1))
        .clipShape(Circle())
    }
    
    // MARK: - Macro Rings Section
    
    private func macroRingsSection(for meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizationManager.localizedString(for: AppStrings.History.nutritionBreakdown))
                .id("nutrition-breakdown-\(localizationManager.currentLanguage)")
                .font(.headline)
            
            HStack(spacing: 20) {
                macroRing(
                    value: meal.totalMacros.proteinG,
                    label: "Protein",
                    color: .proteinColor,
                    icon: "figure.strengthtraining.traditional"
                )
                
                macroRing(
                    value: meal.totalMacros.carbsG,
                    label: "Carbs",
                    color: .carbsColor,
                    icon: "leaf.fill"
                )
                
                macroRing(
                    value: meal.totalMacros.fatG,
                    label: "Fat",
                    color: .fatColor,
                    icon: "drop.fill"
                )
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func macroRing(value: Double, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                
                // Progress ring (normalized to 100g max for visualization)
                Circle()
                    .trim(from: 0, to: min(value / 100, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                // Center content
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                    Text(value.formattedMacro)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            .frame(width: 80, height: 80)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Ingredients Section
    
    private func ingredientsSection(for meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(localizationManager.localizedString(for: AppStrings.Results.ingredients))
                    .font(.headline)
                    .id("ingredients-label-\(localizationManager.currentLanguage)")
                Spacer()
                Text("\(meal.items.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                ForEach(meal.items, id: \.id) { item in
                    ingredientCard(for: item)
                }
            }
        }
    }
    
    private func ingredientCard(for item: MealItem) -> some View {
        HStack(spacing: 12) {
            // Food icon
            Circle()
                .fill(Color(.tertiarySystemBackground))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "leaf.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
            
            // Name and portion
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(item.portion.formattedPortion) \(item.unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Calories and macros
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.calories) cal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 6) {
                    ingredientMacroLabel(value: item.proteinG, color: .proteinColor)
                    ingredientMacroLabel(value: item.carbsG, color: .carbsColor)
                    ingredientMacroLabel(value: item.fatG, color: .fatColor)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func ingredientMacroLabel(value: Double, color: Color) -> some View {
        Text(value.formattedMacro)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
    
    // MARK: - Notes Section
    
    private func notesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.secondary)
                Text(localizationManager.localizedString(for: AppStrings.Results.notes))
                    .id("notes-meal-detail-\(localizationManager.currentLanguage)")
                    .font(.headline)
            }
            
            Text(notes)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Helper Methods
    
    private func loadMeal() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            meal = try repository.fetchMeal(by: mealId)
        } catch {
            self.error = error
        }
    }
}

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    
    NavigationStack {
        MealDetailView(mealId: UUID(), repository: repository)
    }
}
