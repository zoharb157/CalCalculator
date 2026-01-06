//
//  OnboardingWebView.swift
//  playground
//
//  WKWebView-based onboarding flow with integrated goals generation
//

import SwiftUI
import WebKit

/// A SwiftUI wrapper for the HTML-based onboarding flow
struct OnboardingWebView: View {
    let onComplete: (OnboardingResult) -> Void

    var body: some View {
        OnboardingWebViewRepresentable(onComplete: onComplete)
            .ignoresSafeArea()
    }
}

/// Result from the onboarding flow
struct OnboardingResult {
    let answers: [String: Any]
    let goals: GeneratedGoalsData
    let completedAt: Date

    struct GeneratedGoalsData {
        let calories: Int
        let proteinG: Double
        let carbsG: Double
        let fatG: Double
    }
}

/// UIViewRepresentable wrapper for WKWebView
struct OnboardingWebViewRepresentable: UIViewRepresentable {
    let onComplete: (OnboardingResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Add message handler for communication from JS
        config.userContentController.add(context.coordinator, name: "onboarding")

        // Configure preferences
        config.preferences.javaScriptEnabled = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // Allow inspection in Safari for debugging (iOS 16.4+)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        // Load the HTML with injected JS
        loadOnboardingContent(into: webView)

        context.coordinator.webView = webView

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }

    /// Loads the onboarding HTML template and injects the JS content
    private func loadOnboardingContent(into webView: WKWebView) {
        // Load HTML template
        guard let htmlURL = Bundle.main.url(forResource: "onboarding", withExtension: "html"),
            var htmlContent = try? String(contentsOf: htmlURL, encoding: .utf8)
        else {
            print("⚠️ [OnboardingWebView] Could not find or read onboarding.html in bundle")
            return
        }

        // Load JS content
        guard let jsURL = Bundle.main.url(forResource: "onboarding", withExtension: "js"),
            let jsContent = try? String(contentsOf: jsURL, encoding: .utf8)
        else {
            print("⚠️ [OnboardingWebView] Could not find or read onboarding.js in bundle")
            return
        }

        // Replace the placeholder with actual JS content
        htmlContent = htmlContent.replacingOccurrences(of: "#SPLASH_JS#", with: jsContent)

        // Get the base URL for relative resource loading
        let baseURL = htmlURL.deletingLastPathComponent()

        // Load the combined HTML string
        webView.loadHTMLString(htmlContent, baseURL: baseURL)
    }

    /// Coordinator to handle JS message callbacks
    class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?
        let onComplete: (OnboardingResult) -> Void

        init(onComplete: @escaping (OnboardingResult) -> Void) {
            self.onComplete = onComplete
        }

        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            guard message.name == "onboarding" else { return }
            guard let body = message.body as? [String: Any] else { return }
            guard let type = body["type"] as? String else { return }

            let payload = body["payload"] as? [String: Any] ?? [:]

            switch type {
            case "ready":
                print(
                    "📱 [OnboardingWebView] Onboarding ready, first step: \(payload["firstStepId"] ?? "unknown")"
                )

            case "step_view":
                print("📱 [OnboardingWebView] Viewing step: \(payload["stepId"] ?? "unknown")")

            case "complete":
                handleComplete(payload: payload)

            default:
                print("📱 [OnboardingWebView] Unknown message type: \(type)")
            }
        }

        private func handleComplete(payload: [String: Any]) {
            print("📱 [OnboardingWebView] Onboarding complete!")

            // Extract answers
            let answers = payload["answers"] as? [String: Any] ?? [:]

            // Extract generated goals
            let goalsData = payload["goals"] as? [String: Any] ?? [:]
            let goals = OnboardingResult.GeneratedGoalsData(
                calories: goalsData["calories"] as? Int ?? 2000,
                proteinG: goalsData["proteinG"] as? Double ?? 150,
                carbsG: goalsData["carbsG"] as? Double ?? 250,
                fatG: goalsData["fatG"] as? Double ?? 65
            )

            // Parse completion date
            let completedAtString = payload["completedAt"] as? String ?? ""
            let dateFormatter = ISO8601DateFormatter()
            let completedAt = dateFormatter.date(from: completedAtString) ?? Date()

            let result = OnboardingResult(
                answers: answers,
                goals: goals,
                completedAt: completedAt
            )

            // Call completion handler on main thread
            DispatchQueue.main.async { [weak self] in
                self?.onComplete(result)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingWebView { result in
        print("Onboarding completed!")
        print("Calories: \(result.goals.calories)")
        print("Protein: \(result.goals.proteinG)g")
        print("Carbs: \(result.goals.carbsG)g")
        print("Fat: \(result.goals.fatG)g")
    }
}
