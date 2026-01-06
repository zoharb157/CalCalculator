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

struct MainTabView: View {
    var repository: MealRepository
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab = 0
    @State private var scrollHomeToTopTrigger = UUID()
    @State private var scrollProgressToTopTrigger = UUID()
    @State private var scrollHistoryToTopTrigger = UUID()
    @State private var showingCreateDiet = false
    @State private var showingPaywall = false
    @State private var showDeclineConfirmation = false
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @Environment(TheSDK.self) private var sdk

    @State var homeViewModel: HomeViewModel
    @State var scanViewModel: ScanViewModel
    @State var historyViewModel: HistoryViewModel
    @State var progressViewModel: ProgressViewModel
    @State var settingsViewModel: SettingsViewModel
    
    @Environment(\.isSubscribed) private var isSubscribed
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activeDietPlans: [DietPlan]
    
    private var hasActiveDiet: Bool {
        !activeDietPlans.isEmpty && isSubscribed
    }
    
    init(repository: MealRepository) {
        let initStart = Date()
        self.repository = repository
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
        let initTime = Date().timeIntervalSince(initStart)
        if initTime > 0.1 {
            print("⚠️ [MainTabView] Initialization took \(String(format: "%.3f", initTime))s")
        }
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        // This forces the view to update when the language changes
        let _ = localizationManager.currentLanguage
        
        return ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
            HomeView(
                viewModel: homeViewModel,
                repository: repository,
                scanViewModel: scanViewModel,
                scrollToTopTrigger: scrollHomeToTopTrigger,
                onMealSaved: {
                    // Refresh all relevant data when a meal is saved
                    // This ensures Home, History, and Progress views stay in sync
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
            .tag(0)
            
            ProgressDashboardView(
                viewModel: progressViewModel,
                scrollToTopTrigger: scrollProgressToTopTrigger
            )
                .tabItem {
                    Label(localizationManager.localizedString(for: AppStrings.Progress.title), systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)
            
            Group {
                if hasActiveDiet {
                    MyDietView(
                        viewModel: MyDietViewModel()
                    )
                } else {
                    HistoryViewContent(
                        viewModel: historyViewModel,
                        repository: repository,
                        isSubscribed: isSubscribed,
                        scrollToTopTrigger: scrollHistoryToTopTrigger,
                        onCreateDiet: {
                            if isSubscribed {
                                showingCreateDiet = true
                            } else {
                                showingPaywall = true
                            }
                        }
                    )
                }
            }
                .tabItem {
                    Label(hasActiveDiet ? localizationManager.localizedString(for: AppStrings.DietPlan.myDiet) : localizationManager.localizedString(for: AppStrings.History.title), systemImage: "calendar")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label(localizationManager.localizedString(for: AppStrings.Profile.title), systemImage: "person.fill")
                }
                .tag(3)
            }
            
            // Offline banner - shown when network connection is unavailable
            // Displays at the top of the screen to inform users of connectivity issues
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
        .onChange(of: selectedTab) { oldValue, newValue in
            // When a tab is selected (switched to), trigger scroll to top
            // This ensures users always start at the top when switching tabs
            Task { @MainActor in
                // Small delay to ensure the view is fully loaded before scrolling
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                switch newValue {
                case 0:
                    scrollHomeToTopTrigger = UUID()
                case 1:
                    scrollProgressToTopTrigger = UUID()
                case 2:
                    scrollHistoryToTopTrigger = UUID()
                default:
                    break
                }
            }
        }
        .background(TabBarTapDetector(
            onHomeTabTapped: {
                scrollHomeToTopTrigger = UUID()
            },
            onProgressTabTapped: {
                scrollProgressToTopTrigger = UUID()
            },
            onHistoryTabTapped: {
                scrollHistoryToTopTrigger = UUID()
            }
        ))
        .onChange(of: localizationManager.currentLanguage) { _, _ in
            // Language changed - views will automatically update via @ObservedObject
            // No need to recreate the entire hierarchy - this keeps the user in their current view
        }
        .sheet(isPresented: $showingCreateDiet) {
            if let existingPlan = activeDietPlans.first {
                // If plan exists, show editor directly
                DietPlanEditorView(plan: existingPlan, repository: DietPlanRepository(context: modelContext))
            } else {
                // If no plan, show list to create one
                DietPlansListView()
            }
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            SDKView(
                model: sdk,
                page: .splash,
                show: paywallBinding(showPaywall: $showingPaywall, sdk: sdk, showDeclineConfirmation: $showDeclineConfirmation),
                backgroundColor: .white,
                ignoreSafeArea: true
            )
            .paywallDismissalOverlay(showPaywall: $showingPaywall, showDeclineConfirmation: $showDeclineConfirmation)
        }
    }
}

// MARK: - TabBar Tap Detector

/// UIViewControllerRepresentable wrapper that detects re-taps on tab bar items
/// Uses UITabBarControllerDelegate to detect when a user taps an already-selected tab
/// This enables scroll-to-top functionality when re-tapping the same tab
struct TabBarTapDetector: UIViewControllerRepresentable {
    let onHomeTabTapped: () -> Void
    let onProgressTabTapped: () -> Void
    let onHistoryTabTapped: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        DispatchQueue.main.async {
            // Find the UITabBarController in the view hierarchy
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let tabBarController = window.rootViewController as? UITabBarController ?? findTabBarController(in: window.rootViewController) {
                let delegate = TabBarTapDelegate(
                    onHomeTabTapped: onHomeTabTapped,
                    onProgressTabTapped: onProgressTabTapped,
                    onHistoryTabTapped: onHistoryTabTapped
                )
                // Store delegate using associated object to keep it alive
                // This prevents the delegate from being deallocated
                objc_setAssociatedObject(tabBarController, "tabBarTapDelegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                tabBarController.delegate = delegate
            }
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    /// Recursively searches the view controller hierarchy to find UITabBarController
    /// This handles cases where the tab bar controller is nested in other view controllers
    private func findTabBarController(in viewController: UIViewController?) -> UITabBarController? {
        guard let viewController = viewController else { return nil }
        if let tabBarController = viewController as? UITabBarController {
            return tabBarController
        }
        // Recursively search child view controllers
        for child in viewController.children {
            if let tabBarController = findTabBarController(in: child) {
                return tabBarController
            }
        }
        return nil
    }
}

// MARK: - TabBar Tap Delegate

/// UITabBarControllerDelegate implementation that detects re-taps on selected tabs
/// When a user taps a tab that is already selected, this triggers the scroll-to-top action
class TabBarTapDelegate: NSObject, UITabBarControllerDelegate {
    let onHomeTabTapped: () -> Void
    let onProgressTabTapped: () -> Void
    let onHistoryTabTapped: () -> Void
    private var lastSelectedIndex: Int = 0 // Tracks the previously selected tab index
    
    init(
        onHomeTabTapped: @escaping () -> Void,
        onProgressTabTapped: @escaping () -> Void,
        onHistoryTabTapped: @escaping () -> Void
    ) {
        self.onHomeTabTapped = onHomeTabTapped
        self.onProgressTabTapped = onProgressTabTapped
        self.onHistoryTabTapped = onHistoryTabTapped
        super.init()
    }
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        let newIndex = tabBarController.viewControllers?.firstIndex(of: viewController) ?? -1
        
        // If a tab is tapped and it was already selected (re-tap), trigger scroll to top
        // This enables the scroll-to-top functionality when re-tapping the same tab
        if newIndex == lastSelectedIndex {
            switch newIndex {
            case 0:
                onHomeTabTapped()
            case 1:
                onProgressTabTapped()
            case 2:
                onHistoryTabTapped()
            default:
                break
            }
        }
        
        lastSelectedIndex = newIndex
        return true // Always allow the selection
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [Meal.self, MealItem.self, DaySummary.self, WeightEntry.self],
            inMemory: true
        )
}
