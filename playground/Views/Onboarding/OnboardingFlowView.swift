//
//  OnboardingFlowView.swift
//  playground
//
//  Created by Bassam-Hillo on 20/12/2025.
//


import SwiftUI

struct OnboardingFlowView: View {
    let jsonFileName: String
    let onComplete: ([String: Any]) -> Void

    @StateObject private var store = OnboardingStore()

    @State private var steps: [OnboardingStep] = []
    @State private var currentIndex: Int = 0
    @State private var history: [Int] = []
    @State private var loadError: String?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let loadError {
                VStack(spacing: 12) {
                    Text("Onboarding Error").font(.headline)
                    Text(loadError).foregroundStyle(.secondary)
                }
                .padding()
            } else if steps.isEmpty {
                ProgressView().task { loadIfNeeded() }
            } else {
                let step = steps[currentIndex]
                OnboardingStepScreen(
                    step: step,
                    store: store,
                    showBack: !history.isEmpty,
                    progress: Double(currentIndex + 1) / Double(max(steps.count, 1)),
                    onBack: { goBack() },
                    onNext: { goNext() },
                    onFinish: { finish() }
                )
                .animation(.default, value: currentIndex)
                .task { 
                    loadIfNeeded()
                }
                .onChange(of: currentIndex) { oldValue, newValue in
                    if !steps.isEmpty && newValue < steps.count {
                        loadValuesFromProfile(for: steps[newValue])
                    }
                }
                .onAppear {
                    if !steps.isEmpty {
                        loadValuesFromProfile(for: step)
                    }
                }
            }
        }
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        do {
            let loaded = try OnboardingLoader.loadSteps(jsonFileName: jsonFileName)
            steps = OnboardingLoader.orderedSteps(from: loaded)
            currentIndex = 0
            history = []
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func goNext() {
        guard !steps.isEmpty else { return }
        let current = steps[currentIndex]

        // compute next index using `next` id if possible, else sequential
        var nextIndex: Int?
        if let nextID = current.next, let idx = steps.firstIndex(where: { $0.id == nextID }) {
            nextIndex = idx
        } else if currentIndex + 1 < steps.count {
            nextIndex = currentIndex + 1
        }

        if let nextIndex {
            history.append(currentIndex)
            currentIndex = nextIndex
        } else {
            finish()
        }
    }

    private func goBack() {
        guard let last = history.popLast() else { return }
        currentIndex = last
    }

    private func finish() {
        let dict = store.asAnyDictionary(jsonFriendly: true)
        onComplete(dict)
    }
    
    private func loadValuesFromProfile(for step: OnboardingStep) {
        let profile = UserProfile.shared
        
        switch step.id {
        case "height_weight":
            // Load height and weight from profile only if not already set
            // Height: convert feet/inches to cm or ft
            if let heightField = step.fields?.first(where: { $0.id == "height" }) {
                // Only load if value doesn't exist
                if store.measurementValueAnswer(stepID: step.id, fieldID: "height") == nil {
                    let heightInInches = Double(profile.heightFeet * 12 + profile.heightInches)
                    let heightInCm = heightInInches * 2.54
                    let defaultUnit = heightField.input.defaultUnit ?? "cm"
                    
                    if defaultUnit == "cm" {
                        store.setMeasurementValue(
                            stepID: step.id,
                            fieldID: "height",
                            value: .double(heightInCm),
                            fallbackUnit: defaultUnit
                        )
                    } else {
                        // ft - store as feet with decimal for inches
                        let feet = Double(profile.heightFeet) + Double(profile.heightInches) / 12.0
                        store.setMeasurementValue(
                            stepID: step.id,
                            fieldID: "height",
                            value: .double(feet),
                            fallbackUnit: defaultUnit
                        )
                    }
                }
            }
            
            // Weight: convert lbs to kg or keep as lbs
            if let weightField = step.fields?.first(where: { $0.id == "weight" }) {
                // Only load if value doesn't exist
                if store.measurementValueAnswer(stepID: step.id, fieldID: "weight") == nil {
                    let defaultUnit = weightField.input.defaultUnit ?? "kg"
                    
                    if defaultUnit == "kg" {
                        let weightInKg = profile.currentWeight * 0.453592
                        store.setMeasurementValue(
                            stepID: step.id,
                            fieldID: "weight",
                            value: .double(weightInKg),
                            fallbackUnit: defaultUnit
                        )
                    } else {
                        // lbs
                        store.setMeasurementValue(
                            stepID: step.id,
                            fieldID: "weight",
                            value: .double(profile.currentWeight),
                            fallbackUnit: defaultUnit
                        )
                    }
                }
            }
            
        case "birthdate":
            // Load date of birth only if not already set
            if let birthdateField = step.fields?.first(where: { $0.id == "birthdate" }) {
                if store.formField(stepID: step.id, fieldID: birthdateField.id) == nil {
                    store.setFormField(
                        stepID: step.id,
                        fieldID: birthdateField.id,
                        value: .date(profile.dateOfBirth)
                    )
                }
            }
            
        default:
            break
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingFlowView(jsonFileName: "onboarding") { result in
        print("Onboarding completed: \(result)")
    }
}

// MARK: - Preview

#Preview {
    OnboardingFlowView(jsonFileName: "onboarding") { result in
        print("Onboarding completed: \(result)")
    }
}
