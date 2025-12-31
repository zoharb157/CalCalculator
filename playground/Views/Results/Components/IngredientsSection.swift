//
//  IngredientsSection.swift
//  playground
//
//  Results view - Ingredients list section
//

import SwiftUI

struct IngredientsSection: View {
    let items: [MealItem]
    let onUpdatePortion: (MealItem, Double) -> Void
    let onDelete: (MealItem) -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(alignment: .leading, spacing: 12) {
            headerText
            ingredientsList
        }
    }
    
    // MARK: - Private Views
    
    private var headerText: some View {
        Text(localizationManager.localizedString(for: AppStrings.Results.ingredients))
            .font(.headline)
            .id("ingredients-title-\(localizationManager.currentLanguage)")
    }
    
    private var ingredientsList: some View {
        ForEach(items, id: \.id) { item in
            IngredientRow(
                item: item,
                onUpdatePortion: { newPortion in
                    onUpdatePortion(item, newPortion)
                },
                onDelete: {
                    onDelete(item)
                }
            )
        }
    }
}

// MARK: - Ingredient Row

struct IngredientRow: View {
    let item: MealItem
    let onUpdatePortion: (Double) -> Void
    let onDelete: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var isEditing = false
    @State private var portionText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            rowContent
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            deleteButton
        }
    }
    
    // MARK: - Private Views
    
    private var rowContent: some View {
        HStack {
            itemInfo
            Spacer()
            nutritionInfo
        }
        .padding()
    }
    
    private var itemInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            itemName
            portionInfo
        }
    }
    
    private var itemName: some View {
        Text(item.name.capitalized)
            .font(.headline)
    }
    
    private var portionInfo: some View {
        HStack(spacing: 8) {
            portionView
        }
    }
    
    @ViewBuilder
    private var portionView: some View {
        if isEditing {
            editingPortionView
        } else {
            displayPortionView
        }
    }
    
    private var editingPortionView: some View {
        HStack(spacing: 4) {
            TextField("Portion", text: $portionText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .keyboardDoneButton()
            
            Text(item.unit)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                if let newPortion = Double(portionText) {
                    onUpdatePortion(newPortion)
                }
                isEditing = false
            }
            .id("done-ingredients-\(localizationManager.currentLanguage)")
            .font(.caption)
            .foregroundColor(.accentColor)
        }
    }
    
    private var displayPortionView: some View {
        Button {
            portionText = item.portion.formattedPortion
            isEditing = true
        } label: {
            HStack(spacing: 4) {
                Text("\(item.portion.formattedPortion) \(item.unit)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Image(systemName: "pencil")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    private var nutritionInfo: some View {
        VStack(alignment: .trailing, spacing: 4) {
            caloriesText
            macrosRow
        }
    }
    
    private var caloriesText: some View {
        Text("\(item.calories) cal")
            .font(.headline)
    }
    
    private var macrosRow: some View {
        HStack(spacing: 6) {
            Text("\(localizationManager.localizedString(for: AppStrings.Home.proteinShort)): \(item.proteinG.formattedMacro)")
                .foregroundColor(.proteinColor)
            Text("\(localizationManager.localizedString(for: AppStrings.Home.carbsShort)): \(item.carbsG.formattedMacro)")
                .foregroundColor(.carbsColor)
            Text("\(localizationManager.localizedString(for: AppStrings.Home.fatShort)): \(item.fatG.formattedMacro)")
                .foregroundColor(.fatColor)
        }
        .font(.caption2)
    }
    
    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label(localizationManager.localizedString(for: AppStrings.Common.delete), systemImage: "trash")
                .id("delete-ingredient-\(localizationManager.currentLanguage)")
        }
    }
}

// MARK: - Previews

#Preview("Ingredients Section") {
    IngredientsSection(
        items: [
            MealItem(
                name: "Grilled Chicken Breast",
                portion: 150,
                unit: "g",
                calories: 248,
                proteinG: 46,
                carbsG: 0,
                fatG: 5.4
            ),
            MealItem(
                name: "Brown Rice",
                portion: 100,
                unit: "g",
                calories: 112,
                proteinG: 2.6,
                carbsG: 24,
                fatG: 0.9
            )
        ],
        onUpdatePortion: { _, _ in },
        onDelete: { _ in }
    )
    .padding()
}

#Preview("Ingredient Row") {
    IngredientRow(
        item: MealItem(
            name: "Grilled Chicken Breast",
            portion: 150,
            unit: "g",
            calories: 248,
            proteinG: 46,
            carbsG: 0,
            fatG: 5.4
        ),
        onUpdatePortion: { _ in },
        onDelete: {}
    )
    .padding()
}
