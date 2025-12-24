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
    
    struct PaywallItem: Identifiable {
        let id = UUID()
        let page: Page
        var callback: (() -> Void)?
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
                        
                        // Check subscription status before showing paywall
                        Task {
                            do {
                                async let timewasteTask: () = Task.sleep(nanoseconds: 1_000_000_000)
                                async let updateSubscriptionStateTask = sdk.updateIsSubscribed()
                                
                                let _ = try await (timewasteTask, updateSubscriptionStateTask)
                                
                                await MainActor.run {
                                    if !sdk.isSubscribed {
                                        paywallItem = .init(page: .splash, callback: {
                                            authState = .goalsGeneration
                                        })
                                    } else {
                                        authState = .goalsGeneration
                                    }
                                }
                            } catch {
                                await MainActor.run {
                                    authState = .goalsGeneration
                                }
                            }
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
                    // TODO: Implement sign in view
                    Text("Sign In View")
                        .task {
                            guard !hasCheckedSubscription else { return }
                            hasCheckedSubscription = true
                            
                            do {
                                async let timewasteTask: () = Task.sleep(nanoseconds: 1_000_000_000)
                                async let updateSubscriptionStateTask = sdk.updateIsSubscribed()
                                
                                let _ = try await (timewasteTask, updateSubscriptionStateTask)
                                
                                if !sdk.isSubscribed {
                                    paywallItem = .init(page: .splash, callback: {
                                        authState = .authenticated
                                    })
                                } else {
                                    authState = .authenticated
                                }
                            } catch {
                                authState = .authenticated
                            }
                        }
                    
                case .authenticated:
                    MainTabView(repository: repository)
                }
            } else {
                ProgressView("Loading...")
                    .task {
                        self.repository = MealRepository(context: modelContext)
                        
                        // Check if onboarding is already completed
                        if settings.hasCompletedOnboarding {
                            authState = .authenticated
                        }
                    }
            }
        }
        .fullScreenCover(item: $paywallItem) { item in
            SDKView(
                model: sdk,
                page: item.page,
                show: Binding(
                    get: { paywallItem != nil },
                    set: { if !$0 { paywallItem = nil } }
                ),
                backgroundColor: .white,
                ignoreSafeArea: true
            )
            .ignoresSafeArea()
            .onChange(of: sdk.isSubscribed) { oldValue, newValue in
                if newValue && paywallItem != nil {
                    paywallItem?.callback?()
                    paywallItem = nil
                }
            }
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
