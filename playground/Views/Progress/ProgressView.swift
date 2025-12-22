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
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Current Weight Card
                        CurrentWeightCard(
                            weight: viewModel.displayWeight,
                            unit: viewModel.weightUnit,
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
                        
                        // BMI Card
                        if let bmi = viewModel.bmi, let category = viewModel.bmiCategory {
                            BMICard(bmi: bmi, category: category, isSubscribed: isSubscribed)
                        }
                        
                        // Daily Calories Card
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
                        
                        // HealthKit Data Section
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
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                
                if !isSubscribed {
                    LockedFeatureOverlay(message: "Upgrade to Premium to track your progress")
                }
            }
            .navigationTitle("Progress")
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                await viewModel.loadData()
            }
            .onAppear {
                if viewModel.shouldPromptForWeight {
                    showWeightInput = true
                    viewModel.markWeightPromptShown()
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
                    show: $showPaywall,
                    backgroundColor: .white,
                    ignoreSafeArea: true
                )
            }
        }
    }
}

// MARK: - Current Weight Card

struct CurrentWeightCard: View {
    let weight: Double
    let unit: String
    let daysUntilCheck: Int
    let isSubscribed: Bool
    let onWeightTap: () -> Void
    let onViewProgress: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Weight")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", weight))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(unit)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Next check countdown
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Next check in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("\(daysUntilCheck)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text("days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button(action: onWeightTap) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Log Weight")
                        if !isSubscribed {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .opacity(isSubscribed ? 1.0 : 0.6)
                }
                
                Button(action: onViewProgress) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("Progress")
                        if !isSubscribed {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .opacity(isSubscribed ? 1.0 : 0.6)
                }
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
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Body Mass Index")
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
    
    var progress: Double {
        guard calorieGoal > 0 else { return 0 }
        return Double(averageCalories) / Double(calorieGoal)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Average")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(averageCalories)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("cal")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Goal comparison
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Goal")
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
                    Text("View Daily Breakdown")
                    if !isSubscribed {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                    }
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.orange)
            }
            .opacity(isSubscribed ? 1.0 : 0.6)
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
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Health Data")
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
        .overlay(alignment: .topTrailing) {
            if !isSubscribed {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(4)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Circle())
                    .padding(8)
            }
        }
        .opacity(isSubscribed ? 1.0 : 0.6)
    }
}

// MARK: - Preview

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = ProgressViewModel(repository: repository)
    
    ProgressDashboardView(viewModel: viewModel)
}
