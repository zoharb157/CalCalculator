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
    // Observe UserSettings directly for reactive updates
    @Bindable private var settings = UserSettings.shared
    
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
                    if isDebugOrTestFlight {
                        debugSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.title))
                .id("profile-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: localizationManager.currentLanguage) { oldValue, newValue in
                // Force view refresh when language changes
                viewModel.loadProfileData()
            }
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
            ProfileSectionHeader(title: localizationManager.localizedString(for: AppStrings.Profile.account))
            
            ProfileSectionCard {
                SettingsRow(
                    icon: "gearshape",
                    title: localizationManager.localizedString(for: AppStrings.Profile.preferences),
                    subtitle: localizationManager.localizedString(for: AppStrings.Profile.appearanceNotificationsBehavior),
                    action: { showingPreferences = true }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "globe",
                    title: localizationManager.localizedString(for: AppStrings.Profile.language),
                    subtitle: getLocalizedLanguageName(from: viewModel.selectedLanguage),
                    action: { showingLanguageSelection = true }
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
                SettingsRow(
                    icon: "target",
                    iconColor: .orange,
                    title: localizationManager.localizedString(for: AppStrings.Profile.nutritionGoals),
                    subtitle: localizationManager.localizedString(for: AppStrings.Profile.nutritionGoalsSummary, arguments: viewModel.calorieGoal, Int(viewModel.proteinGoal)),
                    action: { showingEditNutritionGoals = true }
                )

                SettingsDivider()
                
                SettingsRow(
                    icon: "clock.arrow.circlepath",
                    iconColor: .purple,
                    title: localizationManager.localizedString(for: AppStrings.Profile.weightHistory),
                    action: { showingWeightHistory = true }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "circle.inset.filled",
                    iconColor: .blue,
                    title: localizationManager.localizedString(for: AppStrings.Profile.ringColorsExplained),
                    action: { showingRingColorsExplained = true }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "medal.fill",
                    iconColor: .yellow,
                    title: localizationManager.localizedString(for: AppStrings.Profile.myBadges),
                    subtitle: BadgeManager.shared.progressText,
                    action: { showingBadges = true }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "square.and.arrow.up",
                    iconColor: .green,
                    title: localizationManager.localizedString(for: AppStrings.Profile.exportData),
                    subtitle: localizationManager.localizedString(for: AppStrings.Profile.downloadDataAsPDF),
                    action: { showingDataExport = true }
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
                    action: { showingSupportEmail = true }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "star.fill",
                    iconColor: .yellow,
                    title: localizationManager.localizedString(for: AppStrings.Profile.rateUs),
                    action: { showingRateUs = true }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "paperplane.fill",
                    iconColor: .green,
                    title: localizationManager.localizedString(for: AppStrings.Profile.sendFeedback),
                    action: { showingSendFeedback = true }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "doc.text",
                    iconColor: .gray,
                    title: localizationManager.localizedString(for: AppStrings.Profile.termsOfService),
                    action: { openURL("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") }
                )
                
                SettingsDivider()
                
                SettingsRow(
                    icon: "hand.raised",
                    iconColor: .gray,
                    title: localizationManager.localizedString(for: AppStrings.Profile.privacyPolicy),
                    action: { openURL("https://www.apple.com/legal/privacy/") }
                )
            }
            
            // App Version
            HStack {
                Spacer()
                Text(localizationManager.localizedString(for: AppStrings.Profile.version))
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
            ProfileSectionHeader(title: localizationManager.localizedString(for: AppStrings.Profile.debug))
            
            ProfileSectionCard {
                ToggleSettingRow(
                    icon: "hammer.fill",
                    iconColor: .orange,
                    title: localizationManager.localizedString(for: AppStrings.Profile.overrideSubscription),
                    description: localizationManager.localizedString(for: AppStrings.Profile.manuallyControlSubscription),
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
                        title: localizationManager.localizedString(for: AppStrings.Profile.debugIsSubscribed),
                        description: localizationManager.localizedString(for: AppStrings.Profile.overrideSubscriptionStatus),
                        isOn: Binding(
                            get: { settings.debugIsSubscribed },
                            set: { settings.debugIsSubscribed = $0 }
                        )
                    )
                    
                    SettingsDivider()
                    
                    HStack {
                        Text(localizationManager.localizedString(for: AppStrings.Profile.debugStatus))
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(settings.debugIsSubscribed ? localizationManager.localizedString(for: AppStrings.Profile.premium) : localizationManager.localizedString(for: AppStrings.Profile.free))
                            .font(.body)
                            .foregroundColor(settings.debugIsSubscribed ? .green : .gray)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    
                    SettingsDivider()
                    
                    HStack {
                        Text(localizationManager.localizedString(for: AppStrings.Profile.sdkStatus))
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(sdk.isSubscribed ? localizationManager.localizedString(for: AppStrings.Profile.premium) : localizationManager.localizedString(for: AppStrings.Profile.free))
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
