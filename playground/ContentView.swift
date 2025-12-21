//
//  ContentView.swift
//  playground
//
//  Created by Tareq Khalili on 15/12/2025.
//

import SwiftUI
import SwiftData
import MavenCommonSwiftUI
import SDK

// PaywallItem struct matching the example pattern
struct PaywallItem: Equatable, Identifiable {
    let page: SDK.Page
    let callback: (() -> Void)?
    
    init(page: SDK.Page, callback: (() -> Void)? = nil) {
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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TheSDK.self) private var sdk // SDK is always available
    @State private var repository: MealRepository?
    @State private var authState: AuthState = .login
    @State private var onboardingResult: [String: Any] = [:]
    @State private var paywallItem: PaywallItem?
    @State private var hasCheckedSubscription = false
    
    enum AuthState {
        case login
        case onboarding
        case signIn
        case paywall
        case authenticated
    }

    var body: some View {
        Group {
            // Initialize repository immediately - it's fast
            let currentRepository = repository ?? {
                let repo = MealRepository(context: modelContext)
                // Set it asynchronously to avoid modifying state during view render
                Task { @MainActor in
                    if repository == nil {
                        repository = repo
                    }
                }
                return repo
            }()
            
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
                    // ✅ This is the final dictionary: [stepId: answer]
                    onboardingResult = dict
                    
                    // Save user as authenticated
                    AuthenticationManager.shared.setUserId(AuthenticationManager.shared.userId ?? "")

                    // Example: convert to JSON for debugging/network
                    if JSONSerialization.isValidJSONObject(dict),
                       let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
                       let json = String(data: data, encoding: .utf8) {
                        print(json)
                    }
                    
                    // Check subscription status before showing paywall
                    // Defer subscription check to avoid blocking
                    Task {
                        do {
                            _ = try await sdk.updateIsSubscribed()
                            await MainActor.run {
                                if !sdk.isSubscribed {
                                    paywallItem = .init(page: .splash, callback: {
                                        authState = .authenticated
                                    })
                                } else {
                                    authState = .authenticated
                                }
                            }
                        } catch {
                            // If subscription check fails, proceed to app
                            await MainActor.run {
                                authState = .authenticated
                            }
                        }
                    }
                }
                
            case .signIn:
                // TODO: Implement sign in view
                // For now, just authenticate directly
                    Text("Sign In View")
                        .task {
                            guard !hasCheckedSubscription else { return }
                            hasCheckedSubscription = true
                            
                            do {
                                _ = try await sdk.updateIsSubscribed()
                                if !sdk.isSubscribed {
                                    paywallItem = .init(page: .splash, callback: {
                                        authState = .authenticated
                                    })
                                } else {
                                    authState = .authenticated
                                }
                            } catch {
                                // If subscription check fails, proceed to app
                                authState = .authenticated
                            }
                        }
                
            case .paywall:
                // Paywall is shown via fullScreenCover, this is just a placeholder
                Color.clear
                
            case .authenticated:
                if let repository = repository {
                    MainTabView(repository: repository)
                } else {
                    // Repository not ready yet, but show login in the meantime
                    LoginView(
                        onGetStarted: {
                            authState = .onboarding
                        },
                        onSignIn: {
                            authState = .signIn
                        }
                    )
                }
            }
        }
        .onAppear {
            // Initialize repository on appear if not already done
            if repository == nil {
                repository = MealRepository(context: modelContext)
            }
        }
        .fullScreenCover(item: $paywallItem) { page in
            let show: Binding<Bool> = .init(
                get: { true },
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
        .onChange(of: sdk.isSubscribed) { oldValue, newValue in
            if newValue && paywallItem != nil {
                paywallItem?.callback?()
                paywallItem = nil
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
