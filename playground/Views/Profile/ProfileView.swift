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
    
    // Use @State with @Observable - SwiftUI will automatically track changes to viewModel properties
    @State private var viewModel = ProfileViewModel()
    @Environment(TheSDK.self) private var sdk
    @Environment(\.localization) private var localization
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    // Profile image state
    @State private var profileImage: UIImage?
    private let imageStorage = ImageStorage.shared
    
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
    @State private var showingRateUs = false
    @State private var showingSendFeedback = false
    @State private var showingHealthInfoSources = false
    @State private var showingSubscription = false
    @State private var showingDeveloperSettings = false
    @State private var versionTapCount = 0
    
    // Subscription status
    @Environment(\.isSubscribed) private var isSubscribed
    
    // MARK: - Body
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileInfoSection
                    accountSection
                    goalsTrackingSection
                    supportSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.title))
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Pixel.track("screen_profile", type: .navigation)
                profileImage = imageStorage.loadProfilePhoto()
            }
            .onChange(of: localizationManager.currentLanguage) { oldValue, newValue in
                // Force view refresh when language changes
                viewModel.loadProfileData()
            }
        }
        .sheet(isPresented: $showingPersonalDetails, onDismiss: {
            profileImage = imageStorage.loadProfilePhoto()
        }) {
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
        // Referral code screen commented out - no longer needed
        // .sheet(isPresented: $showingReferralCode) {
        //     ReferralCodeView()
        // }
        .sheet(isPresented: $showingBadges) {
            BadgesView()
        }
        .sheet(isPresented: $showingRateUs) {
            RateUsView()
        }
        .sheet(isPresented: $showingSendFeedback) {
            SendFeedbackView()
        }
        .sheet(isPresented: $showingHealthInfoSources) {
            HealthInfoSourcesView()
        }
        .fullScreenCover(isPresented: $showingSubscription) {
            PaywallContainerView(isPresented: $showingSubscription, sdk: sdk, source: "profile_view")
        }
        .sheet(isPresented: $showingDeveloperSettings) {
            DeveloperSettingsView()
        }
    }
    
    // MARK: - Profile Info Section
    
    @ViewBuilder
    private var profileInfoSection: some View {
        ProfileInfoCard(
            fullName: viewModel.fullName,
            username: viewModel.username,
            profileImage: profileImage,
            onTap: { showingPersonalDetails = true }
        )
    }
    
    // MARK: - Account Section
    
    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: localizationManager.localizedString(for: AppStrings.Profile.account))
            
            ProfileSectionCard {
                SettingsRow(
                    icon: "gearshape",
                    title: localizationManager.localizedString(for: AppStrings.Profile.preferences),
                    subtitle: localizationManager.localizedString(for: AppStrings.Profile.appearanceNotificationsBehavior),
                    action: {
                        Pixel.track("settings_preferences", type: .interaction)
                        showingPreferences = true
                    }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "globe",
                    title: localizationManager.localizedString(for: AppStrings.Profile.language),
                    subtitle: getLocalizedLanguageName(from: viewModel.selectedLanguage),
                    action: {
                        Pixel.track("settings_language", type: .interaction)
                        showingLanguageSelection = true
                    }
                )
                
                SettingsDivider()
                
                // Subscription management row - makes in-app purchases easy to find
                SettingsRow(
                    icon: "crown.fill",
                    iconColor: isSubscribed ? .yellow : .orange,
                    title: isSubscribed ? "Manage Subscription" : "Upgrade to Premium",
                    subtitle: isSubscribed ? "You have an active subscription" : "Unlock all premium features",
                    action: {
                        if isSubscribed {
                            Pixel.track("settings_manage_subscription", type: .interaction)
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        } else {
                            Pixel.track("premium_button_tapped", type: .transaction)
                            showingSubscription = true
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Goals & Tracking Section
    
    @ViewBuilder
    private var goalsTrackingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: localizationManager.localizedString(for: AppStrings.Profile.goalsTracking))
            
            ProfileSectionCard {
                // Custom Nutrition Goals row with status badge
                nutritionGoalsRow
 
                SettingsDivider()
                
                SettingsRow(
                    icon: "clock.arrow.circlepath",
                    iconColor: .purple,
                    title: localizationManager.localizedString(for: AppStrings.Profile.weightHistory),
                    action: {
                        Pixel.track("settings_weight_history", type: .interaction)
                        showingWeightHistory = true
                    }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "circle.inset.filled",
                    iconColor: .blue,
                    title: localizationManager.localizedString(for: AppStrings.Profile.ringColorsExplained),
                    action: {
                        Pixel.track("settings_ring_colors", type: .interaction)
                        showingRingColorsExplained = true
                    }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "medal.fill",
                    iconColor: .yellow,
                    title: localizationManager.localizedString(for: AppStrings.Profile.myBadges),
                    subtitle: BadgeManager.shared.progressText,
                    action: {
                        Pixel.track("settings_badges", type: .interaction)
                        showingBadges = true
                    }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "square.and.arrow.up",
                    iconColor: .green,
                    title: localizationManager.localizedString(for: AppStrings.Profile.exportData),
                    subtitle: localizationManager.localizedString(for: AppStrings.Profile.downloadDataAsPDF),
                    action: {
                        Pixel.track("settings_export_data", type: .interaction)
                        showingDataExport = true
                    }
                )
                
                // Referral code row commented out - no longer needed
                // SettingsDivider()
                // 
                // SettingsRow(
                //     icon: "gift.fill",
                //     iconColor: .pink,
                //     title: localizationManager.localizedString(for: AppStrings.Profile.referralCode),
                //     subtitle: localizationManager.localizedString(for: AppStrings.Profile.shareEarnRewards),
                //     action: { showingReferralCode = true }
                // )
            }
        }
    }
    
    // MARK: - Nutrition Goals Row (Custom)
    
    @ViewBuilder
    private var nutritionGoalsRow: some View {
        Button(action: {
            Pixel.track("settings_nutrition_goals", type: .interaction)
            showingEditNutritionGoals = true
        }) {
            HStack(spacing: 16) {
                Image(systemName: "target")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                    .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizationManager.localizedString(for: AppStrings.Profile.nutritionGoals))
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Profile.nutritionGoalsSummary, arguments: viewModel.calorieGoal, Int(viewModel.proteinGoal)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Support Section
    
    @ViewBuilder
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: localizationManager.localizedString(for: AppStrings.Profile.support))
            
            ProfileSectionCard {
                SettingsRow(
                    icon: "envelope",
                    iconColor: .blue,
                    title: localizationManager.localizedString(for: AppStrings.Profile.contactSupport),
                    action: {
                        Pixel.track("settings_mail_us_tapped", type: .interaction)
                        showingSupportEmail = true
                    }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "star.fill",
                    iconColor: .yellow,
                    title: localizationManager.localizedString(for: AppStrings.Profile.rateUs),
                    action: {
                        Pixel.track("settings_rate_us", type: .interaction)
                        showingRateUs = true
                    }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "paperplane.fill",
                    iconColor: .green,
                    title: localizationManager.localizedString(for: AppStrings.Profile.sendFeedback),
                    action: {
                        Pixel.track("settings_feedback_tapped", type: .interaction)
                        showingSendFeedback = true
                    }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "book.closed.fill",
                    iconColor: .purple,
                    title: "Health Information Sources",
                    action: {
                        Pixel.track("settings_health_sources", type: .interaction)
                        showingHealthInfoSources = true
                    }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "doc.text",
                    iconColor: .gray,
                    title: localizationManager.localizedString(for: AppStrings.Profile.termsOfService),
                    action: {
                        Pixel.track("settings_terms_tapped", type: .interaction)
                        openURL("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                    }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "hand.raised",
                    iconColor: .gray,
                    title: localizationManager.localizedString(for: AppStrings.Profile.privacyPolicy),
                    action: {
                        Pixel.track("settings_privacy_tapped", type: .interaction)
                        openURL("https://www.apple.com/legal/privacy/")
                    }
                )
            }
            
            // App Version
            Button {
                versionTapCount += 1
                if versionTapCount >= 10 {
                    showingDeveloperSettings = true
                    versionTapCount = 0
                }
            } label: {
                HStack {
                    Spacer()
                    if versionTapCount >= 5 {
                        Text("\(10 - versionTapCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    Text(localizationManager.localizedString(for: AppStrings.Profile.version))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if versionTapCount >= 5 {
                        Text("\(10 - versionTapCount)")
                            .font(.caption2)
                            .foregroundColor(.clear)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
        }
    }
    
    // MARK: - Helpers
    
    private func getLocalizedLanguageName(from languageName: String) -> String {
        // Get the language code from the language name
        let languageCode = LocalizationManager.languageCode(from: languageName)
        
        // Map language codes to localized names based on current app language
        let currentLanguage = localizationManager.currentLanguage
        let localizedNames: [String: [String: String]] = [
            "en": [
                "en": "English",
                "es": "Spanish",
                "fr": "French",
                "de": "German",
                "it": "Italian",
                "pt": "Portuguese",
                "zh": "Chinese",
                "ja": "Japanese",
                "ko": "Korean",
                "ru": "Russian",
                "ar": "Arabic",
                "hi": "Hindi"
            ],
            "zh": [
                "en": "英语",
                "es": "西班牙语",
                "fr": "法语",
                "de": "德语",
                "it": "意大利语",
                "pt": "葡萄牙语",
                "zh": "中文",
                "ja": "日语",
                "ko": "韩语",
                "ru": "俄语",
                "ar": "阿拉伯语",
                "hi": "印地语"
            ],
            "es": [
                "en": "Inglés",
                "es": "Español",
                "fr": "Francés",
                "de": "Alemán",
                "it": "Italiano",
                "pt": "Portugués",
                "zh": "Chino",
                "ja": "Japonés",
                "ko": "Coreano",
                "ru": "Ruso",
                "ar": "Árabe",
                "hi": "Hindi"
            ],
            "fr": [
                "en": "Anglais",
                "es": "Espagnol",
                "fr": "Français",
                "de": "Allemand",
                "it": "Italien",
                "pt": "Portugais",
                "zh": "Chinois",
                "ja": "Japonais",
                "ko": "Coréen",
                "ru": "Russe",
                "ar": "Arabe",
                "hi": "Hindi"
            ],
            "de": [
                "en": "Englisch",
                "es": "Spanisch",
                "fr": "Französisch",
                "de": "Deutsch",
                "it": "Italienisch",
                "pt": "Portugiesisch",
                "zh": "Chinesisch",
                "ja": "Japanisch",
                "ko": "Koreanisch",
                "ru": "Russisch",
                "ar": "Arabisch",
                "hi": "Hindi"
            ],
            "it": [
                "en": "Inglese",
                "es": "Spagnolo",
                "fr": "Francese",
                "de": "Tedesco",
                "it": "Italiano",
                "pt": "Portoghese",
                "zh": "Cinese",
                "ja": "Giapponese",
                "ko": "Coreano",
                "ru": "Russo",
                "ar": "Arabo",
                "hi": "Hindi"
            ],
            "pt": [
                "en": "Inglês",
                "es": "Espanhol",
                "fr": "Francês",
                "de": "Alemão",
                "it": "Italiano",
                "pt": "Português",
                "zh": "Chinês",
                "ja": "Japonês",
                "ko": "Coreano",
                "ru": "Russo",
                "ar": "Árabe",
                "hi": "Hindi"
            ],
            "ja": [
                "en": "英語",
                "es": "スペイン語",
                "fr": "フランス語",
                "de": "ドイツ語",
                "it": "イタリア語",
                "pt": "ポルトガル語",
                "zh": "中国語",
                "ja": "日本語",
                "ko": "韓国語",
                "ru": "ロシア語",
                "ar": "アラビア語",
                "hi": "ヒンディー語"
            ],
            "ko": [
                "en": "영어",
                "es": "스페인어",
                "fr": "프랑스어",
                "de": "독일어",
                "it": "이탈리아어",
                "pt": "포르투갈어",
                "zh": "중국어",
                "ja": "일본어",
                "ko": "한국어",
                "ru": "러시아어",
                "ar": "아랍어",
                "hi": "힌디어"
            ],
            "ru": [
                "en": "Английский",
                "es": "Испанский",
                "fr": "Французский",
                "de": "Немецкий",
                "it": "Итальянский",
                "pt": "Португальский",
                "zh": "Китайский",
                "ja": "Японский",
                "ko": "Корейский",
                "ru": "Русский",
                "ar": "Арабский",
                "hi": "Хинди"
            ],
            "ar": [
                "en": "الإنجليزية",
                "es": "الإسبانية",
                "fr": "الفرنسية",
                "de": "الألمانية",
                "it": "الإيطالية",
                "pt": "البرتغالية",
                "zh": "الصينية",
                "ja": "اليابانية",
                "ko": "الكورية",
                "ru": "الروسية",
                "ar": "العربية",
                "hi": "الهندية"
            ],
            "hi": [
                "en": "अंग्रेजी",
                "es": "स्पेनिश",
                "fr": "फ्रेंच",
                "de": "जर्मन",
                "it": "इतालवी",
                "pt": "पुर्तगाली",
                "zh": "चीनी",
                "ja": "जापानी",
                "ko": "कोरियाई",
                "ru": "रूसी",
                "ar": "अरबी",
                "hi": "हिंदी"
            ]
        ]
        
        // Return localized name if available, otherwise fall back to English name
        if let namesForLanguage = localizedNames[currentLanguage],
           let localizedName = namesForLanguage[languageCode] {
            return localizedName
        }
        
        // Fallback to English names
        return localizedNames["en"]?[languageCode] ?? languageName
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
}
