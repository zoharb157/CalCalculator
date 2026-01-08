//
//  HomeView.swift
//  playground
//
//  CalAI Clone - Main home screen
//

import SDK
import SwiftUI
import SwiftData
import UserNotifications

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    let repository: MealRepository
    @Bindable var scanViewModel: ScanViewModel
    let scrollToTopTrigger: UUID
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
    @State private var showDeclineConfirmation = false
    @State private var showingDietWelcome = false
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activeDietPlans: [DietPlan]

    init(
        viewModel: HomeViewModel,
        repository: MealRepository,
        scanViewModel: ScanViewModel,
        scrollToTopTrigger: UUID = UUID(),
        onMealSaved: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.repository = repository
        self.scanViewModel = scanViewModel
        self.scrollToTopTrigger = scrollToTopTrigger
        self.onMealSaved = onMealSaved
    }

    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        // This forces the view to update when the language changes
        let _ = localizationManager.currentLanguage
        
        let baseView = mainContent
        
        // Break up the modifier chain into smaller sub-expressions for better compiler performance
        // and to avoid "expression too complex" errors
        let withRefreshAndTasks = baseView
            .refreshable {
                HapticManager.shared.impact(.light)
                await viewModel.refreshTodayData()
                HapticManager.shared.notification(.success)
            }
            .task {
                // Load data asynchronously without blocking the UI
                let startTime = Date()
                print("🟢 [HomeView] .task started - loading data")
                await viewModel.loadData()
                let elapsed = Date().timeIntervalSince(startTime)
                print(
                    "🟢 [HomeView] .task completed - total time: \(String(format: "%.3f", elapsed))s"
                )
                
                // Check for newly earned badges after data loads
                checkForBadges()
                
                // Request notification permission when user first reaches homepage
                // Only requests if authorization status is .notDetermined (first time user sees homepage)
                await requestNotificationPermissionIfNeeded()
                
                // QA: Check real subscription status from SDK for monitoring purposes
                // This is only active in non-DEBUG builds (TestFlight/App Store)
                #if !DEBUG
                Task { @MainActor in
                    do {
                        _ = try await sdk.updateIsSubscribed()
                        let realStatus = sdk.isSubscribed
                        print("🔍 [QA] Real SDK subscription status: \(realStatus ? "Subscribed" : "Not Subscribed")")
                        // Note: We don't update the debug override - this is just for QA monitoring
                    } catch {
                        print("⚠️ [QA] Failed to check real SDK subscription status: \(error)")
                    }
                }
                #endif
            }
            .task(id: viewModel.weekDays.count) {
                // Re-check badges when week days data is loaded
                // This ensures badges are checked after week summaries are available
                if !viewModel.weekDays.isEmpty {
                    checkForBadges()
                }
            }
        
        let withDataObservers = withRefreshAndTasks
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
        
        let withNotifications = withDataObservers
            .onReceive(NotificationCenter.default.publisher(for: .updateLiveActivity)) { _ in
                // Update Live Activity when explicitly requested (e.g., from preferences toggle)
                viewModel.updateLiveActivityIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .exerciseSaved)) { _ in
                // Refresh burned calories when a new exercise is saved
                // This ensures the calorie goal adjustment is recalculated
                Task {
                    await viewModel.refreshBurnedCalories()
                    // Update Live Activity with the new burned calories value
                    viewModel.updateLiveActivityIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .exerciseDeleted)) { _ in
                // Refresh burned calories and today's data when an exercise is deleted
                // This ensures the calorie goal adjustment is recalculated and UI is updated
                Task {
                    await viewModel.refreshBurnedCalories()
                    await viewModel.refreshTodayData()
                    // Update Live Activity with the updated burned calories value
                    viewModel.updateLiveActivityIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .addBurnedCaloriesToggled)) { _ in
                // Refresh burned calories and update UI when the toggle setting changes
                // This recalculates the effective calorie goal
                Task {
                    await viewModel.refreshBurnedCalories()
                    // Update Live Activity with the new goal calculation
                    viewModel.updateLiveActivityIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogged)) { _ in
                // Refresh data when food is logged from the log experience flow
                // This ensures the UI immediately reflects the new meal
                Task {
                    await viewModel.refreshTodayData()
                    checkForBadges()
                    confettiCounter += 1 // Trigger confetti animation
                    viewModel.updateLiveActivityIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // Rebuild weekDays with new locale when language changes
                // This ensures day names and formatting update correctly
                Task { @MainActor in
                    // Force rebuild weekDays with the new locale
                    if let weekSummaries = try? repository.fetchWeekSummaries() {
                        let newWeekDays = viewModel.buildWeekDays(from: weekSummaries, selectedDate: viewModel.selectedDate)
                        viewModel.weekDays = newWeekDays
                    }
                    // Also reload all data to ensure all localized strings update
                    await viewModel.loadData()
                }
            }
        
        // Break up sheets and overlays into separate expression for better organization
        let withSheets = withNotifications
            // Note: No need for onChange modifier - SwiftUI automatically re-evaluates views when
            // @ObservedObject properties change. Since localizationManager.currentLanguage
            // is @Published, all views using localizationManager will update automatically.
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
                    show: paywallBinding(showPaywall: $showingPaywall, sdk: sdk, showDeclineConfirmation: $showDeclineConfirmation),
                    backgroundColor: .white,
                    ignoreSafeArea: true
                )
            }
        
        let withOverlays = withSheets
            .onChange(of: localizationManager.currentLanguage) { oldValue, newValue in
                // Force reload of data when language changes to ensure proper display
                Task {
                    await viewModel.loadData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dietPlanChanged)) { _ in
                // Show welcome view after diet plan is created (if user hasn't seen it)
                if !UserSettings.shared.hasSeenDietWelcome && !activeDietPlans.isEmpty {
                    // Small delay to ensure the sheet is dismissed first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingDietWelcome = true
                    }
                }
            }
            .paywallDismissalOverlay(showPaywall: $showingPaywall, showDeclineConfirmation: $showDeclineConfirmation)
            .overlay {
                if badgeManager.showBadgeAlert, let badge = badgeManager.newlyEarnedBadge {
                    BadgeAlertView(badge: badge) {
                        badgeManager.dismissBadgeAlert()
                    }
                }
            }
            .overlay {
                if showingDietWelcome {
                    DietWelcomeView(isPresented: $showingDietWelcome)
                }
            }
            .overlay(alignment: Alignment.bottomTrailing) {
                floatingMenuOverlay
            }
        
        return withOverlays
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
            ScrollViewReader { proxy in
                List {
                    progressSection
                        .id("home-top") // Anchor point for scrolling to top
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
                .onChange(of: scrollToTopTrigger) { _, _ in
                    // Home tab tap behavior:
                    // - Always scroll to top
                    // - Navigate to current day ONLY if:
                    //   1. Already at top BEFORE this tap (no scroll animation will happen)
                    //   2. Not already on current day
                    
                    // Check scroll position directly from scrollView to get accurate reading
                    let actualScrollOffset = getCurrentScrollOffset()
                    let wasAtTopBeforeScroll = actualScrollOffset <= 50
                    
                    let currentSelectedDate = viewModel.selectedDate
                    let today = Date()
                    let isOnCurrentDay = Calendar.current.isDate(currentSelectedDate, inSameDayAs: today)
                    
                    // If we're already at top, navigate to current day immediately (no scroll needed)
                    if wasAtTopBeforeScroll {
                        if !isOnCurrentDay {
                            HapticManager.shared.impact(.medium)
                            viewModel.selectDay(today)
                        }
                    } else {
                        // Not at top - scroll to top only, don't navigate
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("home-top", anchor: .top)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .scrollHomeToTop)) { _ in
                    // Also support notification-based scrolling (for programmatic triggers)
                    if !isAtTop {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("home-top", anchor: .top)
                        }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 350_000_000) // Wait for animation
                            isAtTop = true
                        }
                    }
                }
                // Track scroll position using UIViewRepresentable with UIScrollView delegate
                .background(
                    ListScrollTracker(isAtTop: $isAtTop)
                )
            }
        }
    }

    @State private var showLogHistorySheet = false
    @State private var isAtTop = true // Tracks if the scroll view is currently at the top position
    
    /// Gets the current scroll offset by finding the UIScrollView in the view hierarchy
    /// Tries to find the List's scrollView specifically
    private func getCurrentScrollOffset() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
            return 0
        }
        
        // Find all UIScrollViews and try to find the one that belongs to our List
        // SwiftUI List uses UICollectionView which contains a UIScrollView
        // We'll look for the largest scrollView (likely the main List scrollView)
        var allScrollViews: [UIScrollView] = []
        findAllScrollViews(in: window.rootViewController?.view, found: &allScrollViews)
        
        // Find the scrollView with the largest contentSize (likely the main List)
        if let mainScrollView = allScrollViews.max(by: { $0.contentSize.height < $1.contentSize.height }) {
            return mainScrollView.contentOffset.y
        }
        
        return 0
    }
    
    private func findAllScrollViews(in view: UIView?, found: inout [UIScrollView]) {
        guard let view = view else { return }
        
        if let scrollView = view as? UIScrollView {
            found.append(scrollView)
        }
        
        for subview in view.subviews {
            findAllScrollViews(in: subview, found: &found)
        }
    }
    
    private func findScrollViewInHierarchy(startingFrom view: UIView?) -> UIScrollView? {
        guard let view = view else { return nil }
        
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        
        for subview in view.subviews {
            if let scrollView = findScrollViewInHierarchy(startingFrom: subview) {
                return scrollView
            }
        }
        
        return nil
    }

    @State private var showDietSummarySheet = false
    @State private var showingEditDietPlan = false
    @State private var selectedDietPlan: DietPlan?
    
    private var logExperienceSection: some View {
        // Use selected date's burned calories, or today's if viewing today
        // This ensures the card shows correct data when viewing historical dates
        let burnedCalories = Calendar.current.isDateInToday(viewModel.selectedDate) 
            ? viewModel.todaysBurnedCalories 
            : viewModel.selectedDateBurnedCalories
        
        // Use selected date's exercise count from viewModel
        // This ensures consistency with the burned calories calculation
        let exercisesCount = viewModel.selectedDateExercisesCount
        
        return LogExperienceCard(
            mealsCount: viewModel.recentMeals.count,
            exercisesCount: exercisesCount,
            totalCaloriesConsumed: viewModel.todaysSummary?.totalCalories ?? 0,
            totalCaloriesBurned: burnedCalories,
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
                if activeDietPlans.isEmpty {
                    // No active plan - show create plan screen
                    DietPlansListView()
                        .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.myDiet))
                } else {
                    // Active plan exists - show diet summary
                    EnhancedDietSummaryView()
                }
            }
        }
        .sheet(isPresented: $showingEditDietPlan) {
            if let plan = selectedDietPlan {
                DietPlanEditorView(plan: plan, repository: DietPlanRepository(context: modelContext))
            }
        }
    }

    // MARK: - FAB (Floating Action Button) Constants
    
    private enum FABConstants {
        static let fabSize: CGFloat = 60
        static let fabPadding: CGFloat = 20
    }
    
    @ViewBuilder
    private var floatingMenuOverlay: some View {
        // Only show the floating action button if the selected date is today
        // Users can only log new meals/exercises for the current day
        if Calendar.current.isDateInToday(viewModel.selectedDate) {
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    // FAB button - opens camera directly to scan food
                    // This is the primary action for logging meals
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
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        return WeekDaysHeader(weekDays: viewModel.weekDays) { selectedDate in
            HapticManager.shared.impact(.medium)
            viewModel.selectDay(selectedDate)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8),
            value: viewModel.weekDays.map { $0.progress })
    }
    
    private var progressSection: some View {
        // Use selected date's burned calories, or today's if viewing today
        // This ensures the progress card shows correct data when viewing historical dates
        let burnedCalories = Calendar.current.isDateInToday(viewModel.selectedDate) 
            ? viewModel.todaysBurnedCalories 
            : viewModel.selectedDateBurnedCalories
        
        return TodaysProgressCard(
            summary: viewModel.todaysSummary,
            calorieGoal: viewModel.effectiveCalorieGoal,
            remainingCalories: viewModel.remainingCalories,
            progress: viewModel.calorieProgress,
            goalAdjustment: viewModel.goalAdjustmentDescription,
            burnedCalories: burnedCalories
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
            Text(localizationManager.localizedString(for: AppStrings.Home.macronutrients))
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
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

    // Recently uploaded empty section - shown when no meals are logged for today
    // Matches the reference design with proper styling
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
            Text(localizationManager.localizedString(for: AppStrings.Home.recentlyUploaded))
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
    
    // Meals section with images - shown at the end when there are meals to display
    // Displays recent meals in a scrollable grid format
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
    
    // MARK: - Notification Permission
    
    /// Requests notification permission when user first reaches the homepage
    /// Only requests if authorization status is .notDetermined (first time user sees homepage)
    /// This ensures we don't repeatedly prompt users who have already granted or denied permission
    @MainActor
    private func requestNotificationPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        // Only request if status is not determined (first time user sees homepage)
        // If already granted or denied, we respect that decision
        guard settings.authorizationStatus == .notDetermined else {
            return
        }
        
        // Request permission (this will show the system permission dialog)
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                print("✅ [HomeView] Notification permission granted")
            } else {
                print("⚠️ [HomeView] Notification permission denied")
            }
        } catch {
            print("❌ [HomeView] Failed to request notification permission: \(error)")
        }
    }
}

