//
//  HomeView.swift
//  playground
//
//  CalAI Clone - Main home screen
//

import MavenCommonSwiftUI
import SDK
import SwiftUI
import SwiftData

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    let repository: MealRepository
    @Bindable var scanViewModel: ScanViewModel
    var onMealSaved: () -> Void

    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @Environment(\.locale) private var locale
    @ObservedObject private var localizationManager = LocalizationManager.shared

    private var settings = UserSettings.shared
    @State private var badgeManager = BadgeManager.shared

    @State private var showScanSheet = false
    @State private var showLogFoodSheet = false
    @State private var showLogExerciseSheet = false
    @State private var showBadgesSheet = false
    @State private var showQuickLogSheet = false
    @State private var showTextLogSheet = false
    @State private var confettiCounter = 0
    @State private var showBadgeAlert = false
    @State private var showingCreateDiet = false
    @State private var showingPaywall = false
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activeDietPlans: [DietPlan]

    init(
        viewModel: HomeViewModel,
        repository: MealRepository,
        scanViewModel: ScanViewModel,
        onMealSaved: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.repository = repository
        self.scanViewModel = scanViewModel
        self.onMealSaved = onMealSaved
    }

    var body: some View {
        let baseView =
            mainContent

        return
            baseView
            .refreshable {
                HapticManager.shared.impact(.light)
                await viewModel.refreshTodayData()
                HapticManager.shared.notification(.success)
            }
            .task {
                // Load data without blocking UI
                let startTime = Date()
                print("🟢 [HomeView] .task started - loading data")
                await viewModel.loadData()
                let elapsed = Date().timeIntervalSince(startTime)
                print(
                    "🟢 [HomeView] .task completed - total time: \(String(format: "%.3f", elapsed))s"
                )
                checkForBadges()
            }
            .task(id: viewModel.weekDays.count) {
                // Re-check badges when week days are loaded
                if !viewModel.weekDays.isEmpty {
                    checkForBadges()
                }
            }
            .onChange(of: viewModel.recentMeals.count) { _, _ in
                checkForBadges()
                // Update Live Activity when meals change
                viewModel.updateLiveActivityIfNeeded()
            }
            .onChange(of: viewModel.todaysSummary?.totalCalories) { _, _ in
                // Update Live Activity when calories change
                viewModel.updateLiveActivityIfNeeded()
            }
            .onChange(of: viewModel.todaysBurnedCalories) { _, _ in
                // Update Live Activity when burned calories change
                viewModel.updateLiveActivityIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .updateLiveActivity)) { _ in
                // Update Live Activity when requested (e.g., from preferences toggle)
                viewModel.updateLiveActivityIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .exerciseSaved)) { _ in
                // Refresh burned calories when an exercise is saved
                Task {
                    await viewModel.refreshBurnedCalories()
                    // Update Live Activity with new burned calories
                    viewModel.updateLiveActivityIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .addBurnedCaloriesToggled)) { _ in
                // Refresh burned calories and update UI when toggle changes
                Task {
                    await viewModel.refreshBurnedCalories()
                    // Update Live Activity with new goal
                    viewModel.updateLiveActivityIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogged)) { _ in
                // Refresh data when food is logged from the log experience
                Task {
                    await viewModel.refreshTodayData()
                    checkForBadges()
                    confettiCounter += 1
                    viewModel.updateLiveActivityIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // Force view refresh when language changes
                // This ensures all localized strings update immediately
            }
            .id("home-view-\(localizationManager.currentLanguage)")
            .sheet(isPresented: $showScanSheet) {
                ScanView(
                    viewModel: scanViewModel,
                    onMealSaved: {
                        showScanSheet = false
                        confettiCounter += 1
                        onMealSaved()
                    },
                    onDismiss: {
                        showScanSheet = false
                    }
                )
            }
            .sheet(isPresented: $showLogFoodSheet) {
                LogFoodView()
            }
            .sheet(isPresented: $showLogExerciseSheet) {
                LogExerciseView()
            }
            .sheet(isPresented: $showQuickLogSheet) {
                QuickLogView()
            }
            .sheet(isPresented: $showTextLogSheet) {
                TextFoodLogView()
            }
            .sheet(isPresented: $showBadgesSheet) {
                BadgesView()
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
                    show: Binding(
                        get: { showingPaywall },
                        set: { newValue in
                            if !newValue && showingPaywall {
                                // Paywall was dismissed - THIS IS THE ONLY PLACE WE CHECK SUBSCRIPTION STATUS
                                Task { @MainActor in
                                    // Update subscription status from SDK
                                    do {
                                        try await sdk.updateIsSubscribed()
                                        // Update reactive subscription status in app
                                        NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
                                    } catch {
                                        print("⚠️ Failed to update subscription status: \(error)")
                                    }
                                    
                                    // Check SDK directly
                                    if sdk.isSubscribed {
                                        // User subscribed - reset analysis count
                                        AnalysisLimitManager.shared.resetAnalysisCount()
                                    }
                                }
                            }
                            showingPaywall = newValue
                        }
                    ),
                    backgroundColor: .white,
                    ignoreSafeArea: true
                )
            }
            .confettiCannon(trigger: $confettiCounter)
            .overlay {
                if badgeManager.showBadgeAlert, let badge = badgeManager.newlyEarnedBadge {
                    BadgeAlertView(badge: badge) {
                        badgeManager.dismissBadgeAlert()
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                floatingMenuOverlay
            }
            .onChange(of: badgeManager.showBadgeAlert) { _, newValue in
                if newValue {
                    confettiCounter += 1
                }
            }
    }

    // MARK: - Badge Checking

    private func checkForBadges() {
        let totalMeals = viewModel.recentMeals.count
        let totalExercises = (try? repository.fetchTodaysExercises().count) ?? 0

        var weekSummaries: [Date: DaySummary] = [:]
        for day in viewModel.weekDays {
            if let summary = day.summary {
                weekSummaries[Calendar.current.startOfDay(for: day.date)] = summary
            }
        }

        badgeManager.checkForNewBadges(
            totalMeals: totalMeals,
            todaysSummary: viewModel.todaysSummary,
            weekSummaries: weekSummaries,
            totalExercises: totalExercises,
            calorieGoal: viewModel.effectiveCalorieGoal,
            proteinGoal: settings.proteinGoal
        )
    }

    // MARK: - Private Views

    private var mainContent: some View {
        NavigationStack {
            contentView
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { mealId in
                MealDetailView(mealId: mealId, repository: repository)
            }
        }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            // Week days header at the very top
            weekDaysSection
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color(.systemGroupedBackground))

            // Rest of the content
            List {
                progressSection
                logExperienceSection
                dietPlanSection
                macroSection
                badgesSection
                healthKitSection
                
                // Recently uploaded section - show meals or empty state
                if !viewModel.recentMeals.isEmpty {
                    mealsSection
                } else if Calendar.current.isDateInToday(viewModel.selectedDate) {
                    // Show empty state only for today
                    recentlyUploadedEmptySection
                }
            }
            .listStyle(.plain)
        }
    }

    @State private var showLogHistorySheet = false

    @State private var showDietSummarySheet = false
    @State private var showingEditDietPlan = false
    @State private var selectedDietPlan: DietPlan?
    
    private var logExperienceSection: some View {
        LogExperienceCard(
            mealsCount: viewModel.recentMeals.count,
            exercisesCount: (try? repository.fetchTodaysExercises().count) ?? 0,
            totalCaloriesConsumed: viewModel.todaysSummary?.totalCalories ?? 0,
            totalCaloriesBurned: viewModel.todaysBurnedCalories,
            onLogFood: {
                showLogFoodSheet = true
            },
            onLogExercise: {
                showLogExerciseSheet = true
            },
            onTextLog: {
                showTextLogSheet = true
            },
            onViewHistory: {
                showLogHistorySheet = true
            },
            onViewDiet: {
                if isSubscribed {
                    showDietSummarySheet = true
                } else {
                    showingPaywall = true
                }
            }
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .sheet(isPresented: $showLogHistorySheet) {
            LogHistoryView(repository: repository)
        }
        .sheet(isPresented: $showDietSummarySheet) {
            NavigationStack {
                EnhancedDietSummaryView()
            }
        }
        .sheet(isPresented: $showingEditDietPlan) {
            if let plan = selectedDietPlan {
                DietPlanEditorView(plan: plan, repository: DietPlanRepository(context: modelContext))
            }
        }
    }

    // MARK: - FAB Button Constants
    
    private enum FABConstants {
        static let fabSize: CGFloat = 60
        static let fabPadding: CGFloat = 20
    }
    
    @ViewBuilder
    private var floatingMenuOverlay: some View {
        // Only show + button if selected date is today
        if Calendar.current.isDateInToday(viewModel.selectedDate) {
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    // FAB button - opens camera directly to scan food
                    Button {
                        HapticManager.shared.impact(.light)
                        showScanSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: FABConstants.fabSize, height: FABConstants.fabSize)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(
                                color: Color.blue.opacity(0.4),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    }
                    .padding(.trailing, FABConstants.fabPadding)
                    .padding(.bottom, FABConstants.fabPadding)
                }
            }
        }
    }

    private var weekDaysSection: some View {
        WeekDaysHeader(weekDays: viewModel.weekDays) { selectedDate in
            HapticManager.shared.impact(.medium)
            viewModel.selectDay(selectedDate)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8),
            value: viewModel.weekDays.map { $0.progress })
    }

    private var progressSection: some View {
        TodaysProgressCard(
            summary: viewModel.todaysSummary,
            calorieGoal: viewModel.effectiveCalorieGoal,
            remainingCalories: viewModel.remainingCalories,
            progress: viewModel.calorieProgress,
            goalAdjustment: viewModel.goalAdjustmentDescription,
            burnedCalories: viewModel.todaysBurnedCalories
        )
        .opacity((viewModel.hasDataLoaded) ? 1.0 : 0.3)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private var dietPlanSection: some View {
        if isSubscribed {
            DietPlanCard()
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("editDietPlan"))) { notification in
                    if let plan = notification.object as? DietPlan {
                        selectedDietPlan = plan
                        showingEditDietPlan = true
                    }
                }
        }
    }

    private var badgesSection: some View {
        PremiumLockedContent {
            BadgesCard {
                showBadgesSheet = true
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var macroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LocalizedText(AppStrings.Home.macronutrients, comment: "Section title for macronutrients")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
                .id("macronutrients-\(localizationManager.currentLanguage)")
            
            PremiumLockedContent {
                MacroCardsSection(
                    summary: viewModel.todaysSummary,
                    goals: settings.macroGoals
                )
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var healthKitSection: some View {
        HealthKitCard()
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    // Recently uploaded empty section - matches reference design
    @ViewBuilder
    private var recentlyUploadedEmptySection: some View {
        Section {
            RecentlyUploadedEmptyCard(onAddMeal: {
                showScanSheet = true
            })
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } header: {
            LocalizedText(AppStrings.Home.recentlyUploaded, comment: "Section header for recently uploaded meals")
                .font(.headline)
                .foregroundColor(.primary)
                .id("recently-uploaded-\(localizationManager.currentLanguage)")
        }
    }
    
    // Meals section with images - shown at the end when there are meals
    @ViewBuilder
    private var mealsSection: some View {
        RecentMealsSection(
            meals: viewModel.recentMeals,
            repository: repository,
            onDelete: { meal in
                Task {
                    await viewModel.deleteMeal(meal)
                }
            }
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}


#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = HomeViewModel(repository: repository, imageStorage: .shared)
    let scanViewModel = ScanViewModel(
        repository: repository,
        analysisService: CaloriesAPIService(),
        imageStorage: .shared
    )

    HomeView(
        viewModel: viewModel,
        repository: repository,
        scanViewModel: scanViewModel,
        onMealSaved: {}
    )
}
