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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerText
            ingredientsList
        }
    }
    
    // MARK: - Private Views
    
    private var headerText: some View {
        Text("Ingredients")
            .font(.headline)
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
            
            Text(item.unit)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Done") {
                if let newPortion = Double(portionText) {
                    onUpdatePortion(newPortion)
                }
                isEditing = false
            }
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
            Text("P: \(item.proteinG.formattedMacro)")
                .foregroundColor(.proteinColor)
            Text("C: \(item.carbsG.formattedMacro)")
                .foregroundColor(.carbsColor)
            Text("F: \(item.fatG.formattedMacro)")
                .foregroundColor(.fatColor)
        }
        .font(.caption2)
    }
    
    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
    }
}
