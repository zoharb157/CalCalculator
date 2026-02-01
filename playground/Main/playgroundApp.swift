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
import OSLog

@main
struct playgroundApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    let modelContainer: ModelContainer
    @State private var appearanceMode: AppearanceMode
    @State var sdk: TheSDK
    // CRITICAL: Initialize subscriptionStatus from UserDefaults to prevent false->true change
    // This ensures isSubscribed is correct from the start, preventing unnecessary body recomputations
    @State private var subscriptionStatus: Bool = UserDefaults.standard.bool(forKey: "subscriptionStatus")
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
            
            // Also ensure App Group directory exists for shared data
            let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
            let storeURL: URL?
            
            if let appGroupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
                let appGroupSupportURL = appGroupURL.appendingPathComponent("Library/Application Support")
                try? fileManager.createDirectory(
                    at: appGroupSupportURL, withIntermediateDirectories: true)
                storeURL = appGroupSupportURL.appendingPathComponent("default.store")
            } else {
                storeURL = nil
            }
            
            let modelConfiguration: ModelConfiguration
            if !appGroupIdentifier.isEmpty {
                modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    groupContainer: .identifier(appGroupIdentifier)
                )
            } else {
                modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false
                )
            }
            
            // Check if store exists and might be corrupted (missing tables)
            // If store exists but is missing required tables, delete it and recreate
            if let storeURL = storeURL, fileManager.fileExists(atPath: storeURL.path) {
                // Store exists - check if it's valid by trying to open it
                // If it fails or is missing tables, we'll delete it
                do {
                    let testContainer = try ModelContainer(
                        for: schema,
                        configurations: [modelConfiguration]
                    )
                    let testContext = ModelContext(testContainer)
                    // Try to fetch from all required tables to verify they exist
                    let weightDescriptor = FetchDescriptor<WeightEntry>()
                    let dietDescriptor = FetchDescriptor<DietPlan>()
                    let exerciseDescriptor = FetchDescriptor<Exercise>()
                    _ = try testContext.fetch(weightDescriptor)
                    _ = try testContext.fetch(dietDescriptor)
                    _ = try testContext.fetch(exerciseDescriptor)
                    // If we get here, the store is valid
                    modelContainer = testContainer
                } catch {
                    // Store exists but is corrupted or missing tables - delete it
                    AppLogger.forClass("playgroundApp").warning("Existing store is corrupted or missing tables", error: error)
                    AppLogger.forClass("playgroundApp").info("Deleting corrupted store and recreating...")
                    
                    // Delete all store files
                    try? fileManager.removeItem(at: storeURL)
                    try? fileManager.removeItem(at: storeURL.appendingPathExtension("wal"))
                    try? fileManager.removeItem(at: storeURL.appendingPathExtension("shm"))
                    try? fileManager.removeItem(at: storeURL.appendingPathExtension("journal"))
                    AppLogger.forClass("playgroundApp").success("Deleted corrupted store files")
                    
                    // Create fresh store
                    modelContainer = try ModelContainer(
                        for: schema,
                        configurations: [modelConfiguration]
                    )
                    AppLogger.forClass("playgroundApp").success("Successfully created new store")
                }
            } else {
                // Store doesn't exist - create it normally
                do {
                    modelContainer = try ModelContainer(
                        for: schema,
                        configurations: [modelConfiguration]
                    )
                } catch {
                    // If initialization fails, try to delete any partial files and recreate
                    AppLogger.forClass("playgroundApp").warning("Initialization failed", error: error)
                    AppLogger.forClass("playgroundApp").info("Attempting to fix by recreating store...")
                    
                    // Delete old store files if URL is available
                    if let storeURL = storeURL {
                        let fileManager = FileManager.default
                        // Delete old store files (including all possible SQLite files)
                        try? fileManager.removeItem(at: storeURL)
                        try? fileManager.removeItem(at: storeURL.appendingPathExtension("wal"))
                        try? fileManager.removeItem(at: storeURL.appendingPathExtension("shm"))
                        try? fileManager.removeItem(at: storeURL.appendingPathExtension("journal"))
                        AppLogger.forClass("playgroundApp").success("Deleted old store files at: \(storeURL.path)")
                    }
                    
                    // Try again with fresh store
                    modelContainer = try ModelContainer(
                        for: schema,
                        configurations: [modelConfiguration]
                    )
                    AppLogger.forClass("playgroundApp").success("Successfully created new store")
                }
            }
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
                    case .didRegisterForNotifications(let token):
                        print("✅ [SDK] Registered for notifications: \(token)")
                        
                    @unknown default:
                        // Handle any other APNS events
                        print("📱 [SDK] APNS event: \(event)")
                        break
                    }
                }))
        
        // Suppress known system-level warnings that are harmless but noisy
        // These warnings come from iOS frameworks (WKWebView, Network) and third-party SDKs
        suppressSystemWarnings()
    }
    
    /// Suppress known system-level warnings that are harmless
    /// These warnings come from iOS frameworks (WKWebView, Network) and third-party SDKs
    private func suppressSystemWarnings() {
        // Note: System-level warnings from WKWebView and Network frameworks
        // cannot be directly suppressed in Swift. These warnings are:
        // 1. "Update NavigationRequestObserver tried to update multiple times per frame" - from SDK's WKWebView (paywall)
        // 2. "nw_connection_copy_connected_local_endpoint_block_invoke" - informational network messages
        // Both are harmless and don't affect functionality.
        // They appear in debug logs but don't impact app performance or user experience.
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
                    // Debug: Log diet plans on app startup
                    await logDietPlansOnStartup()
                    
                    // Initialize RateUsManager to listen for successful actions
                    _ = RateUsManager.shared
                    
                    // QA/Testing: Auto-subscribe users ONLY if ENABLE_AUTO_SUBSCRIBE is YES in xcconfig
                    // - Debug/Release builds: Auto-subscribe for QA testing
                    // - Prod builds: Real StoreKit verification only (no auto-subscribe)
                    if EnvironmentConfig.shared.isAutoSubscribeEnabled {
                        let settings = UserSettings.shared
                        if !settings.debugOverrideSubscription {
                            // First time - enable override and set as subscribed for QA testing
                            settings.debugOverrideSubscription = true
                            settings.debugIsSubscribed = true
                            print("🔧 [QA] Auto-subscribe enabled: User starts as Pro (env: \(EnvironmentConfig.shared.environment))")
                        }
                    }
                    // NOTE: In Prod mode (isAutoSubscribeEnabled = false), we do NOT clear the override.
                    // The updateSubscriptionStatus() function handles this correctly:
                    // - If debugOverrideSubscription is false, it uses SubscriptionManager.isSubscribed (StoreKit)
                    // - If debugOverrideSubscription is true (from a previous QA build), the user can toggle it off
                    //   in the debug menu, or we rely on the actual value they set
                    
                    // Initialize subscription status on app launch
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
                    
                    // If user just subscribed, reset analysis, meal save, and exercise save counts
                    if !wasSubscribed && subscriptionStatus {
                        AnalysisLimitManager.shared.resetAnalysisCount()
                        MealSaveLimitManager.shared.resetMealSaveCount()
                        ExerciseSaveLimitManager.shared.resetExerciseSaveCount()
                        print("📱 Analysis, meal save, and exercise save counts reset due to subscription")
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
            // Use SDK value as the primary source (updated when paywall closes)
            // This integrates with the SDK's subscription management
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
    
    /// Logs diet plans on app startup for debugging persistence issues
    @MainActor
    private func logDietPlansOnStartup() async {
        let context = modelContainer.mainContext
        let repository = DietPlanRepository(context: context)
        
        do {
            let allPlans = try repository.fetchAllDietPlans()
            print("🍽️ [AppStartup] Found \(allPlans.count) diet plan(s) in database:")
            for (index, plan) in allPlans.enumerated() {
                print("  \(index + 1). '\(plan.name)' - isActive: \(plan.isActive), meals: \(plan.scheduledMeals.count), id: \(plan.id)")
            }
            if allPlans.isEmpty {
                print("  (No diet plans found)")
            }
        } catch {
            print("❌ [AppStartup] Failed to fetch diet plans: \(error)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let appearanceModeChanged = Notification.Name("appearanceModeChanged")
    static let nutritionGoalsChanged = Notification.Name("nutritionGoalsChanged")
    static let updateLiveActivity = Notification.Name("updateLiveActivity")
    static let exerciseSaved = Notification.Name("exerciseSaved")
    static let exerciseDeleted = Notification.Name("exerciseDeleted")
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
    static let homeTabTapped = Notification.Name("homeTabTapped")
    static let showPaywall = Notification.Name("showPaywall")
}
