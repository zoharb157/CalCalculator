//
//  MainTabView.swift
//  playground
//
//  Created by Bassam-Hillo on 16/12/2025.
//

import SwiftUI
import SwiftData
import SDK

struct MainTabView: View {
    var repository: MealRepository
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var selectedTab = 0
    @StateObject private var networkMonitor = NetworkMonitor.shared

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
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
            HomeView(
                viewModel: homeViewModel,
                repository: repository,
                scanViewModel: scanViewModel,
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
                    .id("tab-home-\(localizationManager.currentLanguage)")
            }
            .tag(0)
            
            ProgressDashboardView(viewModel: progressViewModel)
                .tabItem {
                    Label(localizationManager.localizedString(for: AppStrings.Progress.title), systemImage: "chart.line.uptrend.xyaxis")
                        .id("tab-progress-\(localizationManager.currentLanguage)")
                }
                .tag(1)
            
            HistoryOrDietView(
                viewModel: historyViewModel,
                repository: repository,
                tabName: hasActiveDiet ? localizationManager.localizedString(for: AppStrings.DietPlan.myDiet) : localizationManager.localizedString(for: AppStrings.History.title)
            )
                .tabItem {
                    Label(hasActiveDiet ? localizationManager.localizedString(for: AppStrings.DietPlan.myDiet) : localizationManager.localizedString(for: AppStrings.History.title), systemImage: "calendar")
                        .id("tab-history-\(localizationManager.currentLanguage)")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label(localizationManager.localizedString(for: AppStrings.Profile.title), systemImage: "person.fill")
                        .id("tab-profile-\(localizationManager.currentLanguage)")
                }
                .tag(3)
            }
            .id("main-tabview-\(localizationManager.currentLanguage)")
            
            // Offline banner
            if !networkMonitor.isConnected {
                VStack {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.white)
                        Text(localizationManager.localizedString(for: AppStrings.Main.noInternetConnection))
                            .id("no-internet-\(localizationManager.currentLanguage)")
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
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            // Force TabView to refresh when language changes
            // This ensures all tab labels update immediately
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [Meal.self, MealItem.self, DaySummary.self, WeightEntry.self],
            inMemory: true
        )
}
