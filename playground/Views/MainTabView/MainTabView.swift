//
//  MainTabView.swift
//  playground
//
//  Created by Bassam-Hillo on 16/12/2025.
//

import SwiftUI
import SwiftData
// import SDK  // Commented out - using native StoreKit 2 paywall
import UIKit
import ObjectiveC

// MARK: - Tab Enum
/// Stable tab identifiers that don't change based on which tabs are visible
enum MainTab: String, CaseIterable {
    case home
    case progress
    case myDiet
    case history
    case profile
}


struct MainTabView: View {
    var repository: MealRepository
    // CRITICAL: Don't use @ObservedObject to prevent view updates when localization changes
    // Access LocalizationManager.shared directly to avoid triggering TabView recreation
    private var localizationManager: LocalizationManager { LocalizationManager.shared }

    /// Persistent storage for the selected tab
    @AppStorage("selectedMainTab") private var storedTab = MainTab.home.rawValue
    /// Local state for immediate UI updates - synced with AppStorage
    @State private var selectedTabRaw: String = MainTab.home.rawValue
    @State private var scrollHomeToTopTrigger = UUID()
    @State private var lastTabChangeTime: Date = Date()
    @State private var hasAppeared = false // Track if view has appeared to prevent tab reset on recomputation
    @State private var isUserChangingTab = false // Track if user is actively changing tabs
    // CRITICAL: Don't use @StateObject to prevent view updates when network status changes
    // Access NetworkMonitor.shared directly to avoid triggering TabView recreation
    private var networkMonitor: NetworkMonitor { NetworkMonitor.shared }
    
    // Diet creation state (for History tab's create diet prompt)
    @State private var showingCreateDiet = false
    @State private var showingPaywall = false
    @State private var showDeclineConfirmation = false
    // SDK environment removed - using native StoreKit 2 paywall
    // @Environment(TheSDK.self) private var sdk

    @State var homeViewModel: HomeViewModel
    @State var scanViewModel: ScanViewModel
    @State var historyViewModel: HistoryViewModel
    // CRITICAL: Removed progressViewModel from @State to prevent MainTabView body from recomputing
    // when ProgressViewModel updates. ProgressTabView creates its own ProgressViewModel internally,
    // which completely breaks the dependency chain with MainTabView.
    // 
    // This is the correct architectural pattern: Each tab view manages its own view model,
    // preventing unnecessary body recomputations in MainTabView.
    @State var settingsViewModel: SettingsViewModel
    @State var myDietViewModel: MyDietViewModel
    
    @Environment(\.isSubscribed) private var isSubscribed
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activeDietPlans: [DietPlan]
    // CRITICAL: Store hasActiveDiet as @State to prevent MainTabView body from recomputing
    // when @Query or @Environment changes. We update it manually in onChange modifiers.
    @State private var hasActiveDiet: Bool = false
    
    /// Update hasActiveDiet based on current state
    private func updateHasActiveDiet() {
        let newValue = !activeDietPlans.isEmpty && isSubscribed
        if hasActiveDiet != newValue {
            AppLogger.forClass("MainTabView").info("🔍 [updateHasActiveDiet] hasActiveDiet changed: (hasActiveDiet) -> (newValue)")
            hasActiveDiet = newValue
        }
    }
    
    /// Convert the raw string back to a MainTab enum
    private var selectedTab: MainTab {
        get { MainTab(rawValue: selectedTabRaw) ?? .home }
        nonmutating set { selectedTabRaw = newValue.rawValue }
    }
    
