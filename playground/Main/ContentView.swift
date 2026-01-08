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
                        
                        // Mark onboarding as completed and save the completion date
                        settings.completeOnboarding()
                        // Set the onboarding completion date from the result
                        if settings.onboardingCompletedDate == nil {
                            settings.onboardingCompletedDate = Calendar.current.startOfDay(for: result.completedAt)
                        }
                        
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
        
        
        var initialWeightKg: Double?
        var initialHeightCm: Double?
        
        // Priority 1: Try to extract from height_weight directly (most reliable)
        if let heightWeight = answers["height_weight"] as? [String: Any] {
            // Extract height
            if let height = heightWeight["height"],
               let heightUnit = heightWeight["height__unit"] as? String {
                let heightValue = (height as? NSNumber)?.doubleValue ?? (height as? Double) ?? 0
                
                // Convert to cm
                if heightUnit.lowercased() == "ft" {
                    // Convert feet to cm (1 ft = 30.48 cm)
                    initialHeightCm = heightValue * 30.48
                } else {
                    initialHeightCm = heightValue
                }
                
                if let heightCm = initialHeightCm, heightCm > 0 {
                    settings.height = heightCm
                }
            }
            
            // Extract weight
            if let weight = heightWeight["weight"],
               let weightUnit = heightWeight["weight__unit"] as? String {
                let weightValue = (weight as? NSNumber)?.doubleValue ?? (weight as? Double) ?? 0
                
                // Convert to kg
                if weightUnit.lowercased() == "lb" || weightUnit.lowercased() == "lbs" {
                    initialWeightKg = weightValue / 2.20462
                } else {
                    initialWeightKg = weightValue
                }
                
                if let weightKg = initialWeightKg, weightKg > 0 {
                    settings.updateWeight(weightKg)
                }
            }
        }
        
        // Priority 2: Fallback to _normalized if height_weight didn't provide valid values
        // Only use _normalized if we didn't get valid values from height_weight
        // Add bounds checking to prevent invalid data
        if (initialWeightKg == nil || initialWeightKg == 0 || initialHeightCm == nil || initialHeightCm == 0),
           let normalized = answers["_normalized"] as? [String: Any] {
            if (initialHeightCm == nil || initialHeightCm == 0),
               let heightCm = normalized["height_cm"] as? Double,
               heightCm > 0 && heightCm < 300 {
                settings.height = heightCm
                initialHeightCm = heightCm
            }
            
            if (initialWeightKg == nil || initialWeightKg == 0),
               let weightKg = normalized["weight_kg"] as? Double,
               weightKg > 0 && weightKg < 1000 {
                initialWeightKg = weightKg
                settings.updateWeight(weightKg)
            }
        }
        
        // Extract desired weight from "desired_weight" step
        // Note: desired_weight can be in kg or lbs depending on user's unit preference
        if let desiredWeightData = answers["desired_weight"] as? [String: Any] {
            // Handle both Double and Int values
            let desiredWeightValue: Double
            if let value = desiredWeightData["value"] as? Double {
                desiredWeightValue = value
            } else if let value = desiredWeightData["value"] as? Int {
                desiredWeightValue = Double(value)
            } else if let value = desiredWeightData["value"] as? NSNumber {
                desiredWeightValue = value.doubleValue
            } else {
                desiredWeightValue = 0
            }
            
            if desiredWeightValue > 0 {
                // Check the unit - if it's lbs, convert to kg
                let unit = desiredWeightData["unit"] as? String ?? "kg"
                let targetWeightKg: Double
                if unit.lowercased() == "lb" || unit.lowercased() == "lbs" {
                    // Convert from lbs to kg
                    targetWeightKg = desiredWeightValue / 2.20462
                } else {
                    // Already in kg
                    targetWeightKg = desiredWeightValue
                }
                settings.targetWeight = targetWeightKg
            }
        }
        
        // Create initial WeightEntry from onboarding data
        // This ensures ProgressView can display the starting weight
        if let weightKg = initialWeightKg {
            createInitialWeightEntry(weight: weightKg)
        }
    }
    
    /// Creates an initial WeightEntry from onboarding weight data
    /// This ensures ProgressView can display the starting weight even if no weight history exists
    private func createInitialWeightEntry(weight: Double) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        
        // Check if an entry for today already exists
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate<WeightEntry> { entry in
                entry.date >= today && entry.date < tomorrow
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let existingEntries = try modelContext.fetch(descriptor)
            if existingEntries.isEmpty {
                // Create initial entry from onboarding weight
                let entry = WeightEntry(weight: weight, date: Date())
                modelContext.insert(entry)
                try modelContext.save()
            }
        } catch {
            // Silently fail - if we can't create the entry, the user can still add it manually
            // The ProgressViewModel will handle creating it if needed
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
