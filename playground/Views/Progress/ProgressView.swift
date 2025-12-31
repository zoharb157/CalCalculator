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
    
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var showWeightInput = false
    @State private var showPaywall = false
    @State private var showDeclineConfirmation = false
    
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
                            // Current Weight Card
                            CurrentWeightCard(
                                weight: viewModel.displayWeight,
                                unit: viewModel.weightUnit,
                                startWeight: viewModel.weightHistory.first?.weight ?? viewModel.displayWeight,
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
                            
                            // Weight Chart Card
                            WeightChartCard(
                                weightHistory: viewModel.weightHistory,
                                useMetricUnits: viewModel.useMetricUnits
                            )
                            
                            // Weight Changes Card
                            WeightChangesCard(
                                weightHistory: viewModel.weightHistory,
                                currentWeight: viewModel.displayWeight,
                                useMetricUnits: viewModel.useMetricUnits
                            )
                            
                            // Daily Average Calories Card - Locked with blur + Premium button (Progress page = reduced blur)
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
                            
                            // BMI Card - Locked with blur + Premium button (Progress page = reduced blur)
                            if let bmi = viewModel.bmi, let category = viewModel.bmiCategory {
                                PremiumLockedContent(isProgressPage: true) {
                                    BMICard(bmi: bmi, category: category, isSubscribed: true)
                                }
                            }
                            
                            // HealthKit Data Section - FREE (no premium lock)
                            // Show enable settings prompt if authorization denied
                            if viewModel.healthKitAuthorizationDenied {
                                HealthKitSettingsPromptCard()
                            } else {
                                // HealthKit is now free - show without premium lock
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
                        .padding()
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
                    currentWeight: viewModel.displayWeight,
                    unit: viewModel.weightUnit,
                    onSave: { weight in
                        Task {
                            await viewModel.updateWeight(weight)
                        }
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
                    show: Binding(
                        get: { showPaywall },
                        set: { newValue in
                            if !newValue && showPaywall {
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
                                    
                                    // Check SDK directly - show decline confirmation if not subscribed
                                    if !sdk.isSubscribed {
                                        showDeclineConfirmation = true
                                    } else {
                                        // User subscribed - reset analysis count
                                        AnalysisLimitManager.shared.resetAnalysisCount()
                                    }
                                }
                            }
                            showPaywall = newValue
                        }
                    ),
                    backgroundColor: .white,
                    ignoreSafeArea: true
                )
            }
            .overlay {
                // Show confirmation modal on top of everything - no padding/blur around it
                if showDeclineConfirmation {
                    PaywallDeclineConfirmationView(
                        isPresented: $showDeclineConfirmation,
                        showPaywall: $showPaywall
                    )
                    .zIndex(1000) // Ensure it's on top
                }
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
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var currentWeight: Double
    @State private var hasChanges: Bool = false
    
    // For scrollable picker
    private let minWeight: Double = 20.0
    private let maxWeight: Double = 300.0
    private let step: Double = 0.1
    
    private var weightValues: [Double] {
        stride(from: minWeight, through: maxWeight, by: step).map { $0 }
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
        VStack(alignment: .leading, spacing: 16) {
            Text(localizationManager.localizedString(for: AppStrings.Progress.currentWeight))
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Inline weight picker with +/- buttons
            HStack(spacing: 16) {
                // Minus button
                Button {
                    adjustWeight(-step)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isSubscribed ? .blue : .gray)
                }
                .disabled(!isSubscribed)
                .onTapGesture {
                    if !isSubscribed {
                        onShowPaywall()
                    }
                }
                
                // Inline weight display (no scroll)
                VStack(spacing: 4) {
                    // Weight above (smaller, lighter)
                    Text(String(format: "%.1f %@", max(minWeight, currentWeight - step), unit))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    // Current weight (large, bold, in a field)
                    Text(String(format: "%.1f %@", currentWeight, unit))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Weight below (smaller, lighter)
                    Text(String(format: "%.1f %@", min(maxWeight, currentWeight + step), unit))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .onChange(of: currentWeight) { oldValue, newValue in
                    // Update hasChanges when currentWeight changes
                    let difference = abs(newValue - weight)
                    hasChanges = difference > 0.01
                }
                
                // Plus button
                Button {
                    adjustWeight(step)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isSubscribed ? .blue : .gray)
                }
                .disabled(!isSubscribed)
                .onTapGesture {
                    if !isSubscribed {
                        onShowPaywall()
                    }
                }
            }
            
            // Save button (only shown when there are changes)
            if hasChanges {
                Button {
                    saveWeight()
                } label: {
                    Text(localizationManager.localizedString(for: AppStrings.Common.save))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Start and Goal weights
            HStack {
                Text(String(format: localizationManager.localizedString(for: AppStrings.Progress.startWeightWithUnit), startWeight, unit))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: localizationManager.localizedString(for: AppStrings.Progress.goalWeightWithUnit), goalWeight, unit))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .onChange(of: weight) { oldValue, newValue in
            // Update currentWeight when weight changes externally (after save)
            currentWeight = newValue
            // Reset hasChanges since weight is now synced
            hasChanges = false
        }
    }
    
    private func adjustWeight(_ delta: Double) {
        guard isSubscribed else {
            onShowPaywall()
            return
        }
        
        let newWeight = max(minWeight, min(maxWeight, currentWeight + delta))
        // Round to nearest step
        let roundedWeight = round(newWeight / step) * step
        currentWeight = roundedWeight
        // Update hasChanges
        hasChanges = abs(roundedWeight - weight) > 0.01
        
        HapticManager.shared.impact(.light)
    }
    
    private func saveWeight() {
        guard hasChanges else { return }
        // Round to nearest step before saving
        let roundedWeight = round(currentWeight / step) * step
        
        // Temporarily disable hasChanges to prevent double-save
        hasChanges = false
        
        // Call the save handler
        onWeightSave(roundedWeight)
        
        // Provide haptic feedback
        HapticManager.shared.notification(.success)
        
        // Note: hasChanges will be reset when weight prop updates via onChange
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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.bodyMassIndex))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(String(format: "%.1f", bmi))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
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
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.dailyAverageCalories))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(averageCalories)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
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
        .padding()
        .frame(height: 110)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

// MARK: - HealthKit Settings Prompt Card

struct HealthKitSettingsPromptCard: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private func openHealthKitSettings() {
        // Direct approach: Open Settings app to the app's settings page
        // User can then navigate to: Privacy & Security > Health > CalCalculator
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
        VStack(spacing: 16) {
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = ProgressViewModel(repository: repository)
    
    ProgressDashboardView(viewModel: viewModel)
}
