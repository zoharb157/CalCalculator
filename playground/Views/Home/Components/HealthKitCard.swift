//
//  HealthKitCard.swift
//  playground
//
//  Card displaying HealthKit activity data
//

import SwiftUI

struct HealthKitCard: View {
    // MARK: - Properties
    
    var selectedDate: Date = Date()
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var healthKitManager = HealthKitManager.shared
    @State private var isLoading = true
    @State private var animateRings = false
    @State private var showingPermissionSheet = false
    
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
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(spacing: 0) {
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
        .onChange(of: selectedDate) { _, newDate in
            Task {
                await loadHealthData(for: newDate, isInitialLoad: false)
            }
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
        .sheet(isPresented: $showingPermissionSheet) {
            HealthKitPermissionSheet(
                onSyncHealthData: {
                    // Dismiss the sheet first, then request permission after a small delay
                    // This ensures the sheet is fully dismissed before the system dialog appears
                    showingPermissionSheet = false
                    
                    Task {
                        // Small delay to ensure sheet dismissal animation completes
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                        
                        // Request authorization - this shows the system Health permission dialog
                        await healthKitManager.requestAndVerifyAuthorization()
                        
                        // Trigger animation if authorized
                        if healthKitManager.isAuthorized {
                            withAnimation(.easeOut(duration: 1.0)) {
                                animateRings = true
                            }
                        }
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
                label: localizationManager.localizedString(for: AppStrings.Progress.steps),
                goal: "10K"
            )
            
            // Active Calories
            ActivityStatRow(
                icon: "flame.fill",
                iconColor: .orange,
                value: "\(healthKitManager.activeCalories)",
                label: localizationManager.localizedString(for: AppStrings.Progress.activeCalories),
                goal: "500"
            )
            
            // Exercise Minutes
            ActivityStatRow(
                icon: "figure.run",
                iconColor: .cyan,
                value: "\(healthKitManager.exerciseMinutes)",
                label: localizationManager.localizedString(for: AppStrings.Progress.exercise),
                goal: "30min"
            )
            
            // Distance
            ActivityStatRow(
                icon: "location.fill",
                iconColor: .pink,
                value: formatDistance(healthKitManager.distance),
                label: localizationManager.localizedString(for: AppStrings.Progress.distance),
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
                    
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(localizationManager.localizedString(for: AppStrings.Home.healthDataNotAvailable))
                    
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
                        
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Home.viewDailyActivity))
                        
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            Button {
                // Show the pre-permission sheet explaining why we need HealthKit access
                showingPermissionSheet = true
            } label: {
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.subheadline)
                    Text(localizationManager.localizedString(for: AppStrings.Home.enableHealthAccess))
                        
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
                    Text(localizationManager.localizedString(for: AppStrings.Progress.healthAccessRequired))
                        
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Updated text to clarify Health app is needed
                    Text("Open Health app > Sharing > Apps to enable permissions")
                        
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
                    Image(systemName: "heart.fill")
                        .font(.subheadline)
                    Text("Open Health App")
                        
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
    
    // MARK: - Actions
    
    private func openHealthSettings() {
        // HealthKit permissions are managed in the Health app, NOT in the app's settings
        // We need to open the Health app directly using the x-apple-health URL scheme
        // Path: Health App > Sharing tab > Apps > CalorieVisionAI
        
        // Try to open Health app's sharing/sources section
        let healthAppURL = URL(string: "x-apple-health://")
        
        if let url = healthAppURL, UIApplication.shared.canOpenURL(url) {
            AppLogger.forClass("HealthKitCard").info("Opening Health app")
            UIApplication.shared.open(url) { success in
                if success {
                    AppLogger.forClass("HealthKitCard").success("Successfully opened Health app")
                } else {
                    AppLogger.forClass("HealthKitCard").error("Failed to open Health app")
                    // Fallback to app settings
                    self.openAppSettings()
                }
            }
        } else {
            // Fallback: Open app settings with instructions
            AppLogger.forClass("HealthKitCard").warning("Cannot open Health app URL, falling back to app settings")
            openAppSettings()
        }
    }
    
    private func openAppSettings() {
        // Fallback: Open the app's settings page
        // Note: HealthKit permissions won't be here, but we provide instructions
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            AppLogger.forClass("HealthKitCard").error("Failed to create settings URL")
            return
        }
        
        AppLogger.forClass("HealthKitCard").info("Opening app settings: \(settingsURL.absoluteString)")
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL) { success in
                if success {
                    AppLogger.forClass("HealthKitCard").success("Successfully opened app settings")
                } else {
                    AppLogger.forClass("HealthKitCard").error("Failed to open app settings")
                }
            }
        } else {
            AppLogger.forClass("HealthKitCard").error("Cannot open settings URL")
        }
    }
    
    private func loadHealthData(for date: Date? = nil, isInitialLoad: Bool = true) async {
        // Only show loading state on initial load, not on date changes
        if isInitialLoad {
            isLoading = true
            animateRings = false
        } else {
            // For date changes, smoothly animate rings to 0 first
            withAnimation(.easeOut(duration: 0.25)) {
                animateRings = false
            }
            // Small delay to let the "collapse" animation complete
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
        }
        
        // Check current status without requesting permission
        healthKitManager.checkCurrentAuthorizationStatus()
        
        // If already authorized, fetch data for the specified date
        if healthKitManager.isAuthorized {
            let targetDate = date ?? selectedDate
            await healthKitManager.fetchData(for: targetDate)
            
            withAnimation(.easeOut(duration: 0.8)) {
                animateRings = true
            }
        }
        
        if isInitialLoad {
            isLoading = false
        }
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
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
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
                
//                // End cap glow effect - positioned at the end of the progress arc
//                if progress > 0.05 {
//                    Circle()
//                        .fill(ringColor)
//                        .frame(width: lineWidth, height: lineWidth)
//                        .position(
//                            x: size / 2 + radius * cos(CGFloat(2 * .pi * progress - .pi / 2)),
//                            y: size / 2 + radius * sin(CGFloat(2 * .pi * progress - .pi / 2))
//                        )
//                        .shadow(color: ringColor.opacity(0.5), radius: 4)
//                        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progress)
//                }
            }
            .frame(width: size, height: size)
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
