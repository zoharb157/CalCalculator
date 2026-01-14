//
//  OnboardingWebView.swift
//  playground
//
//  WKWebView-based onboarding flow with integrated goals generation
//  Uses company standard pattern for JavaScript-to-Swift communication
//

import SwiftUI
import WebKit

// MARK: - OnboardingWebView

/// A SwiftUI wrapper for the HTML-based onboarding flow
struct OnboardingWebView: View {
    let onComplete: (OnboardingResult) -> Void

    var body: some View {
        OnboardingWebViewRepresentable(onComplete: onComplete)
            .ignoresSafeArea()
    }
}

// MARK: - OnboardingResult

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

// MARK: - OnboardingWebViewRepresentable

/// UIViewRepresentable wrapper for WKWebView
struct OnboardingWebViewRepresentable: UIViewRepresentable, Equatable {
    let onComplete: (OnboardingResult) -> Void

    // Conform to Equatable to prevent unnecessary updateUIView calls
    // This prevents "Update NavigationRequestObserver tried to update multiple times per frame" warning
    static func == (lhs: OnboardingWebViewRepresentable, rhs: OnboardingWebViewRepresentable) -> Bool {
        // Always return true since onComplete closure can't be compared
        // This tells SwiftUI that the view hasn't changed and updateUIView shouldn't be called
        return true
    }

