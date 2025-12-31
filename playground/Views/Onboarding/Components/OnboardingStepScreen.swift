//
//  OnboardingStepScreen.swift
//  playground
//
//  Created by Bassam-Hillo on 20/12/2025.
//  Refactored by OpenCode on 21/12/2025.
//

import SwiftUI

struct OnboardingStepScreen: View {
    let step: OnboardingStep
    @ObservedObject var store: OnboardingStore

    let showBack: Bool
    let progress: Double
    let onBack: () -> Void
    let onNext: () -> Void
    let onFinish: () -> Void

    var isLast: Bool {
        step.next == nil
    }

    var primaryTitle: String {
        let localizationManager = LocalizationManager.shared
        if isLast { return step.primaryButton?.title ?? localizationManager.localizedString(for: AppStrings.Common.finish) }
        return step.primaryButton?.title ?? localizationManager.localizedString(for: AppStrings.Common.continue_)
    }

    var canContinue: Bool {
        // Always allow continue - don't require values to be set
        return true
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(uiColor: .systemBackground), Color(uiColor: .systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer(minLength: 30)
                // Custom progress bar
                ProgressBar(value: progress)
                    .frame(height: 4)
                    .padding(.horizontal)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            Text(step.title)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            if let description = step.description, !description.isEmpty {
                                Text(description)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 24)

                        // Body
                        Group {
                            switch step.type {
                            case .info:
                                InfoStepBody(step: step)

                            case .question:
                                QuestionStepBody(step: step, store: store)

                            case .form:
                                FormStepBody(step: step, store: store)

                            case .permission:
                                PermissionStepBody(step: step, store: store, onNext: onNext)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)

                // Footer buttons with blur effect
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 16) {
                        if showBack {
                            Button(action: onBack) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(LocalizationManager.shared.localizedString(for: AppStrings.Common.back))
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(uiColor: .systemGray5))
                                .cornerRadius(12)
                            }
                        }

                        if step.type != .permission {
                            Button(action: { isLast ? onFinish() : onNext() }) {
                                Text(primaryTitle)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        canContinue ? 
                                            Color.accentColor :
                                            Color.accentColor.opacity(0.5)
                                    )
                                    .cornerRadius(12)
                            }
                            .disabled(!canContinue)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .background(.ultraThinMaterial)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(LocalizationManager.shared.localizedString(for: AppStrings.Common.done)) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Info Step") {
    OnboardingStepScreen(
        step: OnboardingStep(
            id: "welcome",
            type: .info,
            title: "Welcome to CalCalculator",
            description: "Let's set up your personalized nutrition tracking experience",
            next: "gender",
            fields: nil,
            input: nil,
            optional: nil,
            permission: nil,
            primaryButton: nil
        ),
        store: OnboardingStore(),
        showBack: false,
        progress: 0.1,
        onBack: { print("Back") },
        onNext: { print("Next") },
        onFinish: { print("Finish") }
    )
}

#Preview("Question Step - Single Select") {
    OnboardingStepScreen(
        step: OnboardingStep(
            id: "gender",
            type: .question,
            title: "What is your gender?",
            description: "This helps us calculate your nutritional needs",
            next: "age",
            fields: nil,
            input: OnboardingInput(
                type: .single_select,
                options: ["Male", "Female", "Other"],
                placeholder: nil,
                min: nil,
                max: nil,
                step: nil,
                unit: nil,
                unitOptions: nil,
                defaultUnit: nil
            ),
            optional: false,
            permission: nil,
            primaryButton: nil
        ),
        store: OnboardingStore(),
        showBack: true,
        progress: 0.3,
        onBack: { print("Back") },
        onNext: { print("Next") },
        onFinish: { print("Finish") }
    )
}

#Preview("Question Step - Integer Picker") {
    OnboardingStepScreen(
        step: OnboardingStep(
            id: "age",
            type: .question,
            title: "How old are you?",
            description: "Age affects your caloric requirements",
            next: "weight",
            fields: nil,
            input: OnboardingInput(
                type: .number,
                options: nil,
                placeholder: nil,
                min: 18,
                max: 100,
                step: 1,
                unit: "years",
                unitOptions: nil,
                defaultUnit: nil
            ),
            optional: false,
            permission: nil,
            primaryButton: nil
        ),
        store: OnboardingStore(),
        showBack: true,
        progress: 0.5,
        onBack: { print("Back") },
        onNext: { print("Next") },
        onFinish: { print("Finish") }
    )
}

#Preview("Form Step") {
    OnboardingStepScreen(
        step: OnboardingStep(
            id: "body_metrics",
            type: .form,
            title: "Body Metrics",
            description: "Help us personalize your nutrition goals",
            next: "goals",
            fields: [
                OnboardingField(
                    id: "weight",
                    label: "Current Weight",
                    required: true,
                    input: OnboardingInput(
                        type: .number,
                        options: nil,
                        placeholder: "Enter weight",
                        min: nil,
                        max: nil,
                        step: nil,
                        unit: nil,
                        unitOptions: ["kg", "lbs"],
                        defaultUnit: "kg"
                    )
                ),
                OnboardingField(
                    id: "height",
                    label: "Height",
                    required: true,
                    input: OnboardingInput(
                        type: .number,
                        options: nil,
                        placeholder: "Enter height",
                        min: nil,
                        max: nil,
                        step: nil,
                        unit: nil,
                        unitOptions: ["cm", "ft"],
                        defaultUnit: "cm"
                    )
                )
            ],
            input: nil,
            optional: nil,
            permission: nil,
            primaryButton: nil
        ),
        store: OnboardingStore(),
        showBack: true,
        progress: 0.7,
        onBack: { print("Back") },
        onNext: { print("Next") },
        onFinish: { print("Finish") }
    )
}

#Preview("Permission Step") {
    OnboardingStepScreen(
        step: OnboardingStep(
            id: "notifications",
            type: .permission,
            title: "Enable Notifications",
            description: "Stay on track with meal reminders and daily goals",
            next: nil,
            fields: nil,
            input: nil,
            optional: nil,
            permission: .notifications,
            primaryButton: nil
        ),
        store: OnboardingStore(),
        showBack: true,
        progress: 1.0,
        onBack: { print("Back") },
        onNext: { print("Next") },
        onFinish: { print("Finish") }
    )
}
