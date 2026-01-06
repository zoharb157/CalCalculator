//
//  ProgressView.swift
//  playground
//
//  Progress tracking dashboard with weight, BMI, calories, and HealthKit integration
//

import SwiftUI
import Charts
import SDK

struct ProgressDashboardView: View {
    @Bindable var viewModel: ProgressViewModel
    let scrollToTopTrigger: UUID
    
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    // Observe UserSettings directly for weight updates
    @Bindable private var settings = UserSettings.shared
    
    @State private var showWeightInput = false
    @State private var showPaywall = false
    @State private var showDeclineConfirmation = false
    
    init(viewModel: ProgressViewModel, scrollToTopTrigger: UUID = UUID()) {
        self.viewModel = viewModel
        self.scrollToTopTrigger = scrollToTopTrigger
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        // This forces the view to update when the language changes
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            mainContent
                .navigationTitle(LocalizationManager.shared.localizedString(for: AppStrings.Progress.title))
                .refreshable {
                    await viewModel.loadData()
                }
                .modifier(TaskModifiers(viewModel: viewModel, isSubscribed: isSubscribed, showWeightInput: $showWeightInput, showPaywall: $showPaywall))
                .modifier(SheetModifiers(viewModel: viewModel, settings: settings, showWeightInput: $showWeightInput, showPaywall: $showPaywall, showDeclineConfirmation: $showDeclineConfirmation, sdk: sdk))
                .modifier(NotificationModifiers(viewModel: viewModel, settings: settings, isSubscribed: isSubscribed, showWeightInput: $showWeightInput, showPaywall: $showPaywall, showDeclineConfirmation: $showDeclineConfirmation, scrollToTopTrigger: scrollToTopTrigger))
                .onReceive(NotificationCenter.default.publisher(for: .widgetWeightUpdated)) { _ in
                    // Handle weight update from widget (triggered when app becomes active)
                    // This processes any pending weight updates from the widget extension
                    // Note: Widget updates are handled in NotificationModifiers
                }
                .onChange(of: localizationManager.currentLanguage) { oldValue, newValue in
                    // Force reload of data when language changes to ensure proper display
                    Task {
                        await viewModel.loadData()
                    }
                }
                .paywallDismissalOverlay(showPaywall: $showPaywall, showDeclineConfirmation: $showDeclineConfirmation)
                .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - View Components
    
    /// Main content view - extracted to help compiler type-check
    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading && viewModel.weightHistory.isEmpty {
            FullScreenLoadingView(message: localizationManager.localizedString(for: AppStrings.Progress.loadingProgressData))
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                            // Current Weight Card - displays current weight with increment/decrement controls
                            // Use .id() modifier to force re-render when weight or history changes
                            CurrentWeightCard(
                                weight: settings.displayWeight,
                                unit: viewModel.weightUnit,
                                startWeight: viewModel.weightHistory.first?.weight ?? settings.displayWeight,
                                goalWeight: viewModel.displayTargetWeight,
                                daysUntilCheck: viewModel.daysUntilNextWeightCheck,
                                isSubscribed: isSubscribed,
                                onWeightSave: { newWeight in
                                    Task {
                                        await viewModel.updateWeight(newWeight)
                                    }
                                },
                                onShowPaywall: {
                                    showPaywall = true
                                },
                                onViewProgress: {
                                    if isSubscribed {
                                        viewModel.showWeightProgressSheet = true
                                    } else {
                                        showPaywall = true
                                    }
                                }
                            )
                            .id("progress-top") // Anchor point for scrolling to top when tab is re-tapped
                            
                            // Weight Chart Card - displays weight trend over time
                            // Use .id() modifier to force re-render when history count or values change
                            WeightChartCard(
                                weightHistory: viewModel.weightHistory,
                                useMetricUnits: viewModel.useMetricUnits
                            )
                            .id("weight-chart-\(viewModel.weightHistory.count)-\(viewModel.weightHistory.last?.weight ?? 0)")
                            
                            // Weight Changes Card - shows weight changes over different timeframes
                            // Uses the most recent weight from history (last item when sorted ascending),
                            // or current weight from settings if no history exists
                            // Component already has .id() modifier to handle updates
                            WeightChangesCard(
                                weightHistory: viewModel.weightHistory,
                                currentWeight: viewModel.mostRecentWeight,
                                useMetricUnits: viewModel.useMetricUnits
                            )
                            
                            // Daily Average Calories Card - shows average daily calorie consumption
                            // Locked with blur + Premium button (Progress page uses reduced blur for better visibility)
                            PremiumLockedContent(isProgressPage: true) {
                                DailyCaloriesCard(
                                    averageCalories: viewModel.averageCalories,
                                    calorieGoal: UserSettings.shared.calorieGoal,
                                    hourlyCalories: viewModel.hourlyCalories,
                                    isSubscribed: isSubscribed,
                                    onViewDetails: {
                                        if isSubscribed {
                                            viewModel.showCaloriesSheet = true
                                        } else {
                                            showPaywall = true
                                        }
                                    }
                                )
                            }
                            
                            // BMI Card - displays Body Mass Index with category and visual scale
                            // Locked with blur + Premium button (Progress page uses reduced blur)
                            if let bmi = viewModel.bmi, let category = viewModel.bmiCategory {
                                PremiumLockedContent(isProgressPage: true) {
                                    BMICard(bmi: bmi, category: category, isSubscribed: true)
                                }
                            }
                            
                            // HealthKit Data Section - displays steps, calories, exercise, heart rate, etc.
                            // FREE feature (no premium lock) - available to all users
                            // Show settings prompt card if HealthKit authorization was denied
                            if viewModel.healthKitAuthorizationDenied {
                                HealthKitSettingsPromptCard()
                            } else {
                                // HealthKit is free - show data without premium lock
                                HealthDataSection(
                                    steps: viewModel.steps,
                                    activeCalories: viewModel.activeCalories,
                                    exerciseMinutes: viewModel.exerciseMinutes,
                                    heartRate: viewModel.heartRate,
                                    distance: viewModel.distance,
                                    sleepHours: viewModel.sleepHours,
                                    isSubscribed: isSubscribed
                                )
                            }
                        }
                        .padding(12)
                    .onChange(of: scrollToTopTrigger) { _, _ in
                        // Scroll to top when Progress tab is re-tapped (trigger UUID changes)
                        // Provides smooth scrolling animation to the top of the view
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("progress-top", anchor: .top)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - View Modifiers (extracted to help compiler type-check)

/// Task-related modifiers - extracted to help compiler type-check
struct TaskModifiers: ViewModifier {
    weak var viewModel: ProgressViewModel?
    let isSubscribed: Bool
    @Binding var showWeightInput: Bool
    @Binding var showPaywall: Bool
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // Reload data when language changes to ensure all localized strings update
                Task { @MainActor in
                    await viewModel?.loadData()
                }
            }
            .task {
                // Load all progress data (weight history, calories, HealthKit data)
                await viewModel?.loadData()
                
                // Check if widget updated weight via shared UserDefaults
                // This handles weight updates made from the widget extension
                let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
                if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
                   sharedDefaults.bool(forKey: "widget.weightUpdatedFromWidget"),
                   let newWeight = sharedDefaults.object(forKey: "widget.pendingWeightUpdate") as? Double {
                    // Clear the flags to prevent duplicate processing
                    sharedDefaults.set(false, forKey: "widget.weightUpdatedFromWidget")
                    sharedDefaults.removeObject(forKey: "widget.pendingWeightUpdate")
                    
                    // Update weight if user is subscribed (weight tracking is premium)
                    if isSubscribed {
                        Task {
                            await viewModel?.updateWeight(newWeight)
                        }
                    }
                }
                
                // Check if widget requested weight input sheet to be shown
                // This handles taps on the widget that should open the weight input
                if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
                   sharedDefaults.bool(forKey: "openWeightInput") {
                    // Clear the flag to prevent duplicate triggers
                    sharedDefaults.set(false, forKey: "openWeightInput")
                    // Show weight input if subscribed, otherwise show paywall
                    if isSubscribed {
                        showWeightInput = true
                    } else {
                        showPaywall = true
                    }
                }
                
                // Show weight prompt immediately if user hasn't logged weight recently
                // This ensures new users are prompted to enter their weight
                if viewModel?.shouldPromptForWeight == true {
                    showWeightInput = true
                    viewModel?.markWeightPromptShown()
                }
            }
    }
}

/// Sheet-related modifiers - extracted to help compiler type-check
struct SheetModifiers: ViewModifier {
    @Bindable var viewModel: ProgressViewModel
    let settings: UserSettings
    @Binding var showWeightInput: Bool
    @Binding var showPaywall: Bool
    @Binding var showDeclineConfirmation: Bool
    let sdk: TheSDK
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showWeightInput) {
                WeightInputSheet(
                    currentWeight: settings.displayWeight,
                    unit: viewModel.weightUnit,
                    onSave: { weight in
                        Task {
                            await viewModel.updateWeight(weight)
                        }
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $viewModel.showWeightProgressSheet) {
                WeightProgressSheet(
                    weightHistory: viewModel.weightHistory,
                    selectedFilter: $viewModel.weightTimeFilter,
                    useMetricUnits: viewModel.useMetricUnits,
                    onFilterChange: {
                        Task {
                            await viewModel.onWeightFilterChange()
                        }
                    }
                )
            }
            .sheet(isPresented: $viewModel.showCaloriesSheet) {
                CaloriesDetailSheet(
                    dailyData: viewModel.dailyCaloriesData,
                    averageCalories: viewModel.averageCalories,
                    selectedFilter: $viewModel.caloriesTimeFilter,
                    onFilterChange: {
                        Task {
                            await viewModel.onCaloriesFilterChange()
                        }
                    }
                )
            }
            .fullScreenCover(isPresented: $showPaywall) {
                SDKView(
                    model: sdk,
                    page: .splash,
                    show: paywallBinding(showPaywall: $showPaywall, sdk: sdk, showDeclineConfirmation: $showDeclineConfirmation),
                    backgroundColor: .white,
                    ignoreSafeArea: true
                )
            }
    }
}

/// Notification-related modifiers - extracted to help compiler type-check
struct NotificationModifiers: ViewModifier {
    weak var viewModel: ProgressViewModel?
    let settings: UserSettings
    let isSubscribed: Bool
    @Binding var showWeightInput: Bool
    @Binding var showPaywall: Bool
    @Binding var showDeclineConfirmation: Bool
    let scrollToTopTrigger: UUID
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Re-check HealthKit authorization when app comes back from Settings app
                // This handles the case where user grants/denies HealthKit permission in Settings
                // The view automatically returns to the same state after checking
                Task { @MainActor in
                    guard let viewModel = viewModel else { return }
                    await viewModel.loadHealthKitData()
                    
                    // Check if widget updated weight while app was in background
                    // This ensures widget updates aren't missed when app was backgrounded
                    let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
                    if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
                       sharedDefaults.bool(forKey: "widget.weightUpdatedFromWidget"),
                       let newWeight = sharedDefaults.object(forKey: "widget.pendingWeightUpdate") as? Double {
                        // Clear the flags to prevent duplicate processing
                        sharedDefaults.set(false, forKey: "widget.weightUpdatedFromWidget")
                        sharedDefaults.removeObject(forKey: "widget.pendingWeightUpdate")
                        
                        // Update weight if subscribed (weight tracking is premium feature)
                        if isSubscribed {
                            await viewModel.updateWeight(newWeight)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .weightReminderAction)) { [isSubscribed] notification in
                // Show weight input sheet when weight reminder notification is tapped
                // This provides a quick way to log weight from the notification
                if isSubscribed {
                    showWeightInput = true
                } else {
                    showPaywall = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .widgetWeightUpdated)) { _ in
                // Handle weight update from widget (triggered when app becomes active)
                // This is handled in NotificationModifiers.willEnterForegroundNotification
                // which checks for widget weight updates and processes them
            }
            .onChange(of: settings.currentWeight) { [weak viewModel] oldValue, newValue in
                // Reload weight history when weight changes (e.g., from Profile/PersonalDetailsView)
                // This ensures all weight-related views update when weight is changed elsewhere in the app
                // Only reload if value actually changed (threshold: 0.01) to prevent unnecessary work
                guard abs(oldValue - newValue) > 0.01 else { return }
                Task { @MainActor in
                    await viewModel?.loadWeightHistory()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogged)) { [weak viewModel] _ in
                // Refresh hourly calories when a meal is saved/deleted
                // This ensures the trend chart updates immediately when meals change
                Task { @MainActor in
                    await viewModel?.loadHourlyCalories()
                }
            }
            .paywallDismissalOverlay(showPaywall: $showPaywall, showDeclineConfirmation: $showDeclineConfirmation)
    }
}

// MARK: - Current Weight Card

struct CurrentWeightCard: View {
    let weight: Double
    let unit: String
    let startWeight: Double
    let goalWeight: Double
    let daysUntilCheck: Int
    let isSubscribed: Bool
    let onWeightSave: (Double) -> Void
    let onShowPaywall: () -> Void
    let onViewProgress: () -> Void
    
