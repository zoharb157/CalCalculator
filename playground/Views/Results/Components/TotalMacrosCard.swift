//
//  TotalMacrosCard.swift
//  playground
//
//  Results view - Total nutrition macros card
//

import SwiftUI

struct TotalMacrosCard: View {
    let macros: MacroData
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(spacing: 16) {
            headerView
            macroChipsRow
        }
        .padding()
        .cardStyle()
    }
    
    // MARK: - Private Views
    
    private var headerView: some View {
        HStack {
            Text(localizationManager.localizedString(for: AppStrings.Results.totalNutrition))
                .font(.headline)
                .id("total-nutrition-\(localizationManager.currentLanguage)")
            Spacer()
        }
    }
    
    private var macroChipsRow: some View {
        HStack(spacing: 16) {
            caloriesChip
            proteinChip
            carbsChip
            fatChip
        }
    }
    
    private var caloriesChip: some View {
        MacroChip(
            value: "\(macros.calories)",
            label: localizationManager.localizedString(for: AppStrings.Home.calories),
            color: .caloriesColor
        )
    }
    
    private var proteinChip: some View {
        MacroChip(
            value: macros.proteinG.formattedMacro,
            label: localizationManager.localizedString(for: AppStrings.Home.protein),
            unit: "g",
            color: .proteinColor
        )
    }
    
    private var carbsChip: some View {
        MacroChip(
            value: macros.carbsG.formattedMacro,
            label: localizationManager.localizedString(for: AppStrings.Home.carbs),
            unit: "g",
            color: .carbsColor
        )
    }
    
    private var fatChip: some View {
        MacroChip(
            value: macros.fatG.formattedMacro,
            label: localizationManager.localizedString(for: AppStrings.Home.fat),
            unit: "g",
            color: .fatColor
        )
    }
}

// MARK: - Macro Chip

struct MacroChip: View {
    let value: String
    let label: String
    var unit: String = ""
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            valueWithUnit
            labelText
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - Private Views
    
    private var valueWithUnit: some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
            
            if !unit.isEmpty {
                unitText
            }
        }
    }
    
    private var unitText: some View {
        Text(unit)
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private var labelText: some View {
        Text(label)
            .font(.caption2)
            .foregroundColor(.secondary)
    }
}

// MARK: - Previews

#Preview("Total Macros Card") {
    TotalMacrosCard(
        macros: MacroData(
            calories: 650,
            proteinG: 35,
            carbsG: 45,
            fatG: 28
        )
    )
    .padding()
}

#Preview("Macro Chip") {
    HStack(spacing: 16) {
        MacroChip(
            value: "650",
            label: "Calories",
            color: .orange
        )
        MacroChip(
            value: "35",
            label: "Protein",
            unit: "g",
            color: .red
        )
    }
    .padding()
}
