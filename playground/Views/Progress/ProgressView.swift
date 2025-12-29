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
    
    @State private var showWeightInput = false
    @State private var showPaywall = false
    @State private var showDeclineConfirmation = false
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.weightHistory.isEmpty {
                    FullScreenLoadingView(message: "Loading progress data...")
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
                                onWeightTap: {
                                    if isSubscribed {
                                        showWeightInput = true
                                    } else {
                                        showPaywall = true
                                    }
                                },
                                onViewProgress: {
                                    if isSubscribed {
                                        viewModel.showWeightProgressSheet = true
                                    } else {
                                        showPaywall = true
                                    }
                                }
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
                .id("progress-title-\(LocalizationManager.shared.currentLanguage)")
            .refreshable {
                await viewModel.loadData()
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
    let onWeightTap: () -> Void
    let onViewProgress: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizationManager.shared.localizedString(for: AppStrings.Progress.currentWeight))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .id("current-weight-\(LocalizationManager.shared.currentLanguage)")
            
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.0f", weight))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(unit)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Save weight button on the right
                Button(action: onWeightTap) {
                    HStack(spacing: 4) {
                        Text(LocalizationManager.shared.localizedString(for: "Save weight"))
                            .id("save-weight-\(LocalizationManager.shared.currentLanguage)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // Start and Goal weights
            HStack {
                Text("\(LocalizationManager.shared.localizedString(for: "Start")): \(String(format: "%.1f", startWeight)) \(unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .id("start-weight-\(LocalizationManager.shared.currentLanguage)")
                
                Spacer()
                
                Text("\(LocalizationManager.shared.localizedString(for: "Goal")): \(String(format: "%.1f", goalWeight)) \(unit)")
                    .id("goal-weight-\(LocalizationManager.shared.currentLanguage)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - BMI Card

struct BMICard: View {
    let bmi: Double
    let category: BMICategory
    let isSubscribed: Bool
    
    init(bmi: Double, category: BMICategory, isSubscribed: Bool = true) {
        self.bmi = bmi
        self.category = category
        self.isSubscribed = isSubscribed
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizationManager.shared.localizedString(for: "Body Mass Index"))
                        .id("bmi-title-\(LocalizationManager.shared.currentLanguage)")
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
                    Text(LocalizationManager.shared.localizedString(for: AppStrings.Progress.dailyAverageCalories))
                        .id("daily-avg-calories-\(LocalizationManager.shared.currentLanguage)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(averageCalories)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(LocalizationManager.shared.localizedString(for: "cal"))
                            .id("cal-unit-\(LocalizationManager.shared.currentLanguage)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Goal comparison
                VStack(alignment: .trailing, spacing: 4) {
                    Text(LocalizationManager.shared.localizedString(for: "Goal"))
                        .id("goal-label-\(LocalizationManager.shared.currentLanguage)")
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
                    Text(LocalizationManager.shared.localizedString(for: "View Daily Breakdown"))
                        .id("view-daily-breakdown-\(LocalizationManager.shared.currentLanguage)")
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
                Text(LocalizationManager.shared.localizedString(for: "Health Data"))
                    .id("health-data-\(LocalizationManager.shared.currentLanguage)")
                    .font(.headline)
            }
            
            LazyVGrid(columns: columns, spacing: 12) {
                HealthMetricCard(
                    icon: "figure.walk",
                    title: "Steps",
                    value: formatNumber(steps),
                    color: .green,
                    isSubscribed: isSubscribed
                )
                
                HealthMetricCard(
                    icon: "flame.fill",
                    title: "Active Calories",
                    value: "\(activeCalories)",
                    unit: "cal",
                    color: .orange,
                    isSubscribed: isSubscribed
                )
                
                HealthMetricCard(
                    icon: "figure.run",
                    title: "Exercise",
                    value: "\(exerciseMinutes)",
                    unit: "min",
                    color: .blue,
                    isSubscribed: isSubscribed
                )
                
                HealthMetricCard(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    value: "\(heartRate)",
                    unit: "bpm",
                    color: .red,
                    isSubscribed: isSubscribed
                )
                
                HealthMetricCard(
                    icon: "figure.walk.motion",
                    title: "Distance",
                    value: String(format: "%.1f", distance),
                    unit: "km",
                    color: .purple,
                    isSubscribed: isSubscribed
                )
                
                HealthMetricCard(
                    icon: "moon.fill",
                    title: "Sleep",
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
                    Text(LocalizationManager.shared.localizedString(for: "Health Access Required"))
                        .font(.headline)
                        .foregroundColor(.primary)
                        .id("health-access-required-\(LocalizationManager.shared.currentLanguage)")
                    
                    Text(LocalizationManager.shared.localizedString(for: "Go to Settings > Privacy & Security > Health > CalCalculator"))
                        .id("go-to-settings-\(LocalizationManager.shared.currentLanguage)")
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
                    Text(LocalizationManager.shared.localizedString(for: "Open Settings"))
                        .id("open-settings-\(LocalizationManager.shared.currentLanguage)")
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