    init(repository: MealRepository) {
        let initStart = Date()
        self.repository = repository
        
        // CRITICAL: Initialize selectedTabRaw from UserDefaults (same key as @AppStorage)
        // Read directly from UserDefaults to ensure we get the most up-to-date value
        // CRITICAL: Use @AppStorage's value if available, otherwise fall back to UserDefaults
        // This ensures consistency between @AppStorage and @State
        let storedFromDefaults = UserDefaults.standard.string(forKey: "selectedMainTab")
        let stored = storedFromDefaults ?? MainTab.home.rawValue
        // Validate that stored value is a valid tab
        let validTab = MainTab(rawValue: stored) != nil ? stored : MainTab.home.rawValue
        _selectedTabRaw = State(initialValue: validTab)
        
        AppLogger.forClass("MainTabView").info("🔍 [init] Initialized selectedTabRaw from UserDefaults: '\(validTab)' (raw value: '\(storedFromDefaults ?? "nil")')")
        
        _homeViewModel = State(
            initialValue: HomeViewModel(
                repository: repository,
                imageStorage: .shared
            )
        )
        _scanViewModel = State(
            initialValue: ScanViewModel(
                repository: repository,
                analysisService: CaloriesAPIService(),
                imageStorage: .shared
            )
        )
        _historyViewModel = State(
            initialValue: HistoryViewModel(
                repository: repository
            )
        )
        // CRITICAL: Removed progressViewModel initialization - ProgressTabView creates its own
        _settingsViewModel = State(
            initialValue: SettingsViewModel(
                repository: repository,
                imageStorage: .shared
            )
        )
        _myDietViewModel = State(
            initialValue: MyDietViewModel()
        )
        
        let initTime = Date().timeIntervalSince(initStart)
        if initTime > 0.1 {
            print("⚠️ [MainTabView] Initialization took \(String(format: "%.3f", initTime))s")
        }
    }
    
