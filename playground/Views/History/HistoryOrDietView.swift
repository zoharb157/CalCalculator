//
//  HistoryOrDietView.swift
//  playground
//
//  Shows History or Diet view based on whether user has an active diet plan
//

import Charts
import SDK
import SwiftData
import SwiftUI

struct HistoryOrDietView: View {
    @Bindable var viewModel: HistoryViewModel
    let repository: MealRepository
    let tabName: String

    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(\.modelContext) private var modelContext
    @Environment(TheSDK.self) private var sdk
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activeDietPlans:
        [DietPlan]
    @State private var showingCreateDiet = false
    @State private var showingPaywall = false
    @State private var showingWelcome = false

    private var hasActiveDiet: Bool {
        !activeDietPlans.isEmpty
    }

    // Picker tabs
    private enum TopTab: String, CaseIterable, Identifiable {
        case dietPlan, history
        var id: String { rawValue }
        var title: String {
            switch self {
            case .dietPlan:
                return LocalizationManager.shared.localizedString(for: AppStrings.DietPlan.myDiet)
            case .history:
                return LocalizationManager.shared.localizedString(for: AppStrings.History.title)
            }
        }
    }

    @State private var selectedTab: TopTab = .dietPlan

    var body: some View {
        Group {
            if hasActiveDiet && isSubscribed {
                VStack(spacing: 0) {
                    Picker("Select View", selection: $selectedTab) {
                        ForEach(TopTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding([.horizontal, .top])

                    if selectedTab == .dietPlan {
                        DietView(
                            viewModel: viewModel,
                            repository: repository
                        )
                        .navigationTitle(
                            localizationManager.localizedString(for: AppStrings.DietPlan.myDiet)
                        )
                        .id("my-diet-nav-\(localizationManager.currentLanguage)")
                    } else {
                        HistoryView(
                            viewModel: viewModel,
                            repository: repository,
                            isSubscribed: isSubscribed,
                            hasActiveDiet: hasActiveDiet,
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
            } else {
                // Show history with option to create diet (no picker)
                HistoryView(
                    viewModel: viewModel,
                    repository: repository,
                    isSubscribed: isSubscribed,
                    hasActiveDiet: hasActiveDiet,
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
        .sheet(isPresented: $showingCreateDiet) {
            DietPlansListView()
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            SDKView(
                model: sdk,
                page: .splash,
                show: $showingPaywall,
                backgroundColor: .white,
                ignoreSafeArea: true
            )
        }
        .overlay {
            if showingWelcome {
                DietWelcomeView(isPresented: $showingWelcome)
            }
        }
        .onChange(of: hasActiveDiet) { oldValue, newValue in
            // Show welcome when user first creates a diet plan
            if newValue && !oldValue && !UserSettings.shared.hasSeenDietWelcome {
                showingWelcome = true
                UserSettings.shared.hasSeenDietWelcome = true
            }
        }
        .onAppear {
            // Show welcome if user has active diet but hasn't seen it yet
            if hasActiveDiet && !UserSettings.shared.hasSeenDietWelcome {
                showingWelcome = true
                UserSettings.shared.hasSeenDietWelcome = true
            }
        }
    }
}

// MARK: - Combined Diet and History View

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = HistoryViewModel(repository: repository)

    HistoryOrDietView(viewModel: viewModel, repository: repository, tabName: "History")
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self, Meal.self])
}
