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
    // CRITICAL: Store a stable ID for MainTabView to prevent recreation
    // This ID is created once and never changes, so SwiftUI will reuse the same MainTabView instance
    @State private var mainTabViewID = UUID()
    
    // CRITICAL: Don't observe UserSettings here - it causes ContentView to update
    // and recreate MainTabView when UserSettings changes (like after saving weight)
    // Access UserSettings.shared directly in methods instead
    
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
                        
                        // Save userName if available
                        let settings = UserSettings.shared
                        if let userName = result.answers["name_input"] as? [String: Any],
                           let nameValue = userName["value"] as? String,
                           !nameValue.isEmpty {
                            settings.userName = nameValue
                            // Also save to UserProfileRepository so it shows in Profile view
                            UserProfileRepository.shared.setFirstName(nameValue)
                            print("✅ [ContentView] Saved userName from onboarding: '\(nameValue)'")
                        }
                        
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
                    MainTabViewWrapper(repository: repository, id: mainTabViewID)
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
                            AppLogger.forClass("ContentView").warning("Database warm-up took \(String(format: "%.3f", warmTime))s")
                        } else {
                            AppLogger.forClass("ContentView").success("Database warm-up took \(String(format: "%.3f", warmTime))s")
                        }
                        
                        self.repository = MealRepository(context: modelContext)
                        let repoTime = Date().timeIntervalSince(repoStart)
                        AppLogger.forClass("ContentView").success("Repository created in \(String(format: "%.3f", repoTime))s")
                        
                        // Check if onboarding is already completed
                        if UserSettings.shared.hasCompletedOnboarding {
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
        
        // CRITICAL: Log all onboarding answers for debugging
        print("📱 [ContentView] ===== SAVING ONBOARDING DATA =====")
        print("📱 [ContentView] All answer keys: \(answers.keys)")
        print("📱 [ContentView] Full answers structure: \(answers)")
        
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
        
        // Extract gender from onboarding
        // Try multiple possible structures
        var genderValue: String?
        
        // Structure 1: answers["gender"] = { "value": "male" } or { "value": "Male" }
        if let genderStep = answers["gender"] as? [String: Any] {
            print("📱 [ContentView] Gender step found: \(genderStep)")
            if let gender = genderStep["value"] as? String {
                genderValue = gender
                print("📱 [ContentView] Extracted gender from structure 1: '\(gender)'")
            } else {
                // Try other keys in the dictionary
                print("📱 [ContentView] No 'value' key in gender step. Keys: \(genderStep.keys)")
                // Check if the dictionary itself contains the gender as a direct value
                for (key, value) in genderStep {
                    if let strValue = value as? String, (strValue.lowercased() == "male" || strValue.lowercased() == "female") {
                        genderValue = strValue
                        print("📱 [ContentView] Found gender in key '\(key)': '\(strValue)'")
                        break
                    }
                }
            }
        }
        // Structure 2: answers["gender"] = "male" or "Male" (direct string)
        else if let gender = answers["gender"] as? String {
            genderValue = gender
            print("📱 [ContentView] Extracted gender from structure 2 (direct string): '\(gender)'")
        }
        // Structure 3: Check _normalized for gender
        else if let normalized = answers["_normalized"] as? [String: Any] {
            print("📱 [ContentView] Checking _normalized structure: \(normalized)")
            if let gender = normalized["gender"] as? String {
                genderValue = gender
                print("📱 [ContentView] Extracted gender from structure 3 (_normalized): '\(gender)'")
            }
        }
        
        // Normalize and save gender
        if let gender = genderValue {
            let genderLower = gender.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            // Handle "Male"/"Female" or "male"/"female" or any case variation
            if genderLower == "male" || genderLower == "female" {
                settings.gender = genderLower
                print("✅ [ContentView] ✅✅✅ SAVED GENDER FROM ONBOARDING: '\(genderLower)' ✅✅✅")
                // Verify it was saved
                if let savedGender = UserSettings.shared.gender {
                    print("✅ [ContentView] Verified gender saved: '\(savedGender)'")
                } else {
                    print("❌ [ContentView] ERROR: Gender was set but is now nil!")
                }
            } else {
                print("⚠️ [ContentView] Invalid gender value from onboarding: '\(gender)' (lowercased: '\(genderLower)')")
                print("⚠️ [ContentView] Expected 'male' or 'female', got: '\(genderLower)'")
            }
        } else {
            print("❌ [ContentView] ❌❌❌ NO GENDER FOUND IN ONBOARDING ANSWERS ❌❌❌")
            print("❌ [ContentView] Available keys: \(answers.keys)")
            // Log the full answers structure for debugging
            if let genderData = answers["gender"] {
                print("❌ [ContentView] Gender data exists but couldn't extract. Type: \(type(of: genderData)), value: \(genderData)")
            } else {
                print("❌ [ContentView] No 'gender' key in answers at all!")
            }
        }
        
        // Extract birthdate and calculate age
        var birthdateValue: String?
        
        // Structure 1: answers["birthdate"] = { "birthdate": "2026-01-12" }
        if let birthdateStep = answers["birthdate"] as? [String: Any] {
            print("📱 [ContentView] Birthdate step found: \(birthdateStep)")
            // Try "birthdate" key first (actual structure from onboarding)
            if let birthdate = birthdateStep["birthdate"] as? String {
                birthdateValue = birthdate
                print("📱 [ContentView] Extracted birthdate from structure 1 (birthdate key): '\(birthdate)'")
            }
            // Fallback to "value" key
            else if let birthdate = birthdateStep["value"] as? String {
                birthdateValue = birthdate
                print("📱 [ContentView] Extracted birthdate from structure 1 (value key): '\(birthdate)'")
            } else {
                print("📱 [ContentView] No 'birthdate' or 'value' key in birthdate step. Keys: \(birthdateStep.keys)")
                // Try any key that looks like a date string
                for (key, value) in birthdateStep {
                    if let strValue = value as? String, strValue.contains("-") {
                        birthdateValue = strValue
                        print("📱 [ContentView] Found birthdate in key '\(key)': '\(strValue)'")
                        break
                    }
                }
            }
        }
        // Structure 2: answers["birthdate"] = "1990-01-01" (direct string)
        else if let birthdate = answers["birthdate"] as? String {
            birthdateValue = birthdate
            print("📱 [ContentView] Extracted birthdate from structure 2 (direct string): '\(birthdate)'")
        }
        // Structure 3: Check _normalized for birthdate
        else if let normalized = answers["_normalized"] as? [String: Any] {
            print("📱 [ContentView] Checking _normalized structure: \(normalized)")
            if let birthdate = normalized["birthdate"] as? String {
                birthdateValue = birthdate
                print("📱 [ContentView] Extracted birthdate from structure 3 (_normalized): '\(birthdate)'")
            }
        }
        
        // Parse and save birthdate
        if let birthdateString = birthdateValue {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            if let birthdate = formatter.date(from: birthdateString) {
                settings.birthdate = birthdate
                // Age will be calculated automatically
                let calculatedAge = settings.age ?? 0
                print("✅ [ContentView] ✅✅✅ SAVED BIRTHDATE FROM ONBOARDING: '\(birthdateString)' (age: \(calculatedAge)) ✅✅✅")
                // Verify it was saved
                if let savedBirthdate = UserSettings.shared.birthdate {
                    print("✅ [ContentView] Verified birthdate saved: \(savedBirthdate)")
                } else {
                    print("❌ [ContentView] ERROR: Birthdate was set but is now nil!")
                }
                if let savedAge = UserSettings.shared.age {
                    print("✅ [ContentView] Verified age calculated: \(savedAge)")
                } else {
                    print("❌ [ContentView] ERROR: Age was not calculated from birthdate!")
                }
            } else {
                print("⚠️ [ContentView] Failed to parse birthdate: '\(birthdateString)'")
            }
        } else {
            print("❌ [ContentView] ❌❌❌ NO BIRTHDATE FOUND IN ONBOARDING ANSWERS ❌❌❌")
            print("❌ [ContentView] Available keys: \(answers.keys)")
            // Log the full answers structure for debugging
            if let birthdateData = answers["birthdate"] {
                print("❌ [ContentView] Birthdate data exists but couldn't extract. Type: \(type(of: birthdateData)), value: \(birthdateData)")
            } else {
                print("❌ [ContentView] No 'birthdate' key in answers at all!")
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

// MARK: - MainTabViewWrapper
/// Wrapper to prevent MainTabView from being recreated when ContentView updates
/// This ensures tab selection is preserved when UserSettings changes (like after saving weight)
private struct MainTabViewWrapper: View {
    let repository: MealRepository
    let id: UUID
    
    @State private var mainTabView: MainTabView?
    
    var body: some View {
        let _ = AppLogger.forClass("MainTabViewWrapper").debug("body computed - mainTabView exists: \(mainTabView != nil)")
        
        return Group {
            if let mainTabView = mainTabView {
                mainTabView
                    .mealReminderHandler(scanViewModel: mainTabView.scanViewModel)
                    .id(id)
                    .onAppear {
                        AppLogger.forClass("MainTabViewWrapper").debug("MainTabView appeared")
                    }
            } else {
                Color.clear
                    .onAppear {
                        if self.mainTabView == nil {
                            AppLogger.forClass("MainTabViewWrapper").info("Creating MainTabView instance")
                            self.mainTabView = MainTabView(repository: repository)
                        }
                    }
            }
        }
    }
}
