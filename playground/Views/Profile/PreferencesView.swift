//
//  PreferencesView.swift
//  playground
//
//  Preferences screen with appearance and toggle settings
//

import SwiftUI

struct PreferencesView: View {
    
    // MARK: - Properties
    
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    appearanceSection
                    behaviorSection
                    notificationSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Appearance Section
    
    @ViewBuilder
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeader(title: "Appearance")
            
            VStack(spacing: 16) {
                Text("Choose your preferred appearance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                AppearanceModeSelector(selectedMode: $viewModel.appearanceMode)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Behavior Section
    
    @ViewBuilder
    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: "Calorie Tracking")
            
            ProfileSectionCard {
                ToggleSettingRow(
                    icon: "flame.fill",
                    iconColor: .orange,
                    title: "Add Burned Calories",
                    description: "Add calories burned from exercise back to your daily goal. Great for maintaining energy during active days.",
                    isOn: $viewModel.addBurnedCalories
                )
                
                SettingsDivider()
                
                ToggleSettingRow(
                    icon: "arrow.clockwise",
                    iconColor: .green,
                    title: "Rollover Calories",
                    description: "Carry up to 200 unused calories from yesterday into today's goal.",
                    isOn: $viewModel.rolloverCalories
                )
                
                SettingsDivider()
                
                ToggleSettingRow(
                    icon: "slider.horizontal.3",
                    iconColor: .blue,
                    title: "Auto-Adjust Macros",
                    description: "Automatically adjust protein, carbs, and fat when you change your calorie goal.",
                    isOn: $viewModel.autoAdjustMacros
                )
            }
        }
    }
    
    // MARK: - Notification Section
    
    @ViewBuilder
    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: "Notifications & Display")
            
            ProfileSectionCard {
                ToggleSettingRow(
                    icon: "sparkles",
                    iconColor: .purple,
                    title: "Badge Celebrations",
                    description: "Show a full-screen animation when you unlock a new achievement badge.",
                    isOn: $viewModel.badgeCelebrations
                )
                
                SettingsDivider()
                
                ToggleSettingRow(
                    icon: "iphone.badge.play",
                    iconColor: .cyan,
                    title: "Live Activity",
                    description: "Show your daily calories and macros on your Lock Screen and Dynamic Island.",
                    isOn: $viewModel.liveActivity
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PreferencesView(viewModel: ProfileViewModel())
}