    @State private var currentWeight: Double
    @State private var hasChanges: Bool = false
    
    private let minWeight: Double = 20.0
    private let maxWeight: Double = 300.0
    private let step: Double = 0.1
    
    private var titleText: String {
        LocalizationManager.shared.localizedString(for: AppStrings.Progress.currentWeight)
    }
    
    private var saveButtonText: String {
        LocalizationManager.shared.localizedString(for: AppStrings.Common.save)
    }
    
    private var startWeightText: String {
        String(format: LocalizationManager.shared.localizedString(for: AppStrings.Progress.startWeightWithUnit), startWeight, unit)
    }
    
    private var goalWeightText: String {
        String(format: LocalizationManager.shared.localizedString(for: AppStrings.Progress.goalWeightWithUnit), goalWeight, unit)
    }
    
    init(weight: Double, unit: String, startWeight: Double, goalWeight: Double, daysUntilCheck: Int, isSubscribed: Bool, onWeightSave: @escaping (Double) -> Void, onShowPaywall: @escaping () -> Void, onViewProgress: @escaping () -> Void) {
        self.weight = weight
        self.unit = unit
        self.startWeight = startWeight
        self.goalWeight = goalWeight
        self.daysUntilCheck = daysUntilCheck
        self.isSubscribed = isSubscribed
        self.onWeightSave = onWeightSave
        self.onShowPaywall = onShowPaywall
        self.onViewProgress = onViewProgress
        _currentWeight = State(initialValue: weight)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            
            HStack(spacing: 12) {
                Button {
                    adjustWeight(-step)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(isSubscribed ? .blue : .gray)
                }
                .disabled(!isSubscribed)
                .onTapGesture {
                    if !isSubscribed {
                        onShowPaywall()
                    }
                }
                
                Text(String(format: "%.1f %@", currentWeight, unit))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: currentWeight) { oldValue, newValue in
                    hasChanges = abs(newValue - weight) > 0.01
                }
                
                Button {
                    adjustWeight(step)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(isSubscribed ? .blue : .gray)
                }
                .disabled(!isSubscribed)
                .onTapGesture {
                    if !isSubscribed {
                        onShowPaywall()
                    }
                }
            }
            
