//
//  HealthKitPermissionSheet.swift
//  playground
//
//  Pre-permission sheet explaining why HealthKit access is needed
//  Following Apple's Human Interface Guidelines for permission requests
//

import SwiftUI

/// A sheet view that explains why HealthKit access is beneficial before requesting permission
/// This follows Apple's guidelines:
/// - Explain the value before requesting permission
/// - Use neutral language on buttons ("Continue" or "Next", not "Enable" or "Allow")
/// - Give users the option to skip
struct HealthKitPermissionSheet: View {
    
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    /// Callback when user wants to sync health data
    var onSyncHealthData: () -> Void
    
    /// Callback when user skips
    var onSkip: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            dragIndicator
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Health icon with animation
                    healthIconSection
                    
                    // Title and description
                    titleSection
                    
                    // Benefits list
                    benefitsSection
                    
                    // Privacy note
                    privacyNote
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            
            // Action buttons
            actionButtons
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Drag Indicator
    
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color(.systemGray4))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
    
    // MARK: - Health Icon Section
    
    private var healthIconSection: some View {
        ZStack {
            // Outer glow rings
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.red.opacity(0.1), .pink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 160, height: 160)
            
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.red.opacity(0.15), .pink.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 130, height: 130)
            
            // Main icon container
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.23, blue: 0.19),
                            Color(red: 1.0, green: 0.35, blue: 0.37)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(color: .red.opacity(0.3), radius: 20, x: 0, y: 10)
            
            // Health heart icon
            Image(systemName: "heart.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("Sync with Apple Health")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("Get a complete picture of your daily activity by connecting to Apple Health")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }
    
    // MARK: - Benefits Section
    
    private var benefitsSection: some View {
        VStack(spacing: 16) {
            benefitRow(
                icon: "flame.fill",
                iconColor: .orange,
                title: "Track Burned Calories",
                description: "Automatically import your active calories from workouts and daily movement"
            )
            
            benefitRow(
                icon: "figure.walk",
                iconColor: .green,
                title: "Monitor Daily Steps",
                description: "See your step count and walking distance without manual entry"
            )
            
            benefitRow(
                icon: "figure.run",
                iconColor: .cyan,
                title: "Exercise Minutes",
                description: "Track your exercise time and workout sessions automatically"
            )
            
            benefitRow(
                icon: "scalemass.fill",
                iconColor: .purple,
                title: "Weight Sync",
                description: "Keep your weight data in sync across all your health apps"
            )
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Benefit Row
    
    private func benefitRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Privacy Note
    
    private var privacyNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            
            Text("Your health data stays private and secure. We only read the data you choose to share and never store it on external servers.")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineSpacing(2)
        }
        .padding(16)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary button - Sync Health Data
            Button {
                // Call the callback first - it will trigger the system permission dialog
                // The sheet will be dismissed by the parent view after the permission flow completes
                onSyncHealthData()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Sync Health Data")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.23, blue: 0.19),
                            Color(red: 1.0, green: 0.35, blue: 0.37)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            // Secondary button - Skip
            Button {
                dismiss()
                onSkip()
            } label: {
                Text("Skip for Now")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
        .background(
            Color(UIColor.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
}

// MARK: - Preview

#Preview {
    HealthKitPermissionSheet(
        onSyncHealthData: { print("Sync tapped") },
        onSkip: { print("Skip tapped") }
    )
}
