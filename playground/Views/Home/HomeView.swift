//
//  HomeView.swift
//  playground
//
//  CalAI Clone - Main home screen
//

import SwiftUI
import MavenCommonSwiftUI
import SDK

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    let repository: MealRepository
    @Bindable var scanViewModel: ScanViewModel
    var onMealSaved: () -> Void
    
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    
    private var settings = UserSettings.shared
    @State private var badgeManager = BadgeManager.shared
    
    @State private var showScanSheet = false
    @State private var showLogFoodSheet = false
    @State private var showLogExerciseSheet = false
    @State private var showBadgesSheet = false
    @State private var showingFloatingMenu = false
    @State private var confettiCounter = 0
    @State private var showBadgeAlert = false
    @State private var showingCreateDiet = false
    @State private var showingPaywall = false
    @Environment(\.modelContext) private var modelContext
    
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
        NavigationStack {
            ZStack {
                contentView
                floatingMenuOverlay
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { mealId in
                MealDetailView(mealId: mealId, repository: repository)
            }
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
                print("🟢 [HomeView] .task completed - total time: \(String(format: "%.3f", elapsed))s")
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
            .sheet(isPresented: $showBadgesSheet) {
                BadgesView()
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
            .confettiCannon(trigger: $confettiCounter)
            .overlay {
                if badgeManager.showBadgeAlert, let badge = badgeManager.newlyEarnedBadge {
                    BadgeAlertView(badge: badge) {
                        badgeManager.dismissBadgeAlert()
                    }
                }
            }
            .onChange(of: badgeManager.showBadgeAlert) { _, newValue in
                if newValue {
                    confettiCounter += 1
                }
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
                dietPlanSection
                macroSection
                badgesSection
                healthKitSection
                mealsSection
            }
            .listStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var floatingMenuOverlay: some View {
        ZStack {
            // Dimmed background when menu is open
            if showingFloatingMenu {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingFloatingMenu = false
                        }
                    }
            }
            
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 12) {
                        // Menu items (shown when expanded)
                        if showingFloatingMenu {
                            FloatingMenuItem(
                                icon: "calendar.badge.plus",
                                title: "Create Diet Plan",
                                color: .blue
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showingFloatingMenu = false
                                }
                                if isSubscribed {
                                    showingCreateDiet = true
                                } else {
                                    showingPaywall = true
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).combined(with: .offset(x: 0, y: 20)),
                                removal: .scale.combined(with: .opacity)
                            ))
                            
                            FloatingMenuItem(
                                icon: "dumbbell.fill",
                                title: "Log Exercise",
                                color: .orange
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showingFloatingMenu = false
                                }
                                showLogExerciseSheet = true
                            }
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).combined(with: .offset(x: 0, y: 20)),
                                removal: .scale.combined(with: .opacity)
                            ))
                            
                            FloatingMenuItem(
                                icon: "pencil.line",
                                title: "Log Food",
                                color: .green
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showingFloatingMenu = false
                                }
                                showLogFoodSheet = true
                            }
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).combined(with: .offset(x: 0, y: 20)),
                                removal: .scale.combined(with: .opacity)
                            ))
                            
                            FloatingMenuItem(
                                icon: "camera.fill",
                                title: "Scan Meal",
                                color: .purple
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showingFloatingMenu = false
                                }
                                showScanSheet = true
                            }
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).combined(with: .offset(x: 0, y: 20)),
                                removal: .scale.combined(with: .opacity)
                            ))
                        }
                        
                        // Main FAB button
                        Button {
                            HapticManager.shared.impact(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingFloatingMenu.toggle()
                            }
                        } label: {
                            Image(systemName: showingFloatingMenu ? "xmark" : "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    LinearGradient(
                                        colors: showingFloatingMenu ? [.gray, .gray.opacity(0.8)] : [.blue, .blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: (showingFloatingMenu ? Color.gray : Color.blue).opacity(0.4), radius: 8, x: 0, y: 4)
                                .rotationEffect(.degrees(showingFloatingMenu ? 180 : 0))
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
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
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.weekDays.map { $0.progress })
    }
    
    private var progressSection: some View {
        TodaysProgressCard(
            summary: viewModel.todaysSummary,
            calorieGoal: viewModel.effectiveCalorieGoal,
            remainingCalories: viewModel.remainingCalories,
            progress: viewModel.calorieProgress,
            goalAdjustment: viewModel.goalAdjustmentDescription
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
        PremiumLockedContent {
            MacroCardsSection(
                summary: viewModel.todaysSummary,
                goals: settings.macroGoals
            )
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
    
    @ViewBuilder
    private var mealsSection: some View {
        Group {
            if !viewModel.recentMeals.isEmpty {
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
            } else {
                EmptyMealsView(onScanTapped: {
                    showScanSheet = true
                })
                .opacity((viewModel.hasDataLoaded) ? 1.0 : 0.3)
                .listRowInsets(EdgeInsets(top: 40, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }
}

// MARK: - Floating Menu Item

struct FloatingMenuItem: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 2)
            }
        }
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