    var body: some View {
        #if DEBUG
        // Debug logging only in development builds
        let _ = AppLogger.forClass("MainTabView").debug("body computed")
        #endif
        
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        // CRITICAL: Compute hasActiveDiet directly from @Query and @Environment in body
        // This ensures it's correct from the first body computation, preventing the false->true change
        // that causes TabView recreation. By computing it here, we avoid @State updates.
        let hasActiveDiet = !activeDietPlans.isEmpty && isSubscribed
        
        // CRITICAL: DO NOT reference progressViewModel in body computation at all!
        // Even capturing it in a let constant causes SwiftUI to track changes to it.
        // The solution is to use a helper view that receives progressViewModel as a parameter
        // but doesn't cause MainTabView body to recompute when progressViewModel updates.
        
        // CRITICAL: Never reset selectedTabRaw in body - it will cause tab to jump to home
        // The binding will handle validation and only update when user explicitly changes tabs
        // Create a custom binding that detects re-taps on the home tab
        
        // CRITICAL: NEVER modify selectedTabRaw in body - it breaks TabView's binding connection
        // TabView needs a stable binding reference. Modifying selectedTabRaw in body causes
        // TabView to lose track of the selection, preventing the binding setter from being called.
        // 
        // Instead, we'll restore the selection in onAppear (first time only) and onChange (as backup).
        // The binding setter is the PRIMARY way selectedTabRaw should be updated.
        
        // CRITICAL: Use $selectedTabRaw directly - simpler and more reliable
        // TabView will update selectedTabRaw directly, and onChange will handle persistence
        // This is more reliable than a custom binding which might not be called
        // CRITICAL: Log what dependencies are being accessed in body
        AppLogger.forClass("MainTabView").info("🔍 [body] Dependencies: selectedTabRaw=(selectedTabRaw), hasActiveDiet=(hasActiveDiet), activeDietPlans.count=(activeDietPlans.count), isSubscribed=(isSubscribed)")
        
        // CRITICAL: DO NOT sync computed hasActiveDiet to @State during body computation
        // This prevents cascading body recomputations. The computed value is used directly for TabView structure.
        // @State hasActiveDiet is only updated via onChange handlers when dependencies actually change,
        // which allows onChange(of: hasActiveDiet) to handle tab redirection without causing body recomputation.
        
        // CRITICAL: Use $selectedTabRaw directly - simpler and more reliable
        // TabView will update selectedTabRaw directly, and onChange will handle persistence
        // The key is to ensure TabView doesn't get recreated, which we do with .id()
        
        return ZStack(alignment: .top) {
            // CRITICAL: Use StableTabViewWrapper to isolate TabView from body recomputations
            // This prevents TabView from being recreated when MainTabView body recomputes
            // CRITICAL: Use a truly stable ID that doesn't change when dependencies change
            // The wrapper will handle hasActiveDiet and isSubscribed changes internally without recreation
            StableTabViewWrapper(
                selectedTabRaw: $selectedTabRaw,
                storedTab: $storedTab,
                repository: repository,
                homeViewModel: homeViewModel,
                scanViewModel: scanViewModel,
                historyViewModel: historyViewModel,
                settingsViewModel: settingsViewModel,
                myDietViewModel: myDietViewModel,
                scrollHomeToTopTrigger: $scrollHomeToTopTrigger,
                hasActiveDiet: hasActiveDiet,
                isSubscribed: isSubscribed,
                localizationManager: localizationManager,
                onMealSaved: {
                    Task {
                        await homeViewModel.refreshTodayData()
                        // Update Live Activity after data refresh
                        homeViewModel.updateLiveActivityIfNeeded()
                        await historyViewModel.loadData()
                        // CRITICAL: Removed progressViewModel.loadData() call - ProgressTabView manages its own
                        // ProgressViewModel and will update automatically when UserSettings changes.
                        // The ProgressViewModel.updateWeight() method already calls loadWeightHistory()
                        // after updating the weight, so no manual refresh is needed here.
                    }
                },
                handleCreateDiet: handleCreateDiet
            )
            // CRITICAL: Use a stable ID that never changes - this prevents unnecessary recreation
            // The wrapper will update its content when hasActiveDiet/isSubscribed change without being recreated
            .id("stable-tab-view-wrapper-permanent")
            
            // Offline banner
            if !networkMonitor.isConnected {
                VStack {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.white)
                        Text(localizationManager.localizedString(for: AppStrings.Main.noInternetConnection))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.red)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1000)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: networkMonitor.isConnected)
        .onAppear {
            // CRITICAL: Only sync tab selection on FIRST appear, not on every body recomputation
            // This prevents tab from resetting to home when MainTabView body recomputes after weight save
            if !hasAppeared {
                hasAppeared = true
                // CRITICAL: On first appear, initialize from storedTab if selectedTabRaw is invalid
                // But NEVER override a valid selectedTabRaw, even if storedTab is different
                if selectedTabRaw.isEmpty || MainTab(rawValue: selectedTabRaw) == nil {
                    // Only set if selectedTabRaw is invalid
                    let fallback = storedTab.isEmpty || MainTab(rawValue: storedTab) == nil ? MainTab.home.rawValue : storedTab
                    AppLogger.forClass("MainTabView").info("🔍 [onAppear] Initializing selectedTabRaw from storedTab: '\(fallback)'")
                    selectedTabRaw = fallback
                    // Ensure storedTab matches
                    if storedTab != fallback {
                        storedTab = fallback
                    }
                } else {
                    // selectedTabRaw is valid - ensure storedTab matches it (not the other way around!)
                    // This ensures AppStorage reflects the actual current selection
                    if storedTab != selectedTabRaw {
                        AppLogger.forClass("MainTabView").info("🔍 [onAppear] Syncing storedTab to selectedTabRaw: '\(storedTab)' -> '\(selectedTabRaw)'")
                        storedTab = selectedTabRaw
                    }
                }
            } else {
                // CRITICAL: On subsequent appears (after body recomputation), restore selection from UserDefaults
                // if selectedTabRaw is 'home' but UserDefaults has a different value
                // This handles the case where selectedTabRaw was reset during body recomputation
                let currentStored = UserDefaults.standard.string(forKey: "selectedMainTab") ?? MainTab.home.rawValue
                if selectedTabRaw == MainTab.home.rawValue && currentStored != MainTab.home.rawValue && MainTab(rawValue: currentStored) != nil && !isUserChangingTab {
                    AppLogger.forClass("MainTabView").warning("🔍 [onAppear] Restoring selection from UserDefaults: '\(currentStored)'")
                    selectedTabRaw = currentStored
                    storedTab = currentStored
                }
            }
            // CRITICAL: hasActiveDiet is now computed directly in body, so no need to update here
            // The computed value will be synced to @State asynchronously if needed
        }
        .task(id: selectedTabRaw) {
            // CRITICAL: Monitor selectedTabRaw and ensure it's persisted
            // This task runs whenever selectedTabRaw changes, ensuring it's saved
            let currentStored = UserDefaults.standard.string(forKey: "selectedMainTab") ?? MainTab.home.rawValue
            if selectedTabRaw != currentStored && MainTab(rawValue: selectedTabRaw) != nil {
                AppLogger.forClass("MainTabView").info("🔍 [task] Persisting selectedTabRaw: '\(selectedTabRaw)'")
                storedTab = selectedTabRaw
                UserDefaults.standard.set(selectedTabRaw, forKey: "selectedMainTab")
                UserDefaults.standard.synchronize()
            }
        }
        .task {
            // CRITICAL: Periodically check if selectedTabRaw needs to be restored from UserDefaults
            // This handles the case where TabView doesn't update the binding when tabs are tapped
            // We check every 0.5 seconds to catch any desynchronization
            while true {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                let currentStored = UserDefaults.standard.string(forKey: "selectedMainTab") ?? MainTab.home.rawValue
                if selectedTabRaw == MainTab.home.rawValue && currentStored != MainTab.home.rawValue && MainTab(rawValue: currentStored) != nil && !isUserChangingTab {
                    AppLogger.forClass("MainTabView").warning("🔍 [task] Restoring selection from UserDefaults: '\(currentStored)' (selectedTabRaw was '\(selectedTabRaw)')")
                    selectedTabRaw = currentStored
                    storedTab = currentStored
                }
            }
        }
        .onChange(of: activeDietPlans.count) { oldValue, newValue in
            AppLogger.forClass("MainTabView").info("🔍 [onChange] activeDietPlans.count changed: \(oldValue) -> \(newValue)")
            // CRITICAL: Update @State hasActiveDiet when activeDietPlans changes
            // This allows onChange(of: hasActiveDiet) to handle tab redirection
            // Use async update to prevent triggering during body recomputation
            let newHasActiveDiet = !activeDietPlans.isEmpty && isSubscribed
            if self.hasActiveDiet != newHasActiveDiet {
                Task { @MainActor in
                    // Small delay to let body recomputation complete
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                    if self.hasActiveDiet != newHasActiveDiet {
                        self.hasActiveDiet = newHasActiveDiet
                    }
                }
            }
        }
        .onChange(of: isSubscribed) { oldValue, newValue in
            AppLogger.forClass("MainTabView").info("🔍 [onChange] isSubscribed changed: \(oldValue) -> \(newValue)")
            // CRITICAL: Update @State hasActiveDiet when isSubscribed changes
            // This allows onChange(of: hasActiveDiet) to handle tab redirection
            // Use async update to prevent triggering during body recomputation
            let newHasActiveDiet = !activeDietPlans.isEmpty && isSubscribed
            if self.hasActiveDiet != newHasActiveDiet {
                Task { @MainActor in
                    // Small delay to let body recomputation complete
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                    if self.hasActiveDiet != newHasActiveDiet {
                        self.hasActiveDiet = newHasActiveDiet
                    }
                }
            }
        }
        .onChange(of: selectedTabRaw) { oldValue, newValue in
            let timestamp = Date()
            AppLogger.forClass("MainTabView").info("🔍 [onChange selectedTabRaw] Changed at \(timestamp): '\(oldValue)' -> '\(newValue)'")
            AppLogger.forClass("MainTabView").info("🔍 [onChange selectedTabRaw] Stack trace: \(Thread.callStackSymbols.prefix(5).joined(separator: "\n"))")
            
            // CRITICAL: Persist immediately when selectedTabRaw changes (backup to binding setter)
            // This ensures the selection is saved even if the binding setter wasn't called
            if storedTab != newValue {
                AppLogger.forClass("MainTabView").info("🔍 [onChange selectedTabRaw] Persisting selection: '\(newValue)'")
                storedTab = newValue
                UserDefaults.standard.set(newValue, forKey: "selectedMainTab")
                UserDefaults.standard.synchronize()
            }
            
            // When home tab is selected, trigger scroll to top
            if newValue == MainTab.home.rawValue {
                let now = Date()
                let timeSinceLastChange = now.timeIntervalSince(lastTabChangeTime)
                
                // If the same tab was selected again within 0.5 seconds, it's likely a re-tap
                if oldValue == newValue && timeSinceLastChange < 0.5 {
                    // Re-tap on home tab - trigger scroll immediately
                    scrollHomeToTopTrigger = UUID()
                } else {
                    // First time selecting home tab - small delay to ensure view is ready
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        scrollHomeToTopTrigger = UUID()
                    }
                }
                
                lastTabChangeTime = now
            }
        }
        .onChange(of: hasActiveDiet) { oldValue, newValue in
            // When diet tab is removed, redirect user if they were on it
            if oldValue && !newValue && selectedTabRaw == MainTab.myDiet.rawValue {
                // User was on diet tab which is now hidden, move to history
                selectedTabRaw = MainTab.history.rawValue
            }
            // Note: When diet tab appears, no adjustment needed since tabs use stable identifiers
            
            // CRITICAL: Update delegate's hasActiveDiet IMMEDIATELY when it changes
            // This ensures tab index mapping is correct before any tab taps occur
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
               let tabBarController = self.findTabBarController(in: window.rootViewController),
               let delegate = objc_getAssociatedObject(tabBarController, "mainTabBarDelegate") as? MainTabBarDelegate {
                delegate.hasActiveDiet = newValue
            }
        }
        .onAppear {
            // Setup tab bar tap detection when view appears - kept for future use
            setupTabBarTapDetection()
        }
        .sheet(isPresented: $showingCreateDiet) {
            DietPlansListView()
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            paywallView
        }