// MARK: - Scroll Position Tracking

/// UIViewRepresentable to track scroll position in List using UIScrollView delegate
struct ListScrollTracker: UIViewRepresentable {
    @Binding var isAtTop: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Find the UIScrollView in the window hierarchy (not in uiView which is just an empty view)
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
                // Retry after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateUIView(uiView, context: context)
                }
                return
            }
            
            // Find UIScrollView in the window hierarchy
            // SwiftUI List uses UICollectionView which contains a UIScrollView
            if let scrollView = self.findScrollViewInWindow(window) {
                // Check if we already have an observer for this scrollView
                if let existingObserver = objc_getAssociatedObject(scrollView, "scrollObserver") as? ScrollObserver {
                    // Update the binding if observer already exists
                    return
                }
                
                // Remove any existing observer
                if let existingObserver = objc_getAssociatedObject(scrollView, "scrollObserver") as? ScrollObserver {
                    scrollView.removeObserver(existingObserver, forKeyPath: "contentOffset")
                }
                
                // Add observer to track contentOffset
                let observer = ScrollObserver { [weak scrollView] in
                    guard let scrollView = scrollView else { return }
                    let offset = scrollView.contentOffset.y
                    // Consider at top if offset is within 50 points (accounts for List padding and safe area)
                    self.isAtTop = offset <= 50
                }
                observer.scrollView = scrollView
                
                scrollView.addObserver(observer, forKeyPath: "contentOffset", options: [.new], context: nil)
                objc_setAssociatedObject(scrollView, "scrollObserver", observer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                // Set initial value
                let initialOffset = scrollView.contentOffset.y
                self.isAtTop = initialOffset <= 50
            } else {
                // Retry after delay if scroll view not found
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateUIView(uiView, context: context)
                }
            }
        }
    }
    
    private func findScrollViewInWindow(_ window: UIWindow) -> UIScrollView? {
        // Look for UIScrollView in the window hierarchy
        // SwiftUI List uses UICollectionView which contains a UIScrollView
        return findScrollView(in: window.rootViewController?.view)
    }
    
    private func findScrollView(in view: UIView?) -> UIScrollView? {
        guard let view = view else { return nil }
        
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        
        for subview in view.subviews {
            if let scrollView = findScrollView(in: subview) {
                return scrollView
            }
        }
        
        return nil
    }
}

/// Observer class for UIScrollView contentOffset changes
class ScrollObserver: NSObject {
    let onChange: () -> Void
    weak var scrollView: UIScrollView?
    
    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        super.init()
    }
    
    nonisolated override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" {
            Task { @MainActor in
                self.onChange()
            }
        }
    }
    
    deinit {
        // Remove observer when deallocated
        if let scrollView = scrollView {
            scrollView.removeObserver(self, forKeyPath: "contentOffset")
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
