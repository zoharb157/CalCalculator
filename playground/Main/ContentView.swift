//
//  ContentView.swift
//  playground
//
//  Created by Tareq Khalili on 15/12/2025.
//

import SDK
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TheSDK.self) private var sdk
    
    @State private var repository: MealRepository?
    @State private var authState: AuthState = .welcome
    @State private var onboardingResult: [String: Any] = [:]
    @State private var paywallItem: PaywallItem?
    
    private var settings = UserSettings.shared
    
    struct PaywallItem: Equatable, Identifiable {
        let page: Page
        var callback: (() -> Void)?
        
        init(page: Page, callback: (() -> Void)? = nil) {
            self.page = page
            self.callback = callback
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.page == rhs.page
        }
        
        var id: String {
            page.id
        }
    }
    
    enum AuthState {
        case welcome
        case onboarding
        case authenticated
    }
    
    var body: some View {
        Group {
            if let repository = repository {
                switch authState {
                case .welcome:
                    LoginView(
                        onGetStarted: {
                            authState = .onboarding
                        }
                    )
                    
                case .onboarding:
                    OnboardingWebView { result in
                        // Save onboarding data to UserSettings
                        saveOnboardingResult(result)
                        
                        // Save generated goals
                        saveGeneratedGoals(result.goals)
                        
                        // Mark onboarding as completed
                        settings.completeOnboarding()
                        
                        // Log for debugging
                        print("📱 [ContentView] Onboarding completed at: \(result.completedAt)")
                        print(
                            "📱 [ContentView] Goals: \(result.goals.calories) kcal, \(result.goals.proteinG)g protein"
                        )
                        
                        withAnimation {
                            authState = .authenticated
                        }
                    }
                    
                case .authenticated:
                    let mainTabView = MainTabView(repository: repository)
                    mainTabView
                        .mealReminderHandler(scanViewModel: mainTabView.scanViewModel)
                }
            } else {
                // Initialize repository immediately without splash screen
                Color.clear
                    .task {
                        let repoStart = Date()
                        // Pre-warm the model context and database with a simple query
                        // This ensures SwiftData is fully initialized before we start querying
                        let warmStart = Date()
                        do {
                            // Perform a lightweight query to initialize the database
                            var testDescriptor = FetchDescriptor<DaySummary>()
                            testDescriptor.fetchLimit = 1
                            _ = try? modelContext.fetch(testDescriptor)
                        }
                        let warmTime = Date().timeIntervalSince(warmStart)
                        if warmTime > 0.1 {
                            print("⚠️ [ContentView] Database warm-up took \(String(format: "%.3f", warmTime))s")
                        } else {
                            print("✅ [ContentView] Database warm-up took \(String(format: "%.3f", warmTime))s")
                        }
                        
                        self.repository = MealRepository(context: modelContext)
                        let repoTime = Date().timeIntervalSince(repoStart)
                        print("✅ [ContentView] Repository created in \(String(format: "%.3f", repoTime))s")
                        
                        // Check if onboarding is already completed
                        if settings.hasCompletedOnboarding {
                            authState = .authenticated
                        }
                    }
            }
        }
        .fullScreenCover(item: $paywallItem) { page in
            let show: Binding<Bool> = .init(
                get: {
                    true
                },
                set: { _ in
                    page.callback?()
                    paywallItem = nil
                }
            )
            
            SDKView(
                model: sdk,
                page: page.page,
                show: show,
                backgroundColor: .white,
                ignoreSafeArea: true
            )
            .ignoresSafeArea()
            .id(page.id)
        }
    }
    
    // MARK: - Save Onboarding Data
    
    private func saveOnboardingResult(_ result: OnboardingResult) {
        let settings = UserSettings.shared
        let answers = result.answers
        
        // Extract normalized height and weight from _normalized
        if let normalized = answers["_normalized"] as? [String: Any] {
            if let heightCm = normalized["height_cm"] as? Double {
                settings.height = heightCm
            }
            if let weightKg = normalized["weight_kg"] as? Double {
                settings.updateWeight(weightKg)
            }
        }
        
        // Extract desired weight from "desired_weight" step
        if let desiredWeightData = answers["desired_weight"] as? [String: Any],
           let desiredWeightValue = desiredWeightData["value"] as? Double {
            settings.targetWeight = desiredWeightValue
        }
        
        // Extract goal type
        if let goalData = answers["goal"] as? [String: Any],
           let goalValue = goalData["value"] as? String {
            // Map goal to settings if needed
            print("📱 [ContentView] User goal: \(goalValue)")
        }
        
        // Extract activity level
        if let activityData = answers["activity_level"] as? [String: Any],
           let activityValue = activityData["value"] as? String {
            print("📱 [ContentView] Activity level: \(activityValue)")
        }
    }

    private func saveGeneratedGoals(_ goals: OnboardingResult.GeneratedGoalsData) {
        let settings = UserSettings.shared
        settings.calorieGoal = goals.calories
        settings.proteinGoal = goals.proteinG
        settings.carbsGoal = goals.carbsG
        settings.fatGoal = goals.fatG
        
        print("📱 [ContentView] Saved goals - Calories: \(goals.calories), Protein: \(goals.proteinG)g, Carbs: \(goals.carbsG)g, Fat: \(goals.fatG)g")
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Meal.self,
                MealItem.self,
                DaySummary.self,
                WeightEntry.self
            ],
            inMemory: true
        )
}
