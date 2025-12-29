//
//  HealthKitCard.swift
//  playground
//
//  Card displaying HealthKit activity data
//

import SwiftUI

struct HealthKitCard: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var healthKitManager = HealthKitManager.shared
    @State private var isLoading = true
    @State private var animateRings = false
    
    private var showEnableInSettings: Bool {
        healthKitManager.authorizationDenied && !isLoading
    }
    
    private var showRequestPermission: Bool {
        !healthKitManager.isAuthorized && !healthKitManager.authorizationDenied && !isLoading
    }
    
    private var showActivityContent: Bool {
        healthKitManager.isHealthDataAvailable && !showEnableInSettings && !showRequestPermission && !isLoading
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !healthKitManager.isHealthDataAvailable {
                unavailableView
            } else if isLoading {
                loadingView
            } else if showEnableInSettings {
                enableInSettingsView
            } else if showRequestPermission {
                requestPermissionView
            } else {
                activityContentView
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .task {
            await loadHealthData()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Re-check authorization when app comes back from settings
            Task {
                isLoading = true
                await healthKitManager.refreshAuthorizationAndData()
                isLoading = false
                
                if healthKitManager.isAuthorized {
                    withAnimation(.easeOut(duration: 1.0)) {
                        animateRings = true
                    }
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    @ViewBuilder
    private var loadingView: some View {
        HStack(spacing: 20) {
            // Activity rings placeholder
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 12)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 12)
                    .frame(width: 72, height: 72)
                
                Circle()
                    .stroke(Color.cyan.opacity(0.2), lineWidth: 12)
                    .frame(width: 44, height: 44)
                
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            VStack(alignment: .leading, spacing: 14) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 28, height: 28)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 60, height: 14)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 40, height: 10)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Activity Content View
    
    @ViewBuilder
    private var activityContentView: some View {
        HStack(spacing: 20) {
            // Left side - Activity Rings
            activityRingsView
            
            // Right side - Stats
            activityStatsView
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animateRings = true
            }
        }
    }
    
    // MARK: - Activity Rings View
    
    @ViewBuilder
    private var activityRingsView: some View {
        ZStack {
            // Outer ring - Steps
            ActivityRing(
                progress: animateRings ? min(Double(healthKitManager.steps) / 10000, 1.0) : 0,
                ringColor: .green,
                lineWidth: 12
            )
            .frame(width: 100, height: 100)
            
            // Middle ring - Calories
            ActivityRing(
                progress: animateRings ? min(Double(healthKitManager.activeCalories) / 500, 1.0) : 0,
                ringColor: .orange,
                lineWidth: 12
            )
            .frame(width: 72, height: 72)
            
            // Inner ring - Exercise
            ActivityRing(
                progress: animateRings ? min(Double(healthKitManager.exerciseMinutes) / 30, 1.0) : 0,
                ringColor: .cyan,
                lineWidth: 12
            )
            .frame(width: 44, height: 44)
        }
    }
    
    // MARK: - Activity Stats View
    
    @ViewBuilder
    private var activityStatsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Steps
            ActivityStatRow(
                icon: "figure.walk",
                iconColor: .green,
                value: formatNumber(healthKitManager.steps),
                label: "Steps",
                goal: "10K"
            )
            
            // Active Calories
            ActivityStatRow(
                icon: "flame.fill",
                iconColor: .orange,
                value: "\(healthKitManager.activeCalories)",
                label: "Calories",
                goal: "500"
            )
            
            // Exercise Minutes
            ActivityStatRow(
                icon: "figure.run",
                iconColor: .cyan,
                value: "\(healthKitManager.exerciseMinutes)",
                label: "Exercise",
                goal: "30min"
            )
            
            // Distance
            ActivityStatRow(
                icon: "location.fill",
                iconColor: .pink,
                value: formatDistance(healthKitManager.distance),
                label: "Distance",
                goal: "5km"
            )
        }
    }
    
    // MARK: - Unavailable View
    
    @ViewBuilder
    private var unavailableView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "heart.slash.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(localizationManager.localizedString(for: AppStrings.Home.healthKitUnavailable))
                    .id("healthkit-unavailable-\(localizationManager.currentLanguage)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(localizationManager.localizedString(for: AppStrings.Home.healthDataNotAvailable))
                    .id("health-data-not-available-\(localizationManager.currentLanguage)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Request Permission View
    
    @ViewBuilder
    private var requestPermissionView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.red.opacity(0.2), .pink.opacity(0.2)],
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
                    Text(localizationManager.localizedString(for: AppStrings.Home.connectHealth))
                        .id("connect-health-\(localizationManager.currentLanguage)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Home.viewDailyActivity))
                        .id("view-daily-activity-\(localizationManager.currentLanguage)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            Button {
                Task {
                    // Request authorization - this shows the system Health permission dialog
                    await healthKitManager.requestAndVerifyAuthorization()
                    
                    // Trigger animation if authorized
                    if healthKitManager.isAuthorized {
                        withAnimation(.easeOut(duration: 1.0)) {
                            animateRings = true
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.subheadline)
                    Text(localizationManager.localizedString(for: AppStrings.Home.enableHealthAccess))
                        .id("enable-health-access-\(localizationManager.currentLanguage)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.red, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
    
    // MARK: - Enable In Settings View
    
    @ViewBuilder
    private var enableInSettingsView: some View {
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
                    
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Health Access Required")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Progress.goToSettings))
                        .id("go-to-settings-\(localizationManager.currentLanguage)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                Spacer()
            }
            
            Button {
                openHealthSettings()
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.subheadline)
                    Text(localizationManager.localizedString(for: AppStrings.Progress.openSettings))
                        .id("open-settings-\(localizationManager.currentLanguage)")
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
    }
    
    // MARK: - Actions
    
    private func openHealthSettings() {
        // Direct approach: Open Settings app to the app's settings page
        // User can then navigate to: Privacy & Security > Health > CalCalculator
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            print("❌ [HealthKitCard] Failed to create settings URL")
            return
        }
        
        print("🔵 [HealthKitCard] Opening settings: \(settingsURL.absoluteString)")
        
        // Use the synchronous open method with completion handler for better reliability
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL) { success in
                if success {
                    print("✅ [HealthKitCard] Successfully opened settings")
                } else {
                    print("❌ [HealthKitCard] Failed to open settings")
                }
            }
        } else {
            print("❌ [HealthKitCard] Cannot open settings URL")
        }
    }
    
    private func loadHealthData() async {
        isLoading = true
        animateRings = false
        
        // Check current status without requesting permission
        healthKitManager.checkCurrentAuthorizationStatus()
        
        // If already authorized, fetch data
        if healthKitManager.isAuthorized {
            await healthKitManager.fetchTodayData()
            
            withAnimation(.easeOut(duration: 1.0)) {
                animateRings = true
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Formatting
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            let formatted = Double(number) / 1000.0
            return String(format: "%.1fK", formatted)
        }
        return "\(number)"
    }
    
    private func formatDistance(_ km: Double) -> String {
        if km >= 1 {
            return String(format: "%.1f km", km)
        } else {
            let meters = Int(km * 1000)
            return "\(meters) m"
        }
    }
}

// MARK: - Activity Ring

private struct ActivityRing: View {
    let progress: Double
    let ringColor: Color
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: lineWidth)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            ringColor,
                            ringColor.opacity(0.8),
                            ringColor
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progress)
            
            // End cap glow effect
            if progress > 0.05 {
                Circle()
                    .fill(ringColor)
                    .frame(width: lineWidth, height: lineWidth)
                    .offset(y: -((100 - lineWidth) / 2) * (lineWidth == 12 ? 1 : (lineWidth == 12 ? 0.72 : 0.44)))
                    .rotationEffect(.degrees(360 * progress - 90))
                    .shadow(color: ringColor.opacity(0.5), radius: 4)
                    .opacity(progress > 0 ? 1 : 0)
                    .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progress)
            }
        }
    }
}

// MARK: - Activity Stat Row

private struct ActivityStatRow: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let goal: String
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon with colored background
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            // Value and label
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("/ \(goal)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Normal State") {
    VStack {
        HealthKitCard()
            .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("Dark Mode") {
    VStack {
        HealthKitCard()
            .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
    .preferredColorScheme(.dark)
}
