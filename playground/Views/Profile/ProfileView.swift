//
//  ProfileView.swift
//  playground
//
//  Main Profile screen with settings and user information
//

import SwiftUI
import SDK

struct ProfileView: View {
    
    // MARK: - State
    
    @State private var viewModel = ProfileViewModel()
    @Environment(TheSDK.self) private var sdk
    @Environment(\.localization) private var localization
    private var settings = UserSettings.shared
    
    // Sheet presentation states
    @State private var showingPersonalDetails = false
    @State private var showingPreferences = false
    @State private var showingLanguageSelection = false
    @State private var showingEditNutritionGoals = false
    @State private var showingWeightHistory = false
    @State private var showingRingColorsExplained = false
    @State private var showingSupportEmail = false
    @State private var showingDataExport = false
    @State private var showingReferralCode = false
    @State private var showingBadges = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileInfoSection
                    accountSection
                    goalsTrackingSection
                    preferencesSection
                    supportSection
                    if isDebugOrTestFlight {
                        debugSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(localization.localizedString(for: "Profile"))
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingPersonalDetails) {
            PersonalDetailsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingPreferences) {
            PreferencesView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingEditNutritionGoals) {
            EditNutritionGoalsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingWeightHistory) {
            WeightHistoryView()
        }
        .sheet(isPresented: $showingRingColorsExplained) {
            RingColorsExplainedView()
        }
        .sheet(isPresented: $showingSupportEmail) {
            SupportEmailView()
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView()
        }
        .sheet(isPresented: $showingReferralCode) {
            ReferralCodeView()
        }
        .sheet(isPresented: $showingBadges) {
            BadgesView()
        }
    }
    
    // MARK: - Profile Info Section
    
    @ViewBuilder
    private var profileInfoSection: some View {
        ProfileInfoCard(
            fullName: viewModel.fullName,
            username: viewModel.username,
            onTap: { showingPersonalDetails = true }
        )
    }
    
    // MARK: - Account Section
    
    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: "Account")
            
            ProfileSectionCard {
                SettingsRow(
                    icon: "gearshape",
                    title: "Preferences",
                    subtitle: "Appearance, notifications & behavior",
                    action: { showingPreferences = true }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "globe",
                    title: "Language",
                    subtitle: viewModel.selectedLanguage,
                    action: { showingLanguageSelection = true }
                )
            }
        }
    }
    
    // MARK: - Goals & Tracking Section
    
    @ViewBuilder
    private var goalsTrackingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: "Goals & Tracking")
            
            ProfileSectionCard {
                SettingsRow(
                    icon: "target",
                    iconColor: .orange,
                    title: "Nutrition Goals",
                    subtitle: "\(viewModel.calorieGoal) cal | \(Int(viewModel.proteinGoal))g protein",
                    action: { showingEditNutritionGoals = true }
                )

                SettingsDivider()
                
                SettingsRow(
                    icon: "clock.arrow.circlepath",
                    iconColor: .purple,
                    title: "Weight History",
                    action: { showingWeightHistory = true }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "circle.inset.filled",
                    iconColor: .blue,
                    title: "Ring Colors Explained",
                    action: { showingRingColorsExplained = true }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "medal.fill",
                    iconColor: .yellow,
                    title: "My Badges",
                    subtitle: BadgeManager.shared.progressText,
                    action: { showingBadges = true }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "square.and.arrow.up",
                    iconColor: .green,
                    title: "Export Data",
                    subtitle: "Download your data as PDF",
                    action: { showingDataExport = true }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "gift.fill",
                    iconColor: .pink,
                    title: "Referral Code",
                    subtitle: "Share & earn rewards",
                    action: { showingReferralCode = true }
                )
            }
        }
    }
    
    // MARK: - Preferences Section
    
    @ViewBuilder
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: "Settings")
            
            ProfileSectionCard {
                SettingsRow(
                    icon: "gearshape.fill",
                    iconColor: .blue,
                    title: "Preferences",
                    subtitle: "Appearance, calorie tracking, and notifications",
                    action: { showingPreferences = true }
                )
            }
        }
    }
    
    // MARK: - Support Section
    
    @ViewBuilder
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: "Support")
            
            ProfileSectionCard {
                SettingsRow(
                    icon: "envelope",
                    iconColor: .blue,
                    title: "Contact Support",
                    action: { showingSupportEmail = true }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "doc.text",
                    iconColor: .gray,
                    title: "Terms of Service",
                    action: { openURL("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "hand.raised",
                    iconColor: .gray,
                    title: "Privacy Policy",
                    action: { openURL("https://www.apple.com/legal/privacy/") }
                )
            }
            
            // App Version
            HStack {
                Spacer()
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.top, 16)
        }
    }
    
    // MARK: - Debug Section
    
    /// Check if we're in DEBUG build or TestFlight
    private var isDebugOrTestFlight: Bool {
        #if DEBUG
        return true
        #else
        // Check if running in TestFlight (receipt URL contains sandboxReceipt)
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           receiptURL.path.contains("sandboxReceipt") {
            return true
        }
        return false
        #endif
    }
    
    @ViewBuilder
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: "Debug")
            
            ProfileSectionCard {
                ToggleSettingRow(
                    icon: "hammer.fill",
                    iconColor: .orange,
                    title: "Override Subscription",
                    description: "Manually control subscription status for testing",
                    isOn: Binding(
                        get: { settings.debugOverrideSubscription },
                        set: { settings.debugOverrideSubscription = $0 }
                    )
                )
                
                if settings.debugOverrideSubscription {
                    SettingsDivider()
                    
                    ToggleSettingRow(
                        icon: "checkmark.circle.fill",
                        iconColor: .green,
                        title: "Debug: Is Subscribed",
                        description: "Override subscription status",
                        isOn: Binding(
                            get: { settings.debugIsSubscribed },
                            set: { settings.debugIsSubscribed = $0 }
                        )
                    )
                    
                    SettingsDivider()
                    
                    HStack {
                        Text("Debug Status")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(settings.debugIsSubscribed ? "Premium" : "Free")
                            .font(.body)
                            .foregroundColor(settings.debugIsSubscribed ? .green : .gray)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    
                    SettingsDivider()
                    
                    HStack {
                        Text("SDK Status")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(sdk.isSubscribed ? "Premium" : "Free")
                            .font(.body)
                            .foregroundColor(sdk.isSubscribed ? .green : .gray)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
}