            if hasChanges {
                Button {
                    saveWeight()
                } label: {
                    Text(saveButtonText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            HStack {
                Text(startWeightText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(goalWeightText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .onChange(of: weight) { oldValue, newValue in
            currentWeight = newValue
            hasChanges = false
        }
    }
    
    private func adjustWeight(_ delta: Double) {
        guard isSubscribed else {
            onShowPaywall()
            return
        }
        
        let newWeight = max(minWeight, min(maxWeight, currentWeight + delta))
        let roundedWeight = round(newWeight / step) * step
        currentWeight = roundedWeight
        hasChanges = abs(roundedWeight - weight) > 0.01
        
        HapticManager.shared.impact(.light)
    }
    
    private func saveWeight() {
        guard hasChanges else { return }
        let roundedWeight = round(currentWeight / step) * step
        hasChanges = false
        onWeightSave(roundedWeight)
        HapticManager.shared.notification(.success)
    }
}


// MARK: - BMI Card

struct BMICard: View {
    let bmi: Double
    let category: BMICategory
    let isSubscribed: Bool
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    init(bmi: Double, category: BMICategory, isSubscribed: Bool = true) {
        self.bmi = bmi
        self.category = category
        self.isSubscribed = isSubscribed
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.bodyMassIndex))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(String(format: "%.1f", bmi))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .foregroundColor(category.color)
                            
                            Text(category.rawValue)
                                .font(.headline)
                                .foregroundColor(category.color)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(category.color.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                
                Spacer()
            }
            
            // BMI Scale
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background gradient
                    LinearGradient(
                        colors: [.blue, .green, .yellow, .orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    // Indicator
                    let position = bmiPosition(in: geometry.size.width)
                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: position - 7)
                }
            }
            .frame(height: 12)
            
            // Scale labels
            HStack {
                Text("18.5")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("25")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("30")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("35+")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(category.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
    
    private func bmiPosition(in width: CGFloat) -> CGFloat {
        let minBMI: Double = 15
        let maxBMI: Double = 40
        let clampedBMI = min(max(bmi, minBMI), maxBMI)
        let percentage = (clampedBMI - minBMI) / (maxBMI - minBMI)
        return CGFloat(percentage) * width
    }
}

// MARK: - Daily Calories Card

struct DailyCaloriesCard: View {
    let averageCalories: Int
    let calorieGoal: Int
    let hourlyCalories: [HourlyCalorieData]
    let isSubscribed: Bool
    let onViewDetails: () -> Void
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    init(averageCalories: Int, calorieGoal: Int, hourlyCalories: [HourlyCalorieData] = [], isSubscribed: Bool = true, onViewDetails: @escaping () -> Void) {
        self.averageCalories = averageCalories
        self.calorieGoal = calorieGoal
        self.hourlyCalories = hourlyCalories
        self.isSubscribed = isSubscribed
        self.onViewDetails = onViewDetails
    }
    
    var progress: Double {
        guard calorieGoal > 0 else { return 0 }
        return Double(averageCalories) / Double(calorieGoal)
    }
    
    /// Maximum calories in any hour (for chart scaling)
    /// SwiftUI best practice: Computed property recalculates when hourlyCalories changes
    /// Returns 0 if no calories, 1 if all are zero (to prevent division by zero in chart)
    private var maxHourlyCalories: Int {
        let max = hourlyCalories.map { $0.calories }.max() ?? 0
        return max > 0 ? max : 1 // Return 1 if all zeros to allow chart rendering (though it will be hidden by condition)
    }
    
    /// Whether the chart should be displayed
    /// SwiftUI best practice: Extract complex conditions to computed properties for better readability
    private var shouldShowChart: Bool {
        !hourlyCalories.isEmpty && maxHourlyCalories > 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.dailyAverageCalories))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(averageCalories)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(localizationManager.localizedString(for: AppStrings.Progress.cal))
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Goal comparison
                VStack(alignment: .trailing, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.goalLabel))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(calorieGoal)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: min(CGFloat(progress) * geometry.size.width, geometry.size.width))
                }
            }
            .frame(height: 10)
            
