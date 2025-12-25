//
//  HistoryView.swift
//  playground
//
//  CalAI Clone - Meal history view
//

import SwiftUI

struct MacroCard: View {
    let title: String
    let value: Double
    let goal: Double
    let unit: String
    let color: Color
    let icon: String
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return value / goal
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
                
                // Mini progress ring
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: min(progress, 1.0))
                        .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 24, height: 24)
            }
            
            // Title
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Value
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value.formattedMacro)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Goal
            Text("/ \(goal.formattedMacro)\(unit)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: min(geometry.size.width, geometry.size.width * progress), height: 4)
                        .animation(.spring(response: 0.5), value: value)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
#Preview("Protein Card") {
    MacroCard(
        title: "Protein",
        value: 85.5,
        goal: 120.0,
        unit: "g",
        color: .proteinColor,
        icon: "p.circle.fill"
    )
    .padding()
}

#Preview("Calories Over Goal") {
    MacroCard(
        title: "Calories",
        value: 2200,
        goal: 2000,
        unit: "cal",
        color: .caloriesColor,
        icon: "flame.fill"
    )
    .padding()
}
