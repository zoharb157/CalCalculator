//
//  MainTabView.swift
//  playground
//
//  Created by Bassam-Hillo on 16/12/2025.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    var repository: MealRepository

    @State private var selectedTab = 0

    @State var homeViewModel: HomeViewModel
    @State var scanViewModel: ScanViewModel
    @State var historyViewModel: HistoryViewModel
    @State var settingsViewModel: SettingsViewModel
    
    init(repository: MealRepository) {
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
        _settingsViewModel = State(
            initialValue: SettingsViewModel(
                repository: repository,
                imageStorage: .shared
            )
        )
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                viewModel: homeViewModel,
                repository: repository,
                scanViewModel: scanViewModel,
                onMealSaved: {
                    Task {
                        await homeViewModel.refreshTodayData()
                        await historyViewModel.loadData()
                    }
                }
            )
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)
            
            HistoryView(viewModel: historyViewModel, repository: repository)
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .tag(1)
            
            SettingsView(viewModel: settingsViewModel, onDataDeleted: {
                Task {
                    await homeViewModel.loadData()
                    await historyViewModel.loadData()
                }
            })
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [Meal.self, MealItem.self, DaySummary.self],
            inMemory: true
        )
}
