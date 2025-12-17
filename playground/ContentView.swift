//
//  ContentView.swift
//  playground
//
//  Created by Tareq Khalili on 15/12/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var repository: MealRepository?
    @State private var showOnboarding = !UserSettings.shared.hasCompletedOnboarding
    
    var body: some View {
        if let repository = repository {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
            } else {
                MainTabView(repository: repository)
            }
        } else {
            ProgressView("Loading...")
                .task {
                    self.repository = MealRepository(context: modelContext)
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [Meal.self, MealItem.self, DaySummary.self],
            inMemory: true
        )
}
