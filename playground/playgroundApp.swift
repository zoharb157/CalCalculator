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

@main
struct playgroundApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    let modelContainer: ModelContainer
    @State var sdk: TheSDK
    
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
                .environment(\.isSubscribed, effectiveSubscriptionStatus) // Inject subscription status with debug override
                .onChange(of: sdk.isSubscribed) { oldValue, newValue in
                    // Subscription status changed - environment will update automatically
                    print("📱 Subscription status changed: \(newValue)")
                }
                .onChange(of: UserSettings.shared.debugOverrideSubscription) { oldValue, newValue in
                    // Debug override changed - update environment
                    print("🔧 Debug override subscription: \(newValue ? "enabled" : "disabled")")
                }
                .onChange(of: UserSettings.shared.debugIsSubscribed) { oldValue, newValue in
                    // Debug subscription value changed - update environment
                    print("🔧 Debug isSubscribed: \(newValue)")
                }
        }
    }
    
    /// Effective subscription status: uses debug override if enabled, otherwise uses SDK value
    private var effectiveSubscriptionStatus: Bool {
        let settings = UserSettings.shared
        if settings.debugOverrideSubscription {
            return settings.debugIsSubscribed
        }
        return sdk.isSubscribed
    }
}

// No custom environment key needed - using TheSDK directly as environment object