            // Hourly trend chart (small)
            // SwiftUI best practice: Use computed property for conditional rendering
            if shouldShowChart {
                hourlyTrendChart
            }
            
            Button(action: onViewDetails) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                    Text(localizationManager.localizedString(for: AppStrings.Progress.viewDailyBreakdown))
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.orange)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Hourly Trend Chart
    
    private var hourlyTrendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizationManager.localizedString(for: AppStrings.Progress.todayTrend))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Chart {
                ForEach(hourlyCalories) { data in
                    BarMark(
                        x: .value("Hour", data.hour),
                        y: .value("Calories", data.calories)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange.opacity(0.7), .orange],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(2)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(localizationManager.localizedString(for: AppStrings.Progress.todayTrend))
            .accessibilityValue(accessibilityValue)
            .chartXAxis {
                AxisMarks(values: .stride(by: 3)) { value in
                    AxisGridLine()
                        .foregroundStyle(.gray.opacity(0.2))
                    AxisValueLabel {
                        if let hour = value.as(Int.self), hour >= 0, hour < 24 {
                            Text(hourlyCalories[hour].shortHourLabel)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                        .foregroundStyle(.gray.opacity(0.2))
                    AxisValueLabel {
                        if let calories = value.as(Int.self), calories > 0 {
                            Text("\(calories)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 80)
        }
    }
    
    // MARK: - Computed Properties (SwiftUI Best Practice)
    
    /// Accessibility value for VoiceOver users
    /// SwiftUI best practice: Use computed property instead of function for view data
    /// This ensures the value is recalculated when hourlyCalories changes
    private var accessibilityValue: String {
        let hoursWithData = hourlyCalories.filter { $0.calories > 0 }
        guard !hoursWithData.isEmpty else {
            return localizationManager.localizedString(for: AppStrings.Progress.noDataToday)
        }
        
        let totalCalories = hoursWithData.reduce(0) { $0 + $1.calories }
        let peakHour = hoursWithData.max(by: { $0.calories < $1.calories })
        
        var description = "Total: \(totalCalories) calories. "
        if let peak = peakHour {
            description += "Peak: \(peak.calories) calories at \(peak.hourLabel). "
        }
        description += "\(hoursWithData.count) hours with meals."
        
        return description
    }
}

// MARK: - Health Data Section

struct HealthDataSection: View {
    let steps: Int
    let activeCalories: Int
    let exerciseMinutes: Int
    let heartRate: Int
    let distance: Double
    let sleepHours: Double
    let isSubscribed: Bool
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    init(steps: Int, activeCalories: Int, exerciseMinutes: Int, heartRate: Int, distance: Double, sleepHours: Double, isSubscribed: Bool = true) {
        self.steps = steps
        self.activeCalories = activeCalories
        self.exerciseMinutes = exerciseMinutes
        self.heartRate = heartRate
        self.distance = distance
        self.sleepHours = sleepHours
        self.isSubscribed = isSubscribed
    }
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text(localizationManager.localizedString(for: AppStrings.Progress.healthData))
                    .font(.headline)
            }
            
            LazyVGrid(columns: columns, spacing: 12) {
                HealthMetricCard(
                    icon: "figure.walk",
                    title: localizationManager.localizedString(for: AppStrings.Progress.steps),
                    value: formatNumber(steps),
                    color: .green,
                    isSubscribed: isSubscribed
                )
                
                HealthMetricCard(
                    icon: "flame.fill",
                    title: localizationManager.localizedString(for: AppStrings.Progress.activeCalories),
                    value: "\(activeCalories)",
                    unit: localizationManager.localizedString(for: AppStrings.Progress.cal),
                    color: .orange,
                    isSubscribed: isSubscribed
                )
                
                HealthMetricCard(
                    icon: "figure.run",
                    title: localizationManager.localizedString(for: AppStrings.Progress.exercise),
                    value: "\(exerciseMinutes)",
                    unit: "min",
                    color: .blue,
                    isSubscribed: isSubscribed
                )
                
                HealthMetricCard(
                    icon: "heart.fill",
                    title: localizationManager.localizedString(for: AppStrings.Progress.heartRate),
                    value: "\(heartRate)",
                    unit: "bpm",
                    color: .red,
                    isSubscribed: isSubscribed
                )
                
                HealthMetricCard(
                    icon: "figure.walk.motion",
                    title: localizationManager.localizedString(for: AppStrings.Progress.distance),
                    value: String(format: "%.1f", distance),
                    unit: "km",
                    color: .purple,
                    isSubscribed: isSubscribed
                )
                
                HealthMetricCard(
                    icon: "moon.fill",
                    title: localizationManager.localizedString(for: AppStrings.Progress.sleep),
                    value: String(format: "%.1f", sleepHours),
                    unit: "hrs",
                    color: .indigo,
                    isSubscribed: isSubscribed
                )
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Health Metric Card

struct HealthMetricCard: View {
    let icon: String
    let title: String
    let value: String
    var unit: String? = nil
    let color: Color
    let isSubscribed: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if let unit = unit {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(height: 90)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
}

// MARK: - HealthKit Settings Prompt Card

struct HealthKitSettingsPromptCard: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private func openHealthKitSettings() {
        // Direct approach: Open Settings app to the app's settings page
        // User can then navigate to: Privacy & Security > Health > CalorieVisionAI
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            print("❌ [HealthKitSettingsPromptCard] Failed to create settings URL")
            return
        }
        
        print("🔵 [HealthKitSettingsPromptCard] Opening settings: \(settingsURL.absoluteString)")
        
        // Use the synchronous open method with completion handler for better reliability
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL) { success in
                if success {
                    print("✅ [HealthKitSettingsPromptCard] Successfully opened settings")
                } else {
                    print("❌ [HealthKitSettingsPromptCard] Failed to open settings")
                }
            }
        } else {
            print("❌ [HealthKitSettingsPromptCard] Cannot open settings URL")
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.2), .yellow.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.healthAccessRequired))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Progress.goToSettings))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                Spacer()
            }
            
            Button {
                openHealthKitSettings()
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.subheadline)
                    Text(localizationManager.localizedString(for: AppStrings.Progress.openSettings))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.orange, .yellow.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = ProgressViewModel(repository: repository)
    
    ProgressDashboardView(viewModel: viewModel)
}
