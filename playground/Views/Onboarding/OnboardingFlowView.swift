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
                .task { loadIfNeeded() }
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
}

// MARK: - Preview

#Preview {
    OnboardingFlowView(jsonFileName: "onboarding") { result in
        print("Onboarding completed: \(result)")
    }
}
