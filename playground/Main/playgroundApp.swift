//
//  playgroundApp.swift
//  playground
//
//  Created by Tareq Khalili on 15/12/2025.
//

import Combine
import SDK
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

@main
struct playgroundApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    let modelContainer: ModelContainer
    @State private var appearanceMode: AppearanceMode
    @State var sdk: TheSDK
    @State private var subscriptionStatus: Bool = false
    @State private var previousSubscriptionStatus: Bool = false
    @State private var currentLocale: Locale = LocalizationManager.shared.currentLocale
    @State private var currentLayoutDirection: LayoutDirection = LocalizationManager.shared.layoutDirection

    init() {
        do {
            let schema = Schema([
                Meal.self,
                MealItem.self,
                DaySummary.self,
                WeightEntry.self,
                Exercise.self,
                DietPlan.self,
                ScheduledMeal.self,
                MealTemplate.self,
                MealReminder.self,
            ])

            // Ensure Application Support directory exists before SwiftData tries to create the store
            let fileManager = FileManager.default
            if let appSupportURL = fileManager.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first {
                try? fileManager.createDirectory(
                    at: appSupportURL, withIntermediateDirectories: true)
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
        sdk = .init(
            config: .init(
                baseURL: Config.baseURL,
                logOptions: .all,
                apnsHandler: { event in
                    switch event {
                    case .didReceive(let notification, let details):
                        // Handle remote notification received
                        print("📬 [SDK] Received remote notification: \(notification)")
                        
                        // Handle deep links when app is opened from notification
                        if details == .appOpened {
                            if let urlString = notification["webviewUrl"] as? String,
                                let url = URL(string: urlString)
                            {
                                print("📱 [SDK] Deep link received: \(url)")
                                // TODO: Navigate to deep link URL
                            }
                        }
                        
                        // Handle other notification payloads
                        // Example: Update app state, refresh data, etc.
                        
                    case .didFailToRegisterForNotifications(let error):
                        // Registration failure (handled in AppDelegate)
                        print("❌ [SDK] Failed to register for notifications: \(error)")
                        
                    @unknown default:
                        // Handle any other APNS events
                        print("📱 [SDK] APNS event: \(event)")
                        break
                    }
                }))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(sdk)  // Inject SDK using @Observable
                .preferredColorScheme(appearanceMode.colorScheme)
                .environment(\.localization, LocalizationManager.shared)
                .environment(\.layoutDirection, currentLayoutDirection)
                .environment(\.locale, currentLocale)
                // Removed .id() to prevent view hierarchy recreation - views update via @ObservedObject
                .onReceive(NotificationCenter.default.publisher(for: .appearanceModeChanged)) {
                    notification in
                    if let mode = notification.object as? AppearanceMode {
                        appearanceMode = mode
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) {
                    notification in
                    // Force view refresh when language changes
                    if let languageCode = notification.object as? String {
                        print("🌐 Language changed to: \(languageCode)")
                        
                        // CRITICAL: Update environment values FIRST
                        // This ensures LocalizedStringKey uses the new locale
                        currentLocale = Locale(identifier: languageCode)
                        currentLayoutDirection = LocalizationManager.shared.layoutDirection
                        
                        // Update localization environment to trigger @ObservedObject updates
                        LocalizationManager.shared.objectWillChange.send()
                        
                        // Update environment values immediately
                        Task { @MainActor in
                            // Update environment values to ensure they're current
                            currentLocale = LocalizationManager.shared.currentLocale
                            currentLayoutDirection = LocalizationManager.shared.layoutDirection
                            
                            // Ensure environment values are updated and notify all observers
                            LocalizationManager.shared.objectWillChange.send()
                            
                            // NOTE: Do NOT post another notification here - it causes infinite loop!
                            // The notification was already posted by LocalizationManager
                        }
                    }
                }
                .environment(\.isSubscribed, subscriptionStatus)  // Inject reactive subscription status
                .task {
                    // QA Version: In Release builds, automatically enable subscription override
                    #if !DEBUG
                    let settings = UserSettings.shared
                    if !settings.debugOverrideSubscription {
                        // First time in Release - enable override and set as subscribed
                        settings.debugOverrideSubscription = true
                        settings.debugIsSubscribed = true
                        print("🔧 [QA] Release build: Auto-enabled subscription override (user starts as Pro)")
                    }
                    #endif
                    
                    // Initialize subscription status on app launch (respects debug override)
                    // This ensures debug flag works immediately
                    updateSubscriptionStatus()
                }
                // NOTE: Subscription status is ONLY updated when HTML paywall closes
                // No automatic checks on app launch or onChange listeners
                .onChange(of: UserSettings.shared.debugOverrideSubscription) { oldValue, newValue in
                    // Debug override changed - update reactive state (DEVELOPER ONLY)
                    updateSubscriptionStatus()
                    print("🔧 Debug override subscription: \(newValue ? "enabled" : "disabled")")
                }
                .onChange(of: UserSettings.shared.debugIsSubscribed) { oldValue, newValue in
                    // Debug subscription value changed - update reactive state (DEVELOPER ONLY)
                    updateSubscriptionStatus()
                    previousSubscriptionStatus = newValue
                    print("🔧 Debug isSubscribed: \(newValue)")
                }
                .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusUpdated)) { _ in
                    // Subscription status updated from paywall dismiss - update reactive state
                    updateSubscriptionStatus()
                    let wasSubscribed = previousSubscriptionStatus
                    previousSubscriptionStatus = subscriptionStatus
                    
                    // If user just subscribed, reset analysis count
                    if !wasSubscribed && subscriptionStatus {
                        AnalysisLimitManager.shared.resetAnalysisCount()
                        print("📱 Analysis count reset due to subscription")
                    }
                    
                    print("📱 Subscription status updated from paywall: \(subscriptionStatus)")
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.didBecomeActiveNotification)
                ) { _ in
                    // Refresh widget when app becomes active
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.didEnterBackgroundNotification)
                ) { _ in
                    // Refresh widget when app enters background
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .onReceive(NotificationCenter.default.publisher(for: .nutritionGoalsChanged)) { _ in
                    // Sync widget data and refresh when nutrition goals change
                    let context = ModelContext(modelContainer)
                    let repository = MealRepository(context: context)
                    repository.syncWidgetData()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.didBecomeActiveNotification)
                ) { _ in
                    // NOTE: Subscription status is ONLY updated when HTML paywall closes
                    // No automatic checks when app becomes active
                    
                    // Check if widget updated weight and notify ProgressView
                    let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
                    if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
                       sharedDefaults.bool(forKey: "widget.weightUpdatedFromWidget") {
                        // Post notification so ProgressView can handle it
                        NotificationCenter.default.post(name: .widgetWeightUpdated, object: nil)
                    }
                }
        }
    }

    /// Update reactive subscription status based on debug override or SDK value
    /// Also syncs the subscription status to the widget via shared UserDefaults
    /// Stores the value in UserDefaults so it persists across app launches
    private func updateSubscriptionStatus() {
        let settings = UserSettings.shared
        let newStatus: Bool
        
        if settings.debugOverrideSubscription {
            // Debug override takes priority - use debug flag value
            newStatus = settings.debugIsSubscribed
        } else {
            // Use SDK value (only updated when paywall closes)
            newStatus = sdk.isSubscribed
        }
        
        // Update state
        subscriptionStatus = newStatus
        
        // Store in UserDefaults so it persists and can be read on app launch
        // This ensures the value is only changed by debug flag or SDK
        UserDefaults.standard.set(newStatus, forKey: "subscriptionStatus")

        // Sync subscription status to widget via shared UserDefaults
        syncSubscriptionStatusToWidget(newStatus)
    }

    /// Syncs subscription status to the widget using App Groups shared UserDefaults
    private func syncSubscriptionStatusToWidget(_ isSubscribed: Bool) {
        let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
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
    static let updateLiveActivity = Notification.Name("updateLiveActivity")
    static let exerciseSaved = Notification.Name("exerciseSaved")
    static let exerciseFlowShouldDismiss = Notification.Name("exerciseFlowShouldDismiss")
    static let scrollHomeToTop = Notification.Name("scrollHomeToTop")
    static let addBurnedCaloriesToggled = Notification.Name("addBurnedCaloriesToggled")
    static let languageChanged = Notification.Name("languageChanged")
    static let mealReminderAction = Notification.Name("mealReminderAction")
    static let weightReminderAction = Notification.Name("weightReminderAction")
    static let widgetWeightUpdated = Notification.Name("widgetWeightUpdated")
    static let dietPlanChanged = Notification.Name("dietPlanChanged")
    static let foodLogged = Notification.Name("foodLogged")
    static let subscriptionStatusUpdated = Notification.Name("subscriptionStatusUpdated")
}
