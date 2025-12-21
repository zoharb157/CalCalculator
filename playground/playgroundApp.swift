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

@main
struct playgroundApp: App {
    let modelContainer: ModelContainer
    @State var sdk: TheSDK
    
    init() {
        // Initialize ModelContainer (fast, synchronous)
        do {
            let schema = Schema([
                Meal.self,
                MealItem.self,
                DaySummary.self
            ])
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
        
        // Initialize SDK synchronously like the example app
        // The SDK's heavy work (StoreKit checks, network calls) happens async internally
        // StoreKit errors are logged but don't block - they're expected in development
        let baseURL = URL(string: "https://translate-now.com")!
        let config = SDKConfig(
            baseURL: baseURL,
            facebook: nil,
            logOptions: nil, // Reduced logging
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
            }
        )
        sdk = TheSDK(config: config)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(sdk) // Use direct environment like example app
        }
    }
}

// No custom environment key needed - using TheSDK directly as environment object
