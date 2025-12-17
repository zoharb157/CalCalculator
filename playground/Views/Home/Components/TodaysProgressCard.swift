//
//  HistoryView.swift
//  playground
//
//  CalAI Clone - Meal history view
//

import SwiftUI

struct TodaysProgressCard: View {
    let summary: DaySummary?
    let calorieGoal: Int
    let remainingCalories: Int
    let progress: Double
    
    private var consumed: Int {
        summary?.totalCalories ?? 0
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Left side - Text info
            VStack(alignment: .leading, spacing: 8) {
                
                Text("\(consumed)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("of \(calorieGoal) cal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Remaining calories badge
                HStack(spacing: 4) {
                    Image(systemName: remainingCalories > 0 ? "flame.fill" : "checkmark.circle.fill")
                        .font(.caption)
                    Text("\(remainingCalories) remaining")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(remainingCalories > 0 ? .orange : .green)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    (remainingCalories > 0 ? Color.orange : Color.green).opacity(0.15)
                )
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Right side - Circular progress
            CircularProgressView(progress: progress)
                .frame(width: 100, height: 100)
        }
        .padding()
        .cardStyle()
    }
}

#Preview("Calories Remaining") {
    TodaysProgressCard(
        summary: DaySummary(
            totalCalories: 1500,
            totalProteinG: 85.5,
            totalCarbsG: 180.2,
            totalFatG: 45.8,
            mealCount: 3
        ),
        calorieGoal: 2000,
        remainingCalories: 500,
        progress: 0.75
    )
    .padding()
}

#Preview("Goal Reached") {
    TodaysProgressCard(
        summary: DaySummary(
            totalCalories: 2000,
            totalProteinG: 120,
            totalCarbsG: 200,
            totalFatG: 60,
            mealCount: 4
        ),
        calorieGoal: 2000,
        remainingCalories: 0,
        progress: 1.0
    )
    .padding()
}

#Preview("Over Goal") {
    TodaysProgressCard(
        summary: DaySummary(
            totalCalories: 2300,
            totalProteinG: 140,
            totalCarbsG: 230,
            totalFatG: 70,
            mealCount: 5
        ),
        calorieGoal: 2000,
        remainingCalories: -300,
        progress: 1.15
    )
    .padding()
}
