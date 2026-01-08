//
//  MainTabView.swift
//  playground
//
//  Created by Bassam-Hillo on 16/12/2025.
//

import SwiftUI
import SwiftData
import SDK
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
    @ObservedObject private var localizationManager = LocalizationManager.shared

    /// Persistent storage for the selected tab
    @AppStorage("selectedMainTab") private var storedTab = MainTab.home.rawValue
    /// Local state for immediate UI updates - synced with AppStorage
    @State private var selectedTabRaw: String = MainTab.home.rawValue
    @State private var scrollHomeToTopTrigger = UUID()
    @State private var lastTabChangeTime: Date = Date()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    // Diet creation state (for History tab's create diet prompt)
    @State private var showingCreateDiet = false
    @State private var showingPaywall = false
    @State private var showDeclineConfirmation = false
    @Environment(TheSDK.self) private var sdk

    @State var homeViewModel: HomeViewModel
    @State var scanViewModel: ScanViewModel
    @State var historyViewModel: HistoryViewModel
    @State var progressViewModel: ProgressViewModel
    @State var settingsViewModel: SettingsViewModel
    @State var myDietViewModel: MyDietViewModel
    
    @Environment(\.isSubscribed) private var isSubscribed
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activeDietPlans: [DietPlan]
    
    /// User has premium subscription AND has at least one active diet plan
    private var hasActiveDiet: Bool {
        !activeDietPlans.isEmpty && isSubscribed
    }
    
    /// Convert the raw string back to a MainTab enum
    private var selectedTab: MainTab {
        get { MainTab(rawValue: selectedTabRaw) ?? .home }
        nonmutating set { selectedTabRaw = newValue.rawValue }
    }
    
    init(repository: MealRepository) {
        let initStart = Date()
        self.repository = repository
        
        // Initialize selectedTabRaw from stored value
        let stored = UserDefaults.standard.string(forKey: "selectedMainTab") ?? MainTab.home.rawValue
        _selectedTabRaw = State(initialValue: stored)
        
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
        _progressViewModel = State(
            initialValue: ProgressViewModel(
                repository: repository
            )
        )
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
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        // Create a custom binding that detects re-taps on the home tab
        let tabSelectionBinding = Binding(
            get: { selectedTabRaw },
            set: { newValue in
                let oldValue = selectedTabRaw
                let now = Date()
                let timeSinceLastChange = now.timeIntervalSince(lastTabChangeTime)
                
                // Check if home tab is being tapped again (same tab, within 0.5 seconds)
                if newValue == MainTab.home.rawValue && oldValue == MainTab.home.rawValue && timeSinceLastChange < 0.5 {
                    // Home tab was tapped while already selected - trigger scroll to top immediately
                    scrollHomeToTopTrigger = UUID()
                }
                
                selectedTabRaw = newValue
                lastTabChangeTime = now
            }
        )
        
        return ZStack(alignment: .top) {
            TabView(selection: tabSelectionBinding) {
                HomeView(
                    viewModel: homeViewModel,
                    repository: repository,
                    scanViewModel: scanViewModel,
                    scrollToTopTrigger: scrollHomeToTopTrigger,
                    onMealSaved: {
                        Task {
                            await homeViewModel.refreshTodayData()
                            // Update Live Activity after data refresh
                            homeViewModel.updateLiveActivityIfNeeded()
                            await historyViewModel.loadData()
                            await progressViewModel.loadData()
                        }
                    }
                )
                .tabItem {
                    Label(localizationManager.localizedString(for: AppStrings.Home.title), systemImage: "house.fill")
                }
                .tag(MainTab.home.rawValue)
                
                ProgressDashboardView(viewModel: progressViewModel)
                    .tabItem {
                        Label(localizationManager.localizedString(for: AppStrings.Progress.title), systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(MainTab.progress.rawValue)
                
                // My Diet tab - only shown when user has premium AND active diet
                if hasActiveDiet {
                    MyDietView(viewModel: myDietViewModel)
                        .tabItem {
                            Label(localizationManager.localizedString(for: AppStrings.DietPlan.myDiet), systemImage: "calendar")
                        }
                        .tag(MainTab.myDiet.rawValue)
                }
                
                // History tab - always visible, standalone
                HistoryView(
                    viewModel: historyViewModel,
                    repository: repository,
                    isSubscribed: isSubscribed,
                    hasActiveDiet: hasActiveDiet,
                    onCreateDiet: handleCreateDiet
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
            // Removed .id("main-tab-view") - this was causing issues with tab selection state
            
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
            // Ensure selectedTabRaw is synced with storedTab on appear
            // This prevents tab selection from resetting when view updates
            if selectedTabRaw != storedTab {
                selectedTabRaw = storedTab
            }
        }
        .onChange(of: selectedTabRaw) { oldValue, newValue in
            // Persist tab selection to AppStorage
            storedTab = newValue
            
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
        }
        .onAppear {
            // Setup tab bar tap detection when view appears
            setupTabBarTapDetection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .homeTabTapped)) { _ in
            // When home tab is tapped, trigger scroll to top
            scrollHomeToTopTrigger = UUID()
        }
        .sheet(isPresented: $showingCreateDiet) {
            DietPlansListView()
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            paywallView
        }
        .paywallDismissalOverlay(
            showPaywall: $showingPaywall,
            showDeclineConfirmation: $showDeclineConfirmation
        )
        // No need for onChange - SwiftUI automatically re-evaluates views when
        // @ObservedObject properties change. Since localizationManager.currentLanguage
        // is @Published, all views using localizationManager will update automatically.
    }
    
    // MARK: - Actions
    
    private func handleCreateDiet() {
        // Allow all users to access diet creation - paywall will appear only when saving
        showingCreateDiet = true
    }
    
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
        
        // Set up delegate to detect home tab re-taps
        if let existingDelegate = objc_getAssociatedObject(tabBarController, "mainTabBarDelegate") as? MainTabBarDelegate {
            existingDelegate.onHomeTabTapped = {
                DispatchQueue.main.async {
                    self.scrollHomeToTopTrigger = UUID()
                }
            }
        } else {
            let delegate = MainTabBarDelegate(onHomeTabTapped: {
                DispatchQueue.main.async {
                    self.scrollHomeToTopTrigger = UUID()
                }
            })
            objc_setAssociatedObject(tabBarController, "mainTabBarDelegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            tabBarController.delegate = delegate
        }
        
    }
    
    private func findTabBar(in window: UIWindow) -> UITabBar? {
        return findTabBar(in: window.rootViewController?.view)
    }
    
    private func findTabBar(in view: UIView?) -> UITabBar? {
        guard let view = view else { return nil }
        
        if let tabBar = view as? UITabBar {
            return tabBar
        }
        
        for subview in view.subviews {
            if let tabBar = findTabBar(in: subview) {
                return tabBar
            }
        }
        
        return nil
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
    
    // MARK: - Paywall View
    
    private var paywallView: some View {
        SDKView(
            model: sdk,
            page: .splash,
            show: paywallBinding(
                showPaywall: $showingPaywall,
                sdk: sdk,
                showDeclineConfirmation: $showDeclineConfirmation
            ),
            backgroundColor: .white,
            ignoreSafeArea: true
        )
    }
}


// MARK: - Main Tab Bar Delegate

class MainTabBarDelegate: NSObject, UITabBarControllerDelegate {
    var onHomeTabTapped: () -> Void
    private var lastSelectedIndex: Int = -1
    private var lastTapTime: Date = Date()
    
    init(onHomeTabTapped: @escaping () -> Void) {
        self.onHomeTabTapped = onHomeTabTapped
        super.init()
    }
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        let currentIndex = tabBarController.selectedIndex
        let newIndex = tabBarController.viewControllers?.firstIndex(of: viewController) ?? -1
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        // If home tab (index 0) is tapped and it was already selected, trigger scroll
        if newIndex == 0 && currentIndex == 0 && timeSinceLastTap < 2.0 {
            // Re-tap on home tab - trigger scroll immediately
            onHomeTabTapped()
        }
        
        lastSelectedIndex = newIndex
        lastTapTime = now
        return true
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let currentIndex = tabBarController.selectedIndex
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        // Also check on didSelect in case shouldSelect didn't catch it
        if currentIndex == 0 && lastSelectedIndex == 0 && timeSinceLastTap < 2.0 {
            onHomeTabTapped()
        }
        
        lastSelectedIndex = currentIndex
        lastTapTime = now
    }
}


#Preview {
    ContentView()
        .modelContainer(
            for: [Meal.self, MealItem.self, DaySummary.self, WeightEntry.self],
            inMemory: true
        )
}
