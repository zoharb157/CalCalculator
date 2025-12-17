//
//  RecentMealsSection.swift
//  playground
//
//  CalAI Clone - Recent meals section with swipe-to-delete and tap to view
//

import SwiftUI

struct RecentMealsSection: View {
    let meals: [Meal]
    let repository: MealRepository
    let onDelete: (Meal) -> Void
    
    var body: some View {
        sectionContent
    }
    
    // MARK: - Private Views
    
    private var sectionContent: some View {
        Section {
            ForEach(meals, id: \.id) { meal in
                NavigationLink(value: meal.id) {
                    MealRowView(meal: meal)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    deleteButton(for: meal)
                }
            }
        } header: {
            Text("Recent Meals")
                .font(.headline)
        }
    }

    private func deleteButton(for meal: Meal) -> some View {
        Button(role: .destructive) {
            onDelete(meal)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    
    let meals = Array(repeating: Meal(
        name: "Breakfast Bowl",
        timestamp: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!,
        confidence: 0.95,
        items: [
            MealItem(name: "Oatmeal", portion: 50, unit: "g", calories: 190, proteinG: 7, carbsG: 32, fatG: 3.5),
            MealItem(name: "Banana", portion: 1, unit: "medium", calories: 105, proteinG: 1.3, carbsG: 27, fatG: 0.4)
        ]
    ), count: 2)
    
    List {
        RecentMealsSection(meals: meals, repository: repository) { meal in
            print("Deleting meal: \(meal.name)")
        }
    }
    .listStyle(.plain)
}
