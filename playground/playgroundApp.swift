//
//  playgroundApp.swift
//  playground
//
//  Created by Tareq Khalili on 15/12/2025.
//

import SwiftUI
import SwiftData
import MavenCommonSwiftUI
import SDK
import Firebase
import FirebaseAnalytics
import UIKit

@main
struct playgroundApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    let modelContainer: ModelContainer
    @State var sdk: TheSDK
    @State private var subscriptionStatus: Bool = false
    
    init() {
        // Initialize ModelContainer (fast, synchronous)
        do {
            let schema = Schema([
                Meal.self,
                MealItem.self,
                DaySummary.self,
                WeightEntry.self
            ])
            
            // Ensure Application Support directory exists before SwiftData tries to create the store
            let fileManager = FileManager.default
            if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            }
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
        
        sdk = .init(config: .init(baseURL: Config.baseURL,
                                  logOptions: .all,
                                  apnsHandler: { event in
                                      switch event {
                                      case let .didReceive(notification, details):
                                          guard details == .appOpened else { return }
                                          if let urlString = notification["webviewUrl"] as? String,
                                             let url = URL(string: urlString) {
                                              print("📱 Deep link received: \(url)")
                                          }
                                      default:
                                          break
                                      }
                                  }))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(sdk) // Use direct environment like example app
                .environment(\.isSubscribed, subscriptionStatus) // Inject reactive subscription status
                .task {
                    // Update subscription status on app opening
                    do {
                        try await sdk.updateIsSubscribed()
                        updateSubscriptionStatus()
                        print("📱 Subscription status updated on app launch: \(subscriptionStatus)")
                    } catch {
                        print("⚠️ Failed to update subscription status on launch: \(error)")
                    }
                }
                .onChange(of: sdk.isSubscribed) { oldValue, newValue in
                    // Subscription status changed - update reactive state
                    updateSubscriptionStatus()
                    print("📱 Subscription status changed: \(newValue)")
                }
                .onChange(of: UserSettings.shared.debugOverrideSubscription) { oldValue, newValue in
                    // Debug override changed - update reactive state
                    updateSubscriptionStatus()
                    print("🔧 Debug override subscription: \(newValue ? "enabled" : "disabled")")
                }
                .onChange(of: UserSettings.shared.debugIsSubscribed) { oldValue, newValue in
                    // Debug subscription value changed - update reactive state
                    updateSubscriptionStatus()
                    print("🔧 Debug isSubscribed: \(newValue)")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Refresh subscription status when app becomes active
                    Task {
                        do {
                            try await sdk.updateIsSubscribed()
                            updateSubscriptionStatus()
                            print("📱 Subscription status refreshed on app becoming active: \(subscriptionStatus)")
                        } catch {
                            print("⚠️ Failed to refresh subscription status: \(error)")
                        }
                    }
                }
        }
    }
    
    /// Update reactive subscription status based on debug override or SDK value
    private func updateSubscriptionStatus() {
        let settings = UserSettings.shared
        if settings.debugOverrideSubscription {
            subscriptionStatus = settings.debugIsSubscribed
        } else {
            subscriptionStatus = sdk.isSubscribed
        }
    }
}

// No custom environment key needed - using TheSDK directly as environment object
