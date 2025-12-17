//
//  TotalMacrosCard.swift
//  playground
//
//  Results view - Total nutrition macros card
//

import SwiftUI

struct TotalMacrosCard: View {
    let macros: MacroData
    
    var body: some View {
        VStack(spacing: 16) {
            headerView
            macroChipsRow
        }
        .padding()
        .cardStyle()
    }
    
    // MARK: - Private Views
    
    private var headerView: some View {
        HStack {
            Text("Total Nutrition")
                .font(.headline)
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
            label: "Calories",
            color: .caloriesColor
        )
    }
    
    private var proteinChip: some View {
        MacroChip(
            value: macros.proteinG.formattedMacro,
            label: "Protein",
            unit: "g",
            color: .proteinColor
        )
    }
    
    private var carbsChip: some View {
        MacroChip(
            value: macros.carbsG.formattedMacro,
            label: "Carbs",
            unit: "g",
            color: .carbsColor
        )
    }
    
    private var fatChip: some View {
        MacroChip(
            value: macros.fatG.formattedMacro,
            label: "Fat",
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
