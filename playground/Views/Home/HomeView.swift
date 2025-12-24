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
    @State private var showingFloatingMenu = false
    @State private var confettiCounter = 0
    @State private var showBadgeAlert = false
    
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
            .navigationTitle("Today")
            .navigationDestination(for: UUID.self) { mealId in
                MealDetailView(mealId: mealId, repository: repository)
            }
            .refreshable {
                await viewModel.refreshTodayData()
            }
            .task {
                await viewModel.loadData()
                checkForBadges()
            }
            .onChange(of: viewModel.recentMeals.count) { _, _ in
                checkForBadges()
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
        List {
            weekDaysSection
            progressSection
            healthKitSection
            macroSection
            mealsSection
        }
        .listStyle(.plain)
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
        WeekDaysHeader(weekDays: viewModel.weekDays)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
    
    private var progressSection: some View {
        TodaysProgressCard(
            summary: viewModel.todaysSummary,
            calorieGoal: viewModel.effectiveCalorieGoal,
            remainingCalories: viewModel.remainingCalories,
            progress: viewModel.calorieProgress,
            goalAdjustment: viewModel.goalAdjustmentDescription
        )
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
        .listRowInsets(EdgeInsets(.zero))
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
            } else {
                EmptyMealsView()
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
