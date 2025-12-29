//
//  ContentView.swift
//  playground
//
//  Created by Tareq Khalili on 15/12/2025.
//

import SwiftUI
import SwiftData
import SDK
import MavenCommonSwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TheSDK.self) private var sdk
    
    @State private var repository: MealRepository?
    @State private var authState: AuthState = .login
    @State private var onboardingResult: [String: Any] = [:]
    @State private var paywallItem: PaywallItem?
    @State private var hasCheckedSubscription = false
    
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
        case login
        case onboarding
        case goalsGeneration
        case signIn
        case authenticated
    }
    
    var body: some View {
        Group {
            if let repository = repository {
                switch authState {
                case .login:
                    LoginView(
                        onGetStarted: {
                            authState = .onboarding
                        },
                        onSignIn: {
                            authState = .signIn
                        }
                    )
                    
                case .onboarding:
                    OnboardingFlowView(jsonFileName: "onboarding") { dict in
                        // This is the final dictionary: [stepId: answer]
                        onboardingResult = dict
                        // Save onboarding data to UserSettings
                        saveOnboardingData(dict)
                        
                        // Mark onboarding as completed
                        settings.completeOnboarding()
                        
                        // Save user as authenticated
                        AuthenticationManager.shared.setUserId(AuthenticationManager.shared.userId ?? "")
                        
                        // Example: convert to JSON for debugging/network
                        if JSONSerialization.isValidJSONObject(dict),
                           let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
                           let json = String(data: data, encoding: .utf8) {
                            print(json)
                        }
                        
                        // Check subscription status before showing paywall (non-blocking)
                        Task {
                            // Don't block - proceed immediately and check subscription in background
                            await MainActor.run {
                                authState = .goalsGeneration
                            }
                            
                            // NOTE: Subscription status is ONLY checked when HTML paywall closes
                            // No automatic checks here
                        }
                    }
                    
                case .goalsGeneration:
                    GoalsGenerationView(onboardingData: onboardingResult) {
                        // Save user as authenticated
                        AuthenticationManager.shared.setUserId(AuthenticationManager.shared.userId ?? "")
                        
                        withAnimation {
                            authState = .authenticated
                        }
                    }
                    
                case .signIn:
                    // Sign in is handled via LoginView in the authentication flow
                    LoginView(
                        onGetStarted: {
                            authState = .onboarding
                        },
                        onSignIn: {
                            // Sign in functionality can be added here if needed
                            authState = .authenticated
                        }
                    )
                        .task {
                            guard !hasCheckedSubscription else { return }
                            hasCheckedSubscription = true
                            
                            // Don't block - proceed immediately
                            authState = .authenticated
                            
                            // NOTE: Subscription status is ONLY checked when HTML paywall closes
                            // No automatic checks here
                        }
                    
                case .authenticated:
                    let mainTabView = MainTabView(repository: repository)
                    mainTabView
                        .mealReminderHandler(scanViewModel: mainTabView.scanViewModel)
                }
            } else {
                ProgressView()
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
    
    private func saveOnboardingData(_ dict: [String: Any]) {
        let settings = UserSettings.shared
        
        // Extract height and weight from "height_weight" step
        // Structure: height_weight -> { height: { value: Double, unit: String }, weight: { value: Double, unit: String } }
        if let heightWeightData = dict["height_weight"] as? [String: Any] {
            // Height
            if let heightData = heightWeightData["height"] as? [String: Any] {
                if let heightValue = heightData["value"] as? Double,
                   let unit = heightData["unit"] as? String {
                    // Convert to cm
                    let heightInCm = unit == "cm" ? heightValue : heightValue * 30.48 // ft to cm
                    settings.height = heightInCm
                }
            }
            
            // Weight
            if let weightData = heightWeightData["weight"] as? [String: Any] {
                if let weightValue = weightData["value"] as? Double,
                   let unit = weightData["unit"] as? String {
                    // Convert to kg
                    let weightInKg = unit == "kg" ? weightValue : weightValue * 0.453592 // lbs to kg
                    settings.updateWeight(weightInKg)
                }
            }
        }
        
        // Extract desired weight from "desired_weight" step
        if let desiredWeightValue = dict["desired_weight"] as? Double {
            settings.targetWeight = desiredWeightValue
        }
        
        // Mark onboarding as complete
        settings.completeOnboarding()
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [Meal.self, MealItem.self, DaySummary.self, WeightEntry.self],
            inMemory: true
        )
}
