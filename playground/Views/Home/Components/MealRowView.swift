//
//  HistoryView.swift
//  playground
//
//  CalAI Clone - Meal history view
//

import SwiftUI

struct MealRowView: View {
    let meal: Meal
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let photoURL = meal.photoURL,
               let image = ImageStorage.shared.loadImage(from: photoURL) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .foregroundColor(.gray)
                    )
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("\(meal.totalCalories) cal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Time
            Text(meal.formattedTime)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(meal.name), \(meal.totalCalories) calories, at \(meal.formattedTime)")
    }
}
#Preview {
    let meal = Meal(
        name: "Chicken Salad",
        timestamp: Date(),
        confidence: 0.92,
        items: [
            MealItem(name: "Grilled Chicken", portion: 150, unit: "g", calories: 250, proteinG: 45, carbsG: 0, fatG: 8),
            MealItem(name: "Mixed Greens", portion: 100, unit: "g", calories: 25, proteinG: 2, carbsG: 5, fatG: 0.5)
        ]
    )
    
    return MealRowView(meal: meal)
        .padding()
}
