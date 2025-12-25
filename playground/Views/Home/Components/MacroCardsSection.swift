//
//  HistoryView.swift
//  playground
//
//  CalAI Clone - Meal history view
//

import SwiftUI

struct MacroCardsSection: View {
    let summary: DaySummary?
    let goals: MacroData
    
    private var consumed: MacroData {
        summary?.macros ?? .zero
    }
    
    var body: some View {
        HStack(spacing: 12) {
            MacroCard(
                title: "Protein",
                value: consumed.proteinG,
                goal: goals.proteinG,
                unit: "g",
                color: .proteinColor,
                icon: "p.circle.fill"
            )
            
            MacroCard(
                title: "Carbs",
                value: consumed.carbsG,
                goal: goals.carbsG,
                unit: "g",
                color: .carbsColor,
                icon: "c.circle.fill"
            )
            
            MacroCard(
                title: "Fat",
                value: consumed.fatG,
                goal: goals.fatG,
                unit: "g",
                color: .fatColor,
                icon: "f.circle.fill"
            )
        }
    }
}

#Preview {
    MacroCardsSection(
        summary: DaySummary(
            totalCalories: 1500,
            totalProteinG: 85.5,
            totalCarbsG: 180.2,
            totalFatG: 45.8,
            mealCount: 3
        ),
        goals: MacroData(calories: 2000, proteinG: 120, carbsG: 200, fatG: 60)
    )
}