//        .fullScreenCover(isPresented: $showDeclineConfirmation) {
//            // Native decline confirmation - no longer uses SDK
//            PaywallDeclineConfirmationView(
//                isPresented: $showDeclineConfirmation,
//                showPaywall: $showingPaywall
//            )
//            .interactiveDismissDisabled()
//        }
        // No need for onChange - SwiftUI automatically re-evaluates views when
        // @ObservedObject properties change. Since localizationManager.currentLanguage
        // is @Published, all views using localizationManager will update automatically.
    }
    
    // MARK: - Actions
    
    private func handleCreateDiet() {
        // Allow all users to access diet creation - paywall will appear only when saving
        showingCreateDiet = true
    }
    
    // MARK: - Paywall View
    
    private var paywallView: some View {
        // Native StoreKit 2 paywall - replacing SDK paywall
        NativePaywallView { subscribed in
            showingPaywall = false
            if subscribed {
                // User subscribed - reset analysis, meal save, and exercise save counts
                AnalysisLimitManager.shared.resetAnalysisCount()
                MealSaveLimitManager.shared.resetMealSaveCount()
                ExerciseSaveLimitManager.shared.resetExerciseSaveCount()
                // Update subscription status notification
                NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
            } else {
                // User dismissed without subscribing - show decline confirmation
                showDeclineConfirmation = true
            }
        }
    }
    // MARK: - Tab Bar Tap Detection
    private func setupTabBarTapDetection() {
        // Find the tab bar controller and set up delegate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.findAndSetupTabBarController()
        }
    }
    
    private func findAndSetupTabBarController() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
            // Retry after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.findAndSetupTabBarController()
            }
            return
        }
        
        // Find UITabBarController
        guard let tabBarController = self.findTabBarController(in: window.rootViewController) else {
            // Retry after delay if not found
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.findAndSetupTabBarController()
            }
            return
        }
        
        // Set up delegate to detect home tab re-taps and track tab changes
        // CRITICAL: Always use the computed hasActiveDiet value from query/subscription state
        let currentHasActiveDiet = !activeDietPlans.isEmpty && isSubscribed
        if let existingDelegate = objc_getAssociatedObject(tabBarController, "mainTabBarDelegate") as? MainTabBarDelegate {
            existingDelegate.onHomeTabTapped = {
                DispatchQueue.main.async {
                    self.scrollHomeToTopTrigger = UUID()
                }
            }
            existingDelegate.hasActiveDiet = currentHasActiveDiet
            existingDelegate.onTabChanged = { newTabRawValue in
                DispatchQueue.main.async {
                    AppLogger.forClass("MainTabView").info("🔍 [TabBarDelegate] Updating selectedTabRaw: '\(self.selectedTabRaw)' -> '\(newTabRawValue)'")
                    self.selectedTabRaw = newTabRawValue
                    self.storedTab = newTabRawValue
                    UserDefaults.standard.set(newTabRawValue, forKey: "selectedMainTab")
                    UserDefaults.standard.synchronize()
                }
            }
        } else {
            let delegate = MainTabBarDelegate(
                onHomeTabTapped: {
                    DispatchQueue.main.async {
                        self.scrollHomeToTopTrigger = UUID()
                    }
                },
                onTabChanged: { newTabRawValue in
                    DispatchQueue.main.async {
                        AppLogger.forClass("MainTabView").info("🔍 [TabBarDelegate] Updating selectedTabRaw: '\(self.selectedTabRaw)' -> '\(newTabRawValue)'")
                        self.selectedTabRaw = newTabRawValue
                        self.storedTab = newTabRawValue
                        UserDefaults.standard.set(newTabRawValue, forKey: "selectedMainTab")
                        UserDefaults.standard.synchronize()
                    }
                },
                hasActiveDiet: currentHasActiveDiet
            )
            objc_setAssociatedObject(tabBarController, "mainTabBarDelegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            tabBarController.delegate = delegate
        }
    }
    
    private func findTabBarController(in viewController: UIViewController?) -> UITabBarController? {
        guard let viewController = viewController else { return nil }
        
        if let tabBarController = viewController as? UITabBarController {
            return tabBarController
        }
        
        for child in viewController.children {
            if let tabBarController = findTabBarController(in: child) {
                return tabBarController
            }
        }
        
        if let presented = viewController.presentedViewController {
            if let tabBarController = findTabBarController(in: presented) {
                return tabBarController
            }
        }
        
        return nil
    }
}

