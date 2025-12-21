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
    @State private var authState: AuthState = .login
    @State private var onboardingResult: [String: Any] = [:]
    
    enum AuthState {
        case login
        case onboarding
        case goalsGeneration
        case signIn
        case authenticated
    }

    var body: some View {
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
                    
                    // Transition to goals generation
                    withAnimation {
                        authState = .goalsGeneration
                    }

                    // Example: convert to JSON for debugging/network
                    if JSONSerialization.isValidJSONObject(dict),
                       let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
                       let json = String(data: data, encoding: .utf8) {
                        print(json)
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
                // For now, just authenticate directly
                Text("Sign In View")
                    .onAppear {
                        // Temporary: auto-authenticate existing users
                        authState = .authenticated
                    }
                
            case .authenticated:
                MainTabView(repository: repository)
            }
        } else {
            ProgressView("Loading...")
                .task {
                    self.repository = MealRepository(context: modelContext)
                    
                    // Check if user is already authenticated
//                    if AuthenticationManager.shared.isAuthenticated {
//                        authState = .authenticated
//                    }
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
