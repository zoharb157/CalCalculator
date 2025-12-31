//
//  PermissionStepBody.swift
//  playground
//
//  Created by OpenCode on 21/12/2025.
//

import SwiftUI
import UserNotifications

struct PermissionStepBody: View {
    let step: OnboardingStep
    @ObservedObject var store: OnboardingStore
    let onNext: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
                .padding(.top, 40)
            
            Text(localizationManager.localizedString(for: AppStrings.Profile.youCanChangeThisAnytime))
                .id("change-anytime-\(localizationManager.currentLanguage)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    requestPermission()
                } label: {
                    HStack(spacing: 8) {
                        if isRequesting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(localizationManager.localizedString(for: AppStrings.Onboarding.allowNotifications))
                                .id("allow-notifications-\(localizationManager.currentLanguage)")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .disabled(isRequesting)
                
                Button {
                    store.setStepAnswer(stepID: step.id, value: .bool(false))
                    onNext()
                } label: {
                    Text(localizationManager.localizedString(for: AppStrings.Onboarding.notNow))
                        .id("not-now-\(localizationManager.currentLanguage)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(uiColor: .systemGray5))
                        .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func requestPermission() {
        guard step.permission == .notifications else {
            store.setStepAnswer(stepID: step.id, value: .bool(false))
            onNext()
            return
        }

        isRequesting = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                store.setStepAnswer(stepID: step.id, value: .bool(granted))
                isRequesting = false
                onNext()
            }
        }
    }
}

#Preview {
    PermissionStepBody(
        step: OnboardingStep(
            id: "notifications",
            type: .permission,
            title: "Enable Notifications",
            description: "Get reminders for your meals and goals",
            next: nil,
            fields: nil,
            input: nil,
            optional: nil,
            permission: .notifications,
            primaryButton: nil
        ),
        store: OnboardingStore(),
        onNext: { print("Next tapped") }
    )
    .padding()
}