    // MARK: - UIViewRepresentable Implementation
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "onboarding")
        config.preferences.javaScriptEnabled = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        loadOnboardingContent(into: webView)
        context.coordinator.webView = webView

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op: WebView is configured once in makeUIView
        // Equatable conformance prevents unnecessary updates
    }
    
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.navigationDelegate = nil
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "onboarding")
        uiView.stopLoading()
    }

    // MARK: - Private Helpers
    
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

    // MARK: - Coordinator
    
    /// Coordinator to handle JS message callbacks and navigation
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        // MARK: - Properties
        
        weak var webView: WKWebView?
        let onComplete: (OnboardingResult) -> Void

        // MARK: - Initialization
        
        init(onComplete: @escaping (OnboardingResult) -> Void) {
            self.onComplete = onComplete
        }
        
        deinit {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "onboarding")
            webView?.navigationDelegate = nil
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // CRITICAL: decisionHandler MUST be called synchronously, not asynchronously
            // Calling it asynchronously causes navigation failures and the "Update NavigationRequestObserver" warning
            // Allow all navigation within the onboarding flow
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Navigation finished - no action needed
        }

        // MARK: - WKScriptMessageHandler
        
        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            guard message.name == "onboarding" else { return }
            guard let body = message.body as? [String: Any] else { return }
            
            // Security: Validate payload size (max 1MB to prevent memory exhaustion)
            if let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []),
               jsonData.count > 1_048_576 { // 1MB limit
                #if DEBUG
                print("⚠️ [OnboardingWebView] Payload too large: \(jsonData.count) bytes")
                #endif
                return
            }
            
            // New company pattern: { id, action, params, replyRequierd }
            let id = body["id"] as? String ?? ""
            let action = body["action"] as? String ?? ""
            let params = body["params"] as? [String: Any] ?? [:]
            let replyRequired = body["replyRequierd"] as? Bool ?? false
            
            // Legacy support: { type, payload }
            if action.isEmpty, let type = body["type"] as? String {
                let payload = body["payload"] as? [String: Any] ?? [:]
                handleLegacyMessage(type: type, payload: payload)
                return
            }
            
            switch action {
            case "ready":
                #if DEBUG
                let firstStepId = params["firstStepId"] as? String ?? "unknown"
                print("📱 [OnboardingWebView] Onboarding ready, first step: \(firstStepId)")
                #endif
                if replyRequired {
                    handleEvent(id: id, payload: ["status": "ready"], error: nil)
                }

            case "step_view":
                #if DEBUG
                let stepId = params["stepId"] as? String ?? "unknown"
                print("📱 [OnboardingWebView] Viewing step: \(stepId)")
                #endif
                if replyRequired {
                    handleEvent(id: id, payload: ["status": "viewed"], error: nil)
                }

            case "generate_goals_via_native":
                // Validate params structure for this action
                guard params["answers"] is [String: Any] else {
                    #if DEBUG
                    print("⚠️ [OnboardingWebView] Invalid params structure for generate_goals_via_native")
                    #endif
                    if replyRequired {
                        handleEvent(id: id, payload: nil, error: "Invalid params structure")
                    }
                    return
                }
                handleGenerateGoalsViaNative(params: params, requestId: replyRequired ? id : nil)

            case "goals_generated":
                // Notification only, no response needed
                break

            case "complete":
                handleComplete(params: params)

            default:
                #if DEBUG
                print("⚠️ [OnboardingWebView] Unknown action: \(action)")
                #endif
                if replyRequired {
                    handleEvent(id: id, payload: nil, error: "Unknown action: \(action)")
                }
            }
        }
        
        // MARK: - Message Handlers
        
        /// Legacy message handler for backward compatibility
        private func handleLegacyMessage(type: String, payload: [String: Any]) {
            #if DEBUG
            print("📱 [OnboardingWebView] Legacy message: \(type)")
            #endif
            switch type {
            case "ready", "step_view":
                break
            case "generate_goals_via_native":
                handleGenerateGoalsViaNative(params: payload, requestId: nil)
            case "complete":
                handleComplete(params: payload)
            default:
                #if DEBUG
                print("⚠️ [OnboardingWebView] Unknown legacy message type: \(type)")
                #endif
            }
        }
        
        /// Handle event response using company pattern (__handleEvent__)
        private func handleEvent(id: String, payload: Any?, error: String?) {
            DispatchQueue.main.async { [weak self] in
                guard let webView = self?.webView else { return }
                
                // Validate ID is not empty (ultra-deep safety - ID should always be valid UUID)
                guard !id.isEmpty else {
                    #if DEBUG
                    print("⚠️ [OnboardingWebView] Empty ID provided to handleEvent")
                    #endif
                    return
                }
                
                // Serialize payload to JSON string for safe transmission
                var payloadJson = "undefined"
                if let payload = payload {
                    if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        // Escape for JavaScript string literal (single quotes)
                        // JSON already has escaped quotes (\"), we just need to escape single quotes
                        let escaped = jsonString
                            .replacingOccurrences(of: "\\", with: "\\\\")  // Escape backslashes first
                            .replacingOccurrences(of: "'", with: "\\'")     // Escape single quotes
                            .replacingOccurrences(of: "\n", with: "\\n")    // Escape newlines
                            .replacingOccurrences(of: "\r", with: "\\r")    // Escape carriage returns
                        payloadJson = "'\(escaped)'"
                    }
                }
                
                // Escape error string if present (ultra-deep safety)
                var errorJson = "undefined"
                if let error = error {
                    // Escape for JavaScript string literal
                    let escaped = error
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "'", with: "\\'")
                        .replacingOccurrences(of: "\n", with: "\\n")
                        .replacingOccurrences(of: "\r", with: "\\r")
                    errorJson = "'\(escaped)'"
                }
                
                // Escape ID for JavaScript string (ultra-deep safety - though ID should be safe)
                let escapedId = id
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "\\r")
                
                // Call __handleEvent__ with id, payload, and optional error
                // Parse payload JSON if it's a string, otherwise pass directly
                let message: String
                if payloadJson != "undefined" {
                    message = """
                        (function() {
                            try {
                                var payload = JSON.parse(\(payloadJson));
                                var error = \(errorJson);
                                if (typeof __handleEvent__ === 'function') {
                                    __handleEvent__('\(escapedId)', payload, error);
                                } else {
                                    console.error('__handleEvent__ is not defined');
                                }
                            } catch (e) {
                                console.error('Failed to handle event:', e);
                            }
                        })();
                    """
                } else {
                    message = """
                        (function() {
                            try {
                                var error = \(errorJson);
                                if (typeof __handleEvent__ === 'function') {
                                    __handleEvent__('\(escapedId)', undefined, error);
                                } else {
                                    console.error('__handleEvent__ is not defined');
                                }
                            } catch (e) {
                                console.error('Failed to handle event:', e);
                            }
                        })();
                    """
                }
                
                webView.evaluateJavaScript(message) { result, error in
                    #if DEBUG
                    if let error = error {
                        print("❌ [OnboardingWebView] Failed to handle event: \(error.localizedDescription)")
                    }
                    #endif
                }
            }
        }
        
        /// Handle goals generation request via native Swift service
        private func handleGenerateGoalsViaNative(params: [String: Any], requestId: String?) {
            #if DEBUG
            print("📱 [OnboardingWebView] Generate goals via native requested")
            #endif
            
            guard let answers = params["answers"] as? [String: Any] else {
                #if DEBUG
                print("❌ [OnboardingWebView] Missing answers in params")
                #endif
                if let requestId = requestId {
                    handleEvent(id: requestId, payload: nil, error: "Missing answers data")
                } else {
                    postGoalsGeneratedToJS(ok: false, error: "Missing answers data")
                }
                return
            }
            
            Task {
                do {
                    let goals = try await GoalsGenerationService.shared.generateGoals(from: answers)
                    
                    #if DEBUG
                    print("✅ [OnboardingWebView] Goals generated: \(goals.calories) cal")
                    #endif
                    
                    // Send success response back to JavaScript
                    let goalsData: [String: Any] = [
                        "calories": goals.calories,
                        "proteinG": goals.proteinG,
                        "carbsG": goals.carbsG,
                        "fatG": goals.fatG
                    ]
                    
                    let response: [String: Any] = [
                        "ok": true,
                        "goals": goalsData
                    ]
                    
                    if let requestId = requestId {
                        // New company pattern: use __handleEvent__
                        handleEvent(id: requestId, payload: response, error: nil)
                    } else {
                        // Legacy fallback: use CustomEvent
                        postGoalsGeneratedToJS(ok: true, goals: goalsData)
                    }
                } catch {
                    #if DEBUG
                    print("❌ [OnboardingWebView] Failed to generate goals: \(error.localizedDescription)")
                    #endif
                    let errorMsg = (error as? GoalsGenerationError)?.errorDescription ?? error.localizedDescription
                    
                    if let requestId = requestId {
                        // New company pattern: use __handleEvent__
                        handleEvent(id: requestId, payload: nil, error: errorMsg)
                    } else {
                        // Legacy fallback: use CustomEvent
                        postGoalsGeneratedToJS(ok: false, error: errorMsg)
                    }
                }
            }
        }
        
        /// Legacy method: Post goals to JavaScript using CustomEvent (for backward compatibility)
        private func postGoalsGeneratedToJS(ok: Bool, goals: [String: Any]? = nil, error: String? = nil) {
            DispatchQueue.main.async { [weak self] in
                guard let webView = self?.webView else {
                    #if DEBUG
                    print("⚠️ [OnboardingWebView] WebView is nil, cannot post goals to JS")
                    #endif
                    return
                }
                
                var payload: [String: Any] = ["ok": ok]
                if let goals = goals {
                    payload["goals"] = goals
                }
                if let error = error {
                    payload["error"] = error
                }
                
                // Serialize to JSON and encode as base64 for safe transmission
                guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
                      let jsonString = String(data: jsonData, encoding: .utf8) else {
                    #if DEBUG
                    print("❌ [OnboardingWebView] Failed to serialize payload to JSON")
                    #endif
                    return
                }
                
                // Encode JSON string as base64 to avoid escaping issues
                let base64String = jsonData.base64EncodedString()
                
                let message = """
                    (function() {
                        try {
                            var jsonString = atob('\(base64String)');
                            var detail = JSON.parse(jsonString);
                            window.dispatchEvent(new CustomEvent('goals_generated_native', { detail: detail }));
                        } catch (e) {
                            console.error('Failed to parse goals data:', e);
                        }
                    })();
                """
                
                webView.evaluateJavaScript(message) { result, error in
                    #if DEBUG
                    if let error = error {
                        print("❌ [OnboardingWebView] Failed to post goals to JS: \(error.localizedDescription)")
                    }
                    #endif
                }
            }
        }
        
        /// Handle onboarding completion
        private func handleComplete(params: [String: Any]) {
            let payload = params
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
