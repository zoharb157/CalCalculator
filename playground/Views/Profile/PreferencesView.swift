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
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    // MARK: - Body
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
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
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.preferences))
                .id("preferences-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                        dismiss()
                    }
                    .id("done-button-\(localizationManager.currentLanguage)")
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(viewModel.appearanceMode.colorScheme)
    }
    
    // MARK: - Appearance Section
    
    @ViewBuilder
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeader(title: localizationManager.localizedString(for: AppStrings.Profile.appearance))
                .id("appearance-header-\(localizationManager.currentLanguage)")
            
            VStack(spacing: 16) {
                Text(localizationManager.localizedString(for: AppStrings.Profile.choosePreferredAppearance))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .id("choose-appearance-\(localizationManager.currentLanguage)")
                
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
        VStack(alignment: .leading, spacing: 16) {
            ProfileSectionHeader(title: localizationManager.localizedString(for: AppStrings.Profile.calorieTracking))
                .id("calorie-tracking-header-\(localizationManager.currentLanguage)")
            
            ProfileSectionCard {
                ToggleSettingRow(
                    icon: "flame.fill",
                    iconColor: .orange,
                    title: localizationManager.localizedString(for: AppStrings.Profile.addBurnedCalories),
                    description: localizationManager.localizedString(for: AppStrings.Profile.addBurnedCaloriesDescription),
                    isOn: $viewModel.addBurnedCalories
                )
                .id("add-burned-calories-\(localizationManager.currentLanguage)")
                
                SettingsDivider()
                
                ToggleSettingRow(
                    icon: "arrow.clockwise",
                    iconColor: .green,
                    title: localizationManager.localizedString(for: AppStrings.Profile.rolloverCalories),
                    description: localizationManager.localizedString(for: AppStrings.Profile.rolloverCaloriesDescription),
                    isOn: $viewModel.rolloverCalories
                )
                .id("rollover-calories-\(localizationManager.currentLanguage)")
                
                SettingsDivider()
                
                ToggleSettingRow(
                    icon: "slider.horizontal.3",
                    iconColor: .blue,
                    title: localizationManager.localizedString(for: AppStrings.Profile.autoAdjustMacros),
                    description: localizationManager.localizedString(for: AppStrings.Profile.autoAdjustMacrosDescription),
                    isOn: $viewModel.autoAdjustMacros
                )
                .id("auto-adjust-macros-\(localizationManager.currentLanguage)")
            }
            
            // Weight Unit Section
            ProfileSectionHeader(title: localizationManager.localizedString(for: AppStrings.Profile.units))
                .id("units-header-\(localizationManager.currentLanguage)")
            
            ProfileSectionCard {
                WeightUnitToggleRow(
                    useMetricUnits: Binding(
                        get: { UserSettings.shared.useMetricUnits },
                        set: { UserSettings.shared.useMetricUnits = $0 }
                    )
                )
            }
        }
    }
    
    // MARK: - Notification Section
    
    @ViewBuilder
    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: localizationManager.localizedString(for: AppStrings.Profile.notificationsDisplay))
                .id("notifications-display-header-\(localizationManager.currentLanguage)")
            
            ProfileSectionCard {
                ToggleSettingRow(
                    icon: "sparkles",
                    iconColor: .purple,
                    title: localizationManager.localizedString(for: AppStrings.Profile.badgeCelebrations),
                    description: localizationManager.localizedString(for: AppStrings.Profile.badgeCelebrationsDescription),
                    isOn: $viewModel.badgeCelebrations
                )
                .id("badge-celebrations-\(localizationManager.currentLanguage)")
                
                SettingsDivider()
                
                ToggleSettingRow(
                    icon: "iphone.badge.play",
                    iconColor: .cyan,
                    title: localizationManager.localizedString(for: AppStrings.Profile.liveActivity),
                    description: localizationManager.localizedString(for: AppStrings.Profile.liveActivityDescription),
                    isOn: $viewModel.liveActivity
                )
                .id("live-activity-\(localizationManager.currentLanguage)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PreferencesView(viewModel: ProfileViewModel())
}
