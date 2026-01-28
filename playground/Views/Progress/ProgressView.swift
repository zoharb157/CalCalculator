//
//  ProgressView.swift
//  playground
//
//  Progress tracking dashboard with weight, BMI, calories, and HealthKit integration
//

import SwiftUI
import Charts
// import SDK  // Commented out - using native StoreKit 2 paywall

struct ProgressDashboardView: View {
    // CRITICAL: We need @Bindable for bindings ($viewModel.showWeightProgressSheet, etc.)
    // But we'll prevent unnecessary updates by using stable IDs and not observing UserSettings directly
    @Bindable var viewModel: ProgressViewModel
    
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(\.modelContext) private var modelContext
    // @Environment(TheSDK.self) private var sdk  // Commented out - using native StoreKit 2 paywall
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    // CRITICAL: Don't observe UserSettings directly - access it directly instead
    // This prevents ProgressView from updating when UserSettings changes,
    // which would cause MainTabView to update and reset the tab selection
    // Access UserSettings.shared directly in the view body instead
    
    @State private var showWeightInput = false
    @State private var showPaywall = false
    @State private var showDeclineConfirmation = false
    @State private var showHealthKitPermissionSheet = false
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.weightHistory.isEmpty {
                    FullScreenLoadingView(message: localizationManager.localizedString(for: AppStrings.Progress.loadingProgressData))
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // MARK: - Weight Section
                            VStack(spacing: 16) {
                                // Current Weight Card
                                CurrentWeightCard(
                                    weight: UserSettings.shared.displayWeight,
                                    unit: viewModel.weightUnit,
                                    // Use first weight entry if available, otherwise use current weight as start weight
                                    // This ensures we always have a valid start weight for progress calculation
                                    // Note: currentWeight is already in kg, so we convert to display units if needed
                                    startWeight: viewModel.weightHistory.first?.weight ?? (viewModel.useMetricUnits ? UserSettings.shared.currentWeight : UserSettings.shared.currentWeight * 2.20462),
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
                                .id("current-weight-\(UserSettings.shared.displayWeight)-\(viewModel.weightHistory.count)")
                                
                                // Weight Chart Card
                                // Use hash of all weight values to ensure chart updates when any weight changes
                                WeightChartCard(
                                    weightHistory: viewModel.weightHistory,
                                    useMetricUnits: viewModel.useMetricUnits
                                )
                                .id("weight-chart-\(viewModel.weightHistory.map { "\($0.weight)-\($0.date.timeIntervalSince1970)" }.joined(separator: ","))")
                                
                                // Weight Changes Chart Card
                                WeightChangesChartCard(
                                    weightHistory: viewModel.weightHistory,
                                    currentWeight: viewModel.mostRecentWeight,
                                    useMetricUnits: viewModel.useMetricUnits
                                )
                                .id("weight-changes-\(viewModel.weightHistory.map { "\($0.weight)-\($0.date.timeIntervalSince1970)" }.joined(separator: ","))-\(viewModel.mostRecentWeight)")
                            }
                            
                            // MARK: - Nutrition Section
                            VStack(spacing: 16) {
                                // Daily Average Calories Card - Locked with blur + Premium button
                                PremiumLockedContent(isProgressPage: true) {
                                    DailyCaloriesCard(
                                        averageCalories: viewModel.averageCalories,
                                        calorieGoal: UserSettings.shared.calorieGoal,
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
                                
                                // BMI Card
                                if let bmi = viewModel.bmi, let category = viewModel.bmiCategory {
                                    PremiumLockedContent(isProgressPage: true) {
                                        BMICard(bmi: bmi, category: category, isSubscribed: true)
                                    }
                                }
                            }
                            
                            // MARK: - Health Section
                            VStack(spacing: 16) {
                                if viewModel.healthKitAuthorizationDenied {
                                    HealthKitSettingsPromptCard()
                                } else if viewModel.healthKitAuthorizationNotRequested {
                                    HealthKitRequestPermissionCard(
                                        onRequestPermission: {
                                            showHealthKitPermissionSheet = true
                                        }
                                    )
                                } else {
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
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(LocalizationManager.shared.localizedString(for: AppStrings.Progress.title))
            .refreshable {
                await viewModel.loadData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // Reload data when language changes to ensure all localized strings update
                Task {
                    await viewModel.loadData()
                }
            }
            .task {
                // Set modelContext first to ensure SwiftData operations work
                viewModel.setModelContext(modelContext)
                await viewModel.loadData()
                
                // Check if widget updated weight
                let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
                if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
                   sharedDefaults.bool(forKey: "widget.weightUpdatedFromWidget"),
                   let newWeight = sharedDefaults.object(forKey: "widget.pendingWeightUpdate") as? Double {
                    // Clear the flags
                    sharedDefaults.set(false, forKey: "widget.weightUpdatedFromWidget")
                    sharedDefaults.removeObject(forKey: "widget.pendingWeightUpdate")
                    
                    // Update weight if subscribed
                    if isSubscribed {
                        Task {
                            await viewModel.updateWeight(newWeight)
                        }
                    }
                }
                
                // Check if widget requested weight input
                if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
                   sharedDefaults.bool(forKey: "openWeightInput") {
                    // Clear the flag
                    sharedDefaults.set(false, forKey: "openWeightInput")
                    // Show weight input if subscribed
                    if isSubscribed {
                        showWeightInput = true
                    } else {
                        showPaywall = true
                    }
                }
                
                // Show weight prompt immediately if needed
                if viewModel.shouldPromptForWeight {
                    showWeightInput = true
                    viewModel.markWeightPromptShown()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Re-check HealthKit authorization when app comes back from settings
                // This automatically returns to the same view state
                Task {
                    await viewModel.loadHealthKitData()
                    
                    // Check if widget updated weight while app was in background
                    let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
                    if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
                       sharedDefaults.bool(forKey: "widget.weightUpdatedFromWidget"),
                       let newWeight = sharedDefaults.object(forKey: "widget.pendingWeightUpdate") as? Double {
                        // Clear the flags
                        sharedDefaults.set(false, forKey: "widget.weightUpdatedFromWidget")
                        sharedDefaults.removeObject(forKey: "widget.pendingWeightUpdate")
                        
                        // Update weight if subscribed
                        if isSubscribed {
                            await viewModel.updateWeight(newWeight)
                        }
                    }
                }
            }
            .sheet(isPresented: $showWeightInput) {
                WeightInputSheet(
                    currentWeight: UserSettings.shared.displayWeight,
                    unit: viewModel.weightUnit,
                    onSave: { weight in
                        // Save weight - MainTabView uses @AppStorage for selectedTabRaw
                        // so it won't reset even if MainTabView updates
                        await viewModel.updateWeight(weight)
                    }
                )
                .presentationDetents([.medium])
            }
            .onReceive(NotificationCenter.default.publisher(for: .weightReminderAction)) { notification in
                // Show weight input when notification is tapped
                if isSubscribed {
                    showWeightInput = true
                } else {
                    showPaywall = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .widgetWeightUpdated)) { _ in
                // Handle weight update from widget (notification from app become active)
                checkWidgetUpdates()
            }
            // CRITICAL: Removed onChange(of: UserSettings.shared.currentWeight) to prevent view updates
            // when weight changes. ProgressViewModel.updateWeight() already calls loadWeightHistory(),
            // so this onChange was causing unnecessary view updates that triggered MainTabView to reset.
            // If weight is changed from Profile/PersonalDetailsView, that view should handle the update.
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
                // Native StoreKit 2 paywall - replacing SDK paywall
                NativePaywallView { subscribed in
                    showPaywall = false
                    if subscribed {
                        // User subscribed - reset limits
                        AnalysisLimitManager.shared.resetAnalysisCount()
                        MealSaveLimitManager.shared.resetMealSaveCount()
                        ExerciseSaveLimitManager.shared.resetExerciseSaveCount()
                        NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
                    } else {
                        showDeclineConfirmation = true
                    }
                }
            }
            .paywallDismissalOverlay(showPaywall: $showPaywall, showDeclineConfirmation: $showDeclineConfirmation)
            .sheet(isPresented: $showHealthKitPermissionSheet) {
                HealthKitPermissionSheet(
                    onSyncHealthData: {
                        // Dismiss the sheet first, then request permission after a small delay
                        // This ensures the sheet is fully dismissed before the system dialog appears
                        showHealthKitPermissionSheet = false
                        
                        Task {
                            // Small delay to ensure sheet dismissal animation completes
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                            
                            // Request authorization - this shows the system Health permission dialog
                            await HealthKitManager.shared.requestAndVerifyAuthorization()
                            
                            // Reload HealthKit data to update the view
                            await viewModel.loadHealthKitData()
                        }
                    },
                    onSkip: {
                        // User chose to skip - do nothing, they can enable later
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check for widget weight updates and weight input requests
    private func checkWidgetUpdates() {
        let appGroupIdentifier = "group.CalCalculatorAiPlaygournd.shared"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        
        // Check if widget updated weight
        if sharedDefaults.bool(forKey: "widget.weightUpdatedFromWidget"),
           let newWeight = sharedDefaults.object(forKey: "widget.pendingWeightUpdate") as? Double {
            // Clear the flags
            sharedDefaults.set(false, forKey: "widget.weightUpdatedFromWidget")
            sharedDefaults.removeObject(forKey: "widget.pendingWeightUpdate")
            
            // Update weight if subscribed
            if isSubscribed {
                Task {
                    await viewModel.updateWeight(newWeight)
                }
            }
        }
        
        // Check if widget requested weight input
        if sharedDefaults.bool(forKey: "openWeightInput") {
            // Clear the flag
            sharedDefaults.set(false, forKey: "openWeightInput")
            // Show weight input if subscribed
            if isSubscribed {
                showWeightInput = true
            } else {
                showPaywall = true
            }
        }
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
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private let minWeight: Double = 20.0
    private let maxWeight: Double = 300.0
    private let step: Double = 0.1
    
    private var titleText: String {
        localizationManager.localizedString(for: AppStrings.Progress.currentWeight)
    }
    
    private var saveButtonText: String {
        localizationManager.localizedString(for: AppStrings.Common.save)
    }
    
    private var startWeightText: String {
        String(format: localizationManager.localizedString(for: AppStrings.Progress.startWeightWithUnit), startWeight, unit)
    }
    
    private var goalWeightText: String {
        String(format: localizationManager.localizedString(for: AppStrings.Progress.goalWeightWithUnit), goalWeight, unit)
    }
    
    // Calculate progress towards goal
    private var progressToGoal: Double {
        guard abs(startWeight - goalWeight) > 0.01 else { return 1.0 }
        let totalChange = abs(startWeight - goalWeight)
        let currentChange = abs(startWeight - currentWeight)
        return min(1.0, max(0, currentChange / totalChange))
    }
    
    // Is the user making progress in the right direction?
    private var isProgressPositive: Bool {
        if goalWeight < startWeight {
            // Trying to lose weight
            return currentWeight <= startWeight
        } else {
            // Trying to gain weight
            return currentWeight >= startWeight
        }
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
        VStack(spacing: 0) {
            // Header with gradient accent
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", currentWeight))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        
                        Text(unit)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Weight adjustment controls
                VStack(spacing: 8) {
                    Button {
                        adjustWeight(step)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(isSubscribed ? Color.blue : Color.gray.opacity(0.5))
                            )
                    }
                    .disabled(!isSubscribed)
                    .simultaneousGesture(TapGesture().onEnded {
                        if !isSubscribed { onShowPaywall() }
                    })
                    
                    Button {
                        adjustWeight(-step)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isSubscribed ? .blue : .gray)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .stroke(isSubscribed ? Color.blue : Color.gray.opacity(0.5), lineWidth: 2)
                            )
                    }
                    .disabled(!isSubscribed)
                    .simultaneousGesture(TapGesture().onEnded {
                        if !isSubscribed { onShowPaywall() }
                    })
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Progress bar section
            VStack(spacing: 10) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                        
                        // Progress fill
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: isProgressPositive ? [.blue, .cyan] : [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: CGFloat(progressToGoal) * geometry.size.width)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progressToGoal)
                    }
                }
                .frame(height: 8)
                
                // Start and goal labels
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizationManager.localizedString(for: AppStrings.Progress.start))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f %@", startWeight, unit))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(localizationManager.localizedString(for: AppStrings.Progress.goalLabel))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f %@", goalWeight, unit))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Save button (appears when changes made)
            if hasChanges {
                Button {
                    saveWeight()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                        Text(saveButtonText)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasChanges)
        .onChange(of: currentWeight) { oldValue, newValue in
            hasChanges = abs(newValue - weight) > 0.01
        }
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
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            currentWeight = roundedWeight
        }
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
        VStack(spacing: 16) {
            // Header section
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.bodyMassIndex))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(String(format: "%.1f", bmi))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.subheadline)
                                .foregroundColor(category.color)
                            
                            Text(category.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(category.color)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(category.color.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                
                Spacer()
            }
            
            // BMI Scale
            VStack(spacing: 8) {
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
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
                            .offset(x: position - 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: bmi)
                    }
                }
                .frame(height: 10)
                
                // Scale labels
                HStack {
                    Text("18.5")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("25")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("30")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("35+")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            
            // Description
            Text(category.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
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
    let isSubscribed: Bool
    let onViewDetails: () -> Void
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    init(averageCalories: Int, calorieGoal: Int, isSubscribed: Bool = true, onViewDetails: @escaping () -> Void) {
        self.averageCalories = averageCalories
        self.calorieGoal = calorieGoal
        self.isSubscribed = isSubscribed
        self.onViewDetails = onViewDetails
    }
    
    var progress: Double {
        guard calorieGoal > 0 else { return 0 }
        return Double(averageCalories) / Double(calorieGoal)
    }
    
    private var progressColor: Color {
        if progress < 0.8 {
            return .green
        } else if progress < 1.0 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header section
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.dailyAverageCalories))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(averageCalories)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        
                        Text(localizationManager.localizedString(for: AppStrings.Progress.cal))
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Goal badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.goalLabel))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("\(calorieGoal)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Progress bar
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, progressColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: min(CGFloat(progress) * geometry.size.width, geometry.size.width))
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progress)
                    }
                }
                .frame(height: 10)
                
                // Progress percentage
                HStack {
                    Text("\(Int(progress * 100))% of daily goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            // View details button
            Button(action: onViewDetails) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.subheadline)
                    Text(localizationManager.localizedString(for: AppStrings.Progress.viewDailyBreakdown))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.orange, .orange.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
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
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
                
                Text(localizationManager.localizedString(for: AppStrings.Progress.healthData))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Metrics grid
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
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
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
        VStack(alignment: .leading, spacing: 0) {
            // Icon with colored background
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    
                    if let unit = unit {
                        Text(unit)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(height: 100)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - HealthKit Settings Prompt Card

struct HealthKitSettingsPromptCard: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private func openHealthKitSettings() {
        // Direct approach: Open Settings app to the app's settings page
        // User can then navigate to: Privacy & Security > Health > CalCalculator
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            AppLogger.forClass("ProgressView").error("Failed to create settings URL")
            return
        }
        
        // Use the synchronous open method with completion handler for better reliability
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL) { success in
                if !success {
                    AppLogger.forClass("ProgressView").error("Failed to open settings")
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.red.opacity(0.15), .pink.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
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
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.healthAccessRequired))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Progress.goToSettings))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                Spacer()
            }
            
            Button {
                openHealthKitSettings()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.subheadline)
                    Text(localizationManager.localizedString(for: AppStrings.Progress.openSettings))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.red, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - HealthKit Request Permission Card

/// Card shown when HealthKit authorization has not been requested yet
/// Prompts the user to connect Apple Health with an explanation of benefits
struct HealthKitRequestPermissionCard: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    /// Callback when user taps the button to request permission
    var onRequestPermission: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.red.opacity(0.15), .pink.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
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
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(localizationManager.localizedString(for: AppStrings.Home.connectHealth))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Home.viewDailyActivity))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                Spacer()
            }
            
            Button {
                onRequestPermission()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.subheadline)
                    Text(localizationManager.localizedString(for: AppStrings.Home.enableHealthAccess))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.red, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = ProgressViewModel(repository: repository)
    
    ProgressDashboardView(viewModel: viewModel)
}
