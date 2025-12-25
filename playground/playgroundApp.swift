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
import WidgetKit

@main
struct playgroundApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    let modelContainer: ModelContainer
    @State private var appearanceMode: AppearanceMode
    @State var sdk: TheSDK
    @State private var subscriptionStatus: Bool = false
    
    init() {
        do {
            let schema = Schema([
                Meal.self,
                MealItem.self,
                DaySummary.self,
                WeightEntry.self,
                Exercise.self
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
        
        // UserDefaults read is fast, so this is fine to do synchronously
        _appearanceMode = State(initialValue: UserProfileRepository.shared.getAppearanceMode())
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
                .preferredColorScheme(appearanceMode.colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: .appearanceModeChanged)) { notification in
                    if let mode = notification.object as? AppearanceMode {
                        appearanceMode = mode
                    }
                }
                .environment(sdk) // Use direct environment like example app
                .environment(\.isSubscribed, subscriptionStatus) // Inject reactive subscription status
                .task {
                    // Update subscription status on app opening (non-blocking, low priority)
                    Task.detached(priority: .utility) {
                        do {
                            try await sdk.updateIsSubscribed()
                            await MainActor.run {
                                updateSubscriptionStatus()
                                print("📱 Subscription status updated on app launch: \(subscriptionStatus)")
                            }
                        } catch {
                            print("⚠️ Failed to update subscription status on launch: \(error)")
                        }
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
                    // Refresh widget when app becomes active
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Refresh widget when app enters background
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .onReceive(NotificationCenter.default.publisher(for: .nutritionGoalsChanged)) { _ in
                    // Sync widget data and refresh when nutrition goals change
                    let context = ModelContext(modelContainer)
                    let repository = MealRepository(context: context)
                    repository.syncWidgetData()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Refresh subscription status when app becomes active (non-blocking)
                    Task.detached(priority: .utility) {
                        do {
                            try await sdk.updateIsSubscribed()
                            await MainActor.run {
                                updateSubscriptionStatus()
                                print("📱 Subscription status refreshed on app becoming active: \(subscriptionStatus)")
                            }
                        } catch {
                            print("⚠️ Failed to refresh subscription status: \(error)")
                        }
                    }
                }
        }
    }
    
    /// Update reactive subscription status based on debug override or SDK value
    /// Also syncs the subscription status to the widget via shared UserDefaults
    private func updateSubscriptionStatus() {
        let settings = UserSettings.shared
        if settings.debugOverrideSubscription {
            subscriptionStatus = settings.debugIsSubscribed
        } else {
            subscriptionStatus = sdk.isSubscribed
        }
        
        // Sync subscription status to widget via shared UserDefaults
        syncSubscriptionStatusToWidget(subscriptionStatus)
    }
    
    /// Syncs subscription status to the widget using App Groups shared UserDefaults
    private func syncSubscriptionStatusToWidget(_ isSubscribed: Bool) {
        let appGroupIdentifier = "group.com.calcalculator.shared"
        let isSubscribedKey = "widget.isSubscribed"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ Failed to access shared UserDefaults for widget subscription sync")
            return
        }
        
        sharedDefaults.set(isSubscribed, forKey: isSubscribedKey)
        print("📱 Widget subscription status synced: \(isSubscribed)")
        
        // Reload widget timelines to reflect the change
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let appearanceModeChanged = Notification.Name("appearanceModeChanged")
    static let nutritionGoalsChanged = Notification.Name("nutritionGoalsChanged")
}
