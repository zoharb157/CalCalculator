//
//  AIDataConsentView.swift
//  playground
//
//  Disclosure and consent sheet for AI data sharing
//  Required by Apple Guidelines 5.1.1(i) and 5.1.2(i)
//

import SwiftUI

struct AIDataConsentView: View {
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var onConsent: () -> Void
    var onDecline: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            dragIndicator
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    iconSection
                    titleSection
                    dataDisclosureSection
                    recipientSection
                    privacyNote
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            
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
    
    // MARK: - Icon Section
    
    private var iconSection: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 160, height: 160)
            
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 130, height: 130)
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.5, blue: 1.0),
                            Color(red: 0.5, green: 0.3, blue: 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
            
            Image(systemName: "brain")
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.AIConsent.title))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(localizationManager.localizedString(for: AppStrings.AIConsent.subtitle))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }
    
    // MARK: - Data Disclosure Section
    
    private var dataDisclosureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizationManager.localizedString(for: AppStrings.AIConsent.dataSharedHeader))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            disclosureRow(
                icon: "camera.fill",
                iconColor: .orange,
                title: localizationManager.localizedString(for: AppStrings.AIConsent.dataPhotos),
                description: localizationManager.localizedString(for: AppStrings.AIConsent.dataPhotosDetail)
            )
            
            disclosureRow(
                icon: "figure.stand",
                iconColor: .green,
                title: localizationManager.localizedString(for: AppStrings.AIConsent.dataBodyMetrics),
                description: localizationManager.localizedString(for: AppStrings.AIConsent.dataBodyMetricsDetail)
            )
            
            disclosureRow(
                icon: "figure.run",
                iconColor: .cyan,
                title: localizationManager.localizedString(for: AppStrings.AIConsent.dataWorkouts),
                description: localizationManager.localizedString(for: AppStrings.AIConsent.dataWorkoutsDetail)
            )
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Recipient Section
    
    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localizedString(for: AppStrings.AIConsent.recipientHeader))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "server.rack")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.AIConsent.recipientName))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(localizationManager.localizedString(for: AppStrings.AIConsent.recipientDetail))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Privacy Note
    
    private var privacyNote: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                Text(localizationManager.localizedString(for: AppStrings.AIConsent.privacyNote))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(16)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Button {
                if let url = URL(string: Config.privacyURL.absoluteString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(localizationManager.localizedString(for: AppStrings.AIConsent.viewPrivacyPolicy))
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Disclosure Row
    
    private func disclosureRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
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
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                onConsent()
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(localizationManager.localizedString(for: AppStrings.AIConsent.agreeButton))
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.5, blue: 1.0),
                            Color(red: 0.5, green: 0.3, blue: 0.9)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            Button {
                onDecline()
                dismiss()
            } label: {
                Text(localizationManager.localizedString(for: AppStrings.AIConsent.declineButton))
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

#Preview {
    AIDataConsentView(
        onConsent: { print("Consent granted") },
        onDecline: { print("Consent declined") }
    )
}