// MARK: - Stable Tab View Wrapper
/// Wraps TabView to prevent it from being recreated when MainTabView body recomputes
/// 
/// CRITICAL: This view isolates TabView from MainTabView body recomputations.
/// When MainTabView body recomputes (e.g., when UserSettings changes), this wrapper
/// prevents TabView from being recreated, preserving the current tab selection.
/// 
/// CRITICAL: This struct is intentionally NOT Equatable because it contains closures
/// and view models that can't be compared. SwiftUI will still optimize recreations
/// based on the stable ID we provide in MainTabView.
private struct StableTabViewWrapper: View {
    @Binding var selectedTabRaw: String
    @Binding var storedTab: String
    let repository: MealRepository
    let homeViewModel: HomeViewModel
    let scanViewModel: ScanViewModel
    let historyViewModel: HistoryViewModel
    let settingsViewModel: SettingsViewModel
    let myDietViewModel: MyDietViewModel
    let scrollHomeToTopTrigger: Binding<UUID>
    let hasActiveDiet: Bool
    let isSubscribed: Bool
    let localizationManager: LocalizationManager
    let onMealSaved: () -> Void
    let handleCreateDiet: () -> Void
    
    /// Updates the tab bar delegate's hasActiveDiet to match the current value
    /// This ensures tab index mapping is correct immediately when the TabView structure changes
    private func updateDelegateHasActiveDiet() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
            return
        }
        
        // Find UITabBarController
        func findTabBarController(in viewController: UIViewController?) -> UITabBarController? {
            guard let viewController = viewController else { return nil }
            if let tabBarController = viewController as? UITabBarController {
                return tabBarController
            }
            for child in viewController.children {
                if let tabBarController = findTabBarController(in: child) {
                    return tabBarController
                }
            }
            if let presented = viewController.presentedViewController {
                if let tabBarController = findTabBarController(in: presented) {
                    return tabBarController
                }
            }
            return nil
        }
        
        if let tabBarController = findTabBarController(in: window.rootViewController),
           let delegate = objc_getAssociatedObject(tabBarController, "mainTabBarDelegate") as? MainTabBarDelegate {
            if delegate.hasActiveDiet != hasActiveDiet {
                AppLogger.forClass("MainTabView").info("🔍 [StableTabViewWrapper] Updating delegate.hasActiveDiet: \(delegate.hasActiveDiet) -> \(hasActiveDiet)")
                delegate.hasActiveDiet = hasActiveDiet
            }
        }
    }
    
    var body: some View {
        // CRITICAL: Update delegate's hasActiveDiet immediately when body is computed
        // This ensures the delegate's tab index mapping matches the actual TabView structure
        let _ = updateDelegateHasActiveDiet()
        // CRITICAL: Use a custom binding that reads from UserDefaults to ensure TabView
        // always has the correct selection, even if selectedTabRaw was reset
        let currentStoredValue = UserDefaults.standard.string(forKey: "selectedMainTab") ?? MainTab.home.rawValue
        let tabSelectionBinding = Binding<String>(
            get: {
                // Always read from UserDefaults to get the actual current selection
                // This ensures TabView shows the correct tab even if selectedTabRaw was reset
                let stored = UserDefaults.standard.string(forKey: "selectedMainTab") ?? MainTab.home.rawValue
                if selectedTabRaw != stored && MainTab(rawValue: stored) != nil {
                    // Update selectedTabRaw to match UserDefaults asynchronously
                    DispatchQueue.main.async {
                        selectedTabRaw = stored
                        storedTab = stored
                    }
                    return stored
                }
                return selectedTabRaw
            },
            set: { newValue in
                AppLogger.forClass("MainTabView").info("🔍 [binding set] TabView setting selection: '\(selectedTabRaw)' -> '\(newValue)'")
                selectedTabRaw = newValue
                storedTab = newValue
                UserDefaults.standard.set(newValue, forKey: "selectedMainTab")
                UserDefaults.standard.synchronize()
            }
        )
        
        // CRITICAL: Use stable ID to prevent TabView recreation when wrapper is recreated
        // This ensures HomeView and other tab views are not reinitialized unnecessarily
        TabView(selection: tabSelectionBinding) {
            // CRITICAL: Log current selection when TabView is created/recreated
            let _ = AppLogger.forClass("MainTabView").info("🔍 [TabView] Creating TabView with selection: '\(selectedTabRaw)', storedTab: '\(storedTab)', UserDefaults: '\(currentStoredValue)'")
            
            HomeView(
                viewModel: homeViewModel,
                repository: repository,
                scanViewModel: scanViewModel,
                scrollToTopTrigger: scrollHomeToTopTrigger.wrappedValue,
                onMealSaved: onMealSaved,
                onSwitchToMyDiet: {
                    if hasActiveDiet {
                        selectedTabRaw = MainTab.myDiet.rawValue
                        storedTab = MainTab.myDiet.rawValue
                        UserDefaults.standard.set(MainTab.myDiet.rawValue, forKey: "selectedMainTab")
                        UserDefaults.standard.synchronize()
                    }
                }
            )
            .tabItem {
                Label(localizationManager.localizedString(for: AppStrings.Home.title), systemImage: "house.fill")
            }
            .tag(MainTab.home.rawValue)
            
            ProgressTabView(repository: repository)
                .tabItem {
                    Label(localizationManager.localizedString(for: AppStrings.Progress.title), systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(MainTab.progress.rawValue)
            
            // CRITICAL: Always include MyDiet tab to prevent TabView structure changes
            // Use conditional inclusion but initialize hasActiveDiet correctly to avoid changes
            if hasActiveDiet {
                MyDietView(viewModel: myDietViewModel)
                    .tabItem {
                        Label(localizationManager.localizedString(for: AppStrings.DietPlan.myDiet), systemImage: "calendar")
                    }
                    .tag(MainTab.myDiet.rawValue)
            }
            
            HistoryView(
                viewModel: historyViewModel,
                repository: repository,
                isSubscribed: isSubscribed
            )
            .tabItem {
                Label(localizationManager.localizedString(for: AppStrings.History.title), systemImage: "clock.arrow.circlepath")
            }
            .tag(MainTab.history.rawValue)

            ProfileView()
                .tabItem {
                    Label(localizationManager.localizedString(for: AppStrings.Profile.title), systemImage: "person.fill")
                }
                .tag(MainTab.profile.rawValue)
        }
        .id("main-tab-view-stable")
        .onChange(of: hasActiveDiet) { oldValue, newValue in
            // CRITICAL: Update delegate's hasActiveDiet when it changes
            // This is a backup to ensure the delegate is always in sync
            AppLogger.forClass("MainTabView").info("🔍 [StableTabViewWrapper onChange] hasActiveDiet changed: \(oldValue) -> \(newValue)")
            updateDelegateHasActiveDiet()
            
            // If user was on myDiet tab and it's now hidden, redirect to history
            if oldValue && !newValue && selectedTabRaw == MainTab.myDiet.rawValue {
                AppLogger.forClass("MainTabView").info("🔍 [StableTabViewWrapper] Redirecting from myDiet to history")
                selectedTabRaw = MainTab.history.rawValue
                storedTab = MainTab.history.rawValue
                UserDefaults.standard.set(MainTab.history.rawValue, forKey: "selectedMainTab")
                UserDefaults.standard.synchronize()
            }
        }
    }
}

// MARK: - Progress Tab View
/// Wraps ProgressDashboardView to isolate it from MainTabView body updates
/// 
/// CRITICAL: This view creates its own ProgressViewModel internally, which completely
/// breaks the dependency chain with MainTabView. When ProgressViewModel updates,
/// only ProgressTabView's body recomputes, not MainTabView's body.
/// 
/// HOW IT WORKS:
/// 1. ProgressTabView receives repository as a parameter
/// 2. ProgressTabView creates its own ProgressViewModel internally using @State
/// 3. When progressViewModel updates, only ProgressTabView's body recomputes
/// 4. MainTabView body doesn't recompute because it doesn't observe progressViewModel
/// 5. This prevents TabView recreation, which prevents HomeView from disappearing/reappearing
private struct ProgressTabView: View {
    let repository: MealRepository
    @State private var progressViewModel: ProgressViewModel
    
    init(repository: MealRepository) {
        self.repository = repository
        _progressViewModel = State(initialValue: ProgressViewModel(repository: repository))
    }
    
    var body: some View {
        // CRITICAL: Use stable ID to prevent view recreation
        // The ProgressDashboardView will handle its own updates internally via @Bindable
        ProgressDashboardView(viewModel: progressViewModel)
            .id("progress-tab-view-stable")
    }
}

// MARK: - Main Tab Bar Delegate

class MainTabBarDelegate: NSObject, UITabBarControllerDelegate {

    var onHomeTabTapped: () -> Void
    var onTabChanged: ((String) -> Void)? // Callback to update selectedTabRaw
    var hasActiveDiet: Bool = false // Track if myDiet tab is visible
    private var lastSelectedIndex: Int = -1
    private var lastTapTime: Date = Date()
    
    // Map tab indices to MainTab raw values based on actual tab order
    private func tabRawValue(for index: Int) -> String {
        // Map based on actual visible tabs
        if hasActiveDiet {
            switch index {
            case 0: return MainTab.home.rawValue
            case 1: return MainTab.progress.rawValue
            case 2: return MainTab.myDiet.rawValue
            case 3: return MainTab.history.rawValue
            case 4: return MainTab.profile.rawValue
            default: return MainTab.home.rawValue
            }
        } else {
            switch index {
            case 0: return MainTab.home.rawValue
            case 1: return MainTab.progress.rawValue
            case 2: return MainTab.history.rawValue
            case 3: return MainTab.profile.rawValue
            default: return MainTab.home.rawValue
            }
        }
    }
    
    init(onHomeTabTapped: @escaping () -> Void, onTabChanged: ((String) -> Void)? = nil, hasActiveDiet: Bool = false) {
        self.onHomeTabTapped = onHomeTabTapped
        self.onTabChanged = onTabChanged
        self.hasActiveDiet = hasActiveDiet
        super.init()
    }
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        let currentIndex = tabBarController.selectedIndex
        let newIndex = tabBarController.viewControllers?.firstIndex(of: viewController) ?? -1
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        // CRITICAL: Get the actual tab tag from the view controller instead of using index mapping
        // This prevents issues when hasActiveDiet flag is out of sync with the actual tab structure
        if newIndex != currentIndex && newIndex >= 0, let viewControllers = tabBarController.viewControllers {
            // Extract the tag from the hosting controller
            // SwiftUI wraps each tab in a UIHostingController with the tag we set
            var tabRawValue = self.tabRawValue(for: newIndex) // Fallback to index mapping
            
            // Try to get the actual tag from the view controller
            if newIndex < viewControllers.count {
                // The tabBarItem.tag is set by SwiftUI based on our .tag() modifier
                // However, SwiftUI uses the string hash for tags, so we need to map back
                // Instead, we'll use the actual visible tab count to determine the correct mapping
                let actualTabCount = viewControllers.count
                
                // Recalculate based on actual tab count to avoid stale hasActiveDiet flag
                if actualTabCount == 5 { // All tabs visible (including myDiet)
                    switch newIndex {
                    case 0: tabRawValue = MainTab.home.rawValue
                    case 1: tabRawValue = MainTab.progress.rawValue
                    case 2: tabRawValue = MainTab.myDiet.rawValue
                    case 3: tabRawValue = MainTab.history.rawValue
                    case 4: tabRawValue = MainTab.profile.rawValue
                    default: tabRawValue = MainTab.home.rawValue
                    }
                } else if actualTabCount == 4 { // myDiet tab hidden
                    switch newIndex {
                    case 0: tabRawValue = MainTab.home.rawValue
                    case 1: tabRawValue = MainTab.progress.rawValue
                    case 2: tabRawValue = MainTab.history.rawValue
                    case 3: tabRawValue = MainTab.profile.rawValue
                    default: tabRawValue = MainTab.home.rawValue
                    }
                }
            }
            
            AppLogger.forClass("MainTabView").info("🔍 [TabBarDelegate] Tab changed: index \(currentIndex) -> \(newIndex), rawValue: '\(tabRawValue)' (hasActiveDiet: \(hasActiveDiet), actualTabCount: \(viewControllers.count))")
            onTabChanged?(tabRawValue)
        }
        
        // If home tab (index 0) is tapped and it was already selected, trigger scroll
        if newIndex == 0 && currentIndex == 0 && timeSinceLastTap < 2.0 {
            // Re-tap on home tab - trigger scroll immediately
            onHomeTabTapped()
        }
        
        lastSelectedIndex = newIndex
        lastTapTime = now
        return true
    }
}
