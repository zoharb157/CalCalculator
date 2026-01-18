//
//  OnboardingWebView.swift
//  playground
//
//  WKWebView-based onboarding flow with integrated goals generation
//

import SwiftUI
import WebKit
import UIKit
@preconcurrency import UserNotifications
import AppTrackingTransparency

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

/// Custom WKWebView that shows a Done button to dismiss the keyboard
class OnboardingWebViewWithDoneButton: WKWebView {
    
    /// Custom toolbar with Done button for dismissing keyboard
    private lazy var doneToolbar: UIToolbar = {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.barStyle = .default
        toolbar.isTranslucent = true
        toolbar.sizeToFit()
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(
            title: LocalizationManager.shared.localizedString(for: AppStrings.Common.done),
            style: .done,
            target: self,
            action: #selector(dismissKeyboard)
        )
        doneButton.tintColor = .systemBlue
        
        toolbar.items = [flexSpace, doneButton]
        return toolbar
    }()
    
    override var inputAccessoryView: UIView? {
        return doneToolbar
    }
    
    @objc private func dismissKeyboard() {
        self.endEditing(true)
    }
}

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

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Add message handler for communication from JS
        config.userContentController.add(context.coordinator, name: "onboarding")

        // Configure preferences
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        // Use custom WKWebView subclass that shows Done button to dismiss keyboard
        let webView = OnboardingWebViewWithDoneButton(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Set navigation delegate to coordinator to avoid multiple updates per frame
        webView.navigationDelegate = context.coordinator

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
        // CRITICAL: WKWebView doesn't need updates on every SwiftUI render cycle
        // SwiftUI calls this method whenever the parent view's body recomputes
        // Since we conform to Equatable and always return true, SwiftUI should skip this
        // But if it's still called, we do nothing to prevent NavigationRequestObserver warnings
        // The webView is configured once in makeUIView and doesn't need reconfiguration
    }
    
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        // Clean up when view is removed from hierarchy
        // This prevents warnings from stale WKWebView instances
        Task { @MainActor in
        uiView.navigationDelegate = nil
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "onboarding")
        uiView.stopLoading()
        }
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

    /// Coordinator to handle JS message callbacks and navigation
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        let onComplete: (OnboardingResult) -> Void

        init(onComplete: @escaping (OnboardingResult) -> Void) {
            self.onComplete = onComplete
        }
        
        deinit {
            // Clean up message handler to prevent memory leaks and warnings
            Task { @MainActor [weak webView] in
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "onboarding")
            webView?.navigationDelegate = nil
            }
        }
        
        // MARK: - WKNavigationDelegate
        
        nonisolated func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // CRITICAL: decisionHandler MUST be called synchronously, not asynchronously
            // Calling it asynchronously causes navigation failures and the "Update NavigationRequestObserver" warning
            // Allow all navigation within the onboarding flow
            decisionHandler(.allow)
        }
        
        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Navigation finished - no action needed
            // This delegate method is called but doesn't need to do anything
        }

        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            guard message.name == "onboarding" else { return }
            guard let body = message.body as? [String: Any] else { return }
            
            // Support both new company pattern (id, action, params) and legacy format (type, payload)
            let action: String?
            let params: [String: Any]
            let replyRequired: Bool
            
            if let newAction = body["action"] as? String {
                // New company pattern: { id, action, params, replyRequierd }
                action = newAction
                params = body["params"] as? [String: Any] ?? [:]
                replyRequired = body["replyRequierd"] as? Bool ?? false
                
                // Handle async responses via __handleEvent__
                if replyRequired, let id = body["id"] as? String {
                    // Store the request ID for async response
                    // The response will be sent via __handleEvent__ which calls handleEvent
                    handleEvent(id: id, action: newAction, params: params)
                    return
                }
            } else if let legacyType = body["type"] as? String {
                // Legacy format: { type, payload }
                action = legacyType
                params = body["payload"] as? [String: Any] ?? [:]
                replyRequired = false
            } else {
                print("⚠️ [OnboardingWebView] Message missing both 'action' and 'type' fields")
                return
            }
            
            guard let action = action else { return }

            switch action {
            case "ready":
                print(
                    "📱 [OnboardingWebView] Onboarding ready, first step: \(params["firstStepId"] ?? "unknown")"
                )

            case "step_view":
                print("📱 [OnboardingWebView] Viewing step: \(params["stepId"] ?? "unknown")")

            case "generate_goals_via_native":
                print("📱 [OnboardingWebView] Generate goals via native requested")
                handleGenerateGoalsViaNative(payload: params)

            case "complete":
                handleComplete(payload: params)
                
            case "permission_request":
                handlePermissionRequest(payload: params)
                
            case "goals_generated":
                // Handle goals_generated event (fire and forget)
                if let ok = params["ok"] as? Bool, ok {
                    print("✅ [OnboardingWebView] Goals generated successfully")
                } else if let error = params["error"] as? String {
                    print("❌ [OnboardingWebView] Goals generation failed: \(error)")
                }

            default:
                print("📱 [OnboardingWebView] Unknown message action: \(action)")
            }
        }
        
        /// Handle async events via __handleEvent__ pattern
        private func handleEvent(id: String, action: String, params: [String: Any]) {
            DispatchQueue.main.async { [weak self] in
                guard self?.webView != nil else { return }
                
                switch action {
                case "generate_goals_via_native":
                    print("📱 [OnboardingWebView] Generate goals via native (async) requested")
                    self?.handleGenerateGoalsViaNativeAsync(id: id, payload: params)
                    
                case "permission_request":
                    print("📱 [OnboardingWebView] Permission request (async) - id: \(id)")
                    self?.handlePermissionRequestAsync(id: id, payload: params)
                    
                case "getIsSubscribed", "appsFlyerEvent", "log", "dismiss":
                    // These actions don't need special handling, just acknowledge
                    // The actual implementation would be in the respective handlers
                    print("📱 [OnboardingWebView] Received action: \(action) (id: \(id))")
                    
                default:
                    print("📱 [OnboardingWebView] Unhandled async action: \(action) (id: \(id))")
                }
            }
        }
        
        /// Post response back to JS via __handleEvent__
        private func postEventToJS(id: String, payload: Any?, error: String? = nil) {
            DispatchQueue.main.async { [weak self] in
                guard let webView = self?.webView else { return }
                
                // Serialize payload to JSON string
                var payloadJsonString = "undefined"
                if let payload = payload {
                    if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        // Escape for JavaScript - need to escape backslashes, quotes, and newlines
                        let escaped = jsonString
                            .replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "'", with: "\\'")
                            .replacingOccurrences(of: "\n", with: "\\n")
                            .replacingOccurrences(of: "\r", with: "\\r")
                        payloadJsonString = "'\(escaped)'"
                    }
                }
                
                // Escape error string
                let errorJsonString: String
                if let error = error {
                    let escaped = error
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "'", with: "\\'")
                        .replacingOccurrences(of: "\n", with: "\\n")
                        .replacingOccurrences(of: "\r", with: "\\r")
                    errorJsonString = "'\(escaped)'"
                } else {
                    errorJsonString = "undefined"
                }
                
                // Build JavaScript code - use string concatenation to avoid interpolation issues
                let payloadCode: String
                if payloadJsonString != "undefined" {
                    // payloadJsonString already contains the escaped JSON string in quotes
                    payloadCode = "JSON.parse(" + payloadJsonString + ")"
                } else {
                    payloadCode = "undefined"
                }
                
                // Build the complete JavaScript string using string interpolation for simple values
                let js = """
                    (function() {
                        try {
                            if (window.__handleEvent__) {
                                var payload = \(payloadCode);
                                window.__handleEvent__('\(id)', payload, \(errorJsonString));
                            } else {
                                console.error('__handleEvent__ not found');
                            }
                        } catch (e) {
                            console.error('Failed to call __handleEvent__:', e);
                        }
                    })();
                """
                
                webView.evaluateJavaScript(js) { _, err in
                    if let err = err {
                        print("❌ [OnboardingWebView] Failed to post event to JS: \(err.localizedDescription)")
                    }
                }
            }
        }
        
        /// Handle generate_goals_via_native as async call
        private func handleGenerateGoalsViaNativeAsync(id: String, payload: [String: Any]) {
            guard let answers = payload["answers"] as? [String: Any] else {
                let response: [String: Any] = [
                    "ok": false,
                    "error": "Missing answers data"
                ]
                postEventToJS(id: id, payload: response)
                return
            }
            
            Task {
                do {
                    print("🔵 [OnboardingWebView] Calling GoalsGenerationService (async)...")
                    let goals = try await GoalsGenerationService.shared.generateGoals(from: answers)
                    
                    print("✅ [OnboardingWebView] Goals generated successfully via native (async)")
                    print("   - Calories: \(goals.calories)")
                    print("   - Protein: \(goals.proteinG)g")
                    print("   - Carbs: \(goals.carbsG)g")
                    print("   - Fat: \(goals.fatG)g")
                    
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
                    
                    postEventToJS(id: id, payload: response)
                } catch {
                    print("❌ [OnboardingWebView] Failed to generate goals via native (async): \(error)")
                    let errorMsg = (error as? GoalsGenerationError)?.errorDescription ?? error.localizedDescription
                    let response: [String: Any] = [
                        "ok": false,
                        "error": errorMsg
                    ]
                    postEventToJS(id: id, payload: response)
                }
            }
        }
        
        /// Handle async permission request via __handleEvent__ pattern
        private func handlePermissionRequestAsync(id: String, payload: [String: Any]) {
            let requestId = payload["requestId"] as? String ?? id
            
            // JS might send "permissionType" (v2) or "type" (older code)
            let permissionType =
                (payload["permissionType"] as? String) ??
                (payload["type"] as? String) ??
                ""
            
            let action = (payload["action"] as? String) ?? "request"
            
            print("📱 [OnboardingWebView] Permission request async - type: \(permissionType), action: \(action)")
            
            switch action {
            case "open_settings":
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                let response: [String: Any] = [
                    "ok": true,
                    "requestId": requestId,
                    "permissionType": permissionType,
                    "status": "opened_settings"
                ]
                postEventToJS(id: id, payload: response)
                
            case "decline":
                let response: [String: Any] = [
                    "ok": true,
                    "requestId": requestId,
                    "permissionType": permissionType,
                    "status": "declined"
                ]
                postEventToJS(id: id, payload: response)
                
            case "status":
                checkPermissionStatusAsync(id: id, requestId: requestId, permissionType: permissionType)
                
            case "request", "request_native":
                requestPermissionAsync(id: id, requestId: requestId, permissionType: permissionType)

            default:
                let response: [String: Any] = [
                    "ok": false,
                    "requestId": requestId,
                    "permissionType": permissionType,
                    "status": "unknown",
                    "error": "Unknown action: \(action)"
                ]
                postEventToJS(id: id, payload: response)
            }
        }
        
        /// Check permission status and respond via __handleEvent__
        private func checkPermissionStatusAsync(id: String, requestId: String, permissionType: String) {
            switch permissionType {
            case "tracking":
                let status = mapTrackingStatus(ATTrackingManager.trackingAuthorizationStatus)
                let response: [String: Any] = [
                    "ok": true,
                    "requestId": requestId,
                    "permissionType": permissionType,
                    "status": status
                ]
                postEventToJS(id: id, payload: response)
                
            case "notifications":
                UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                    Task { @MainActor in
                        guard let self else { return }
                        let status = self.mapNotificationStatus(settings.authorizationStatus)
                        let response: [String: Any] = [
                            "ok": true,
                            "requestId": requestId,
                            "permissionType": permissionType,
                            "status": status
                        ]
                        self.postEventToJS(id: id, payload: response)
                    }
                }

            default:
                let response: [String: Any] = [
                    "ok": false,
                    "requestId": requestId,
                    "permissionType": permissionType,
                    "status": "unknown",
                    "error": "Unsupported permissionType: \(permissionType)"
                ]
                postEventToJS(id: id, payload: response)
            }
        }
        
        /// Request permission and respond via __handleEvent__
        private func requestPermissionAsync(id: String, requestId: String, permissionType: String) {
            switch permissionType {
            case "tracking":
                let current = ATTrackingManager.trackingAuthorizationStatus
                guard current == .notDetermined else {
                    let status = mapTrackingStatus(current)
                    let response: [String: Any] = [
                        "ok": true,
                        "requestId": requestId,
                        "permissionType": permissionType,
                        "status": status
                    ]
                    postEventToJS(id: id, payload: response)
                    return
                }
                
                ATTrackingManager.requestTrackingAuthorization { [weak self] newStatus in
                    Task { @MainActor in
                        guard let self else { return }
                        let status = self.mapTrackingStatus(newStatus)
                        let response: [String: Any] = [
                            "ok": true,
                            "requestId": requestId,
                            "permissionType": permissionType,
                            "status": status
                        ]
                        self.postEventToJS(id: id, payload: response)
                    }
                }
                
            case "notifications":
                let center = UNUserNotificationCenter.current()
                center.getNotificationSettings { [weak self] settings in
                    switch settings.authorizationStatus {
                    case .notDetermined:
                        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                            if granted {
                                DispatchQueue.main.async {
                                    UIApplication.shared.registerForRemoteNotifications()
                                }
                            }
                            // Re-check actual status
                            center.getNotificationSettings { updated in
                                Task { @MainActor in
                                    guard let self else { return }
                                    let status = self.mapNotificationStatus(updated.authorizationStatus)
                                    var response: [String: Any] = [
                                        "ok": error == nil,
                                        "requestId": requestId,
                                        "permissionType": permissionType,
                                        "status": status
                                    ]
                                    if let error = error {
                                        response["error"] = error.localizedDescription
                                    }
                                    self.postEventToJS(id: id, payload: response)
                                }
                            }
                        }
                        
                    default:
                        Task { @MainActor in
                            guard let self else { return }
                            let status = self.mapNotificationStatus(settings.authorizationStatus)
                            let response: [String: Any] = [
                                "ok": true,
                                "requestId": requestId,
                                "permissionType": permissionType,
                                "status": status
                            ]
                            self.postEventToJS(id: id, payload: response)
                        }
                    }
                }

            default:
                let response: [String: Any] = [
                    "ok": false,
                    "requestId": requestId,
                    "permissionType": permissionType,
                    "status": "unknown",
                    "error": "Unsupported permissionType: \(permissionType)"
                ]
                postEventToJS(id: id, payload: response)
            }
        }

        private func handlePermissionRequest(payload: [String: Any]) {
            let requestId = payload["requestId"] as? String ?? UUID().uuidString

            // JS might send "permissionType" (v2) or "type" (older code)
            let permissionType =
                (payload["permissionType"] as? String) ??
                (payload["type"] as? String) ??
                ""

            let action = (payload["action"] as? String) ?? "request"

            switch action {
            case "open_settings":
                DispatchQueue.main.async {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
                postPermissionResultToJS(
                    ok: true,
                    requestId: requestId,
                    permissionType: permissionType,
                    status: "opened_settings"
                )

            case "decline":
                // No OS prompt. We just acknowledge.
                postPermissionResultToJS(
                    ok: true,
                    requestId: requestId,
                    permissionType: permissionType,
                    status: "declined"
                )

            case "status":
                checkPermissionStatus(permissionType: permissionType, requestId: requestId)

            case "request", "request_native":
                requestPermission(permissionType: permissionType, requestId: requestId)

            default:
                postPermissionResultToJS(
                    ok: false,
                    requestId: requestId,
                    permissionType: permissionType,
                    status: "unknown",
                    error: "Unknown action: \(action)"
                )
            }
        }

        private func checkPermissionStatus(permissionType: String, requestId: String) {
            switch permissionType {
            case "tracking":
                let status = mapTrackingStatus(ATTrackingManager.trackingAuthorizationStatus)
                postPermissionResultToJS(ok: true, requestId: requestId, permissionType: permissionType, status: status)

            case "notifications":
                UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                    Task { @MainActor in
                        guard let self else { return }
                        let status = self.mapNotificationStatus(settings.authorizationStatus)
                        self.postPermissionResultToJS(
                            ok: true,
                            requestId: requestId,
                            permissionType: permissionType,
                            status: status
                        )
                    }
                }

            default:
                postPermissionResultToJS(
                    ok: false,
                    requestId: requestId,
                    permissionType: permissionType,
                    status: "unknown",
                    error: "Unsupported permissionType: \(permissionType)"
                )
            }
        }

        private func requestPermission(permissionType: String, requestId: String) {
            switch permissionType {
            case "tracking":
                // Only shows the prompt if notDetermined.
                Task { @MainActor in
                    let current = ATTrackingManager.trackingAuthorizationStatus
                    guard current == .notDetermined else {
                        let status = self.mapTrackingStatus(current)
                        self.postPermissionResultToJS(ok: true, requestId: requestId, permissionType: permissionType, status: status)
                        return
                    }

                    let newStatus = await requestTrackingAuthorizationCompat()
                    let status = self.mapTrackingStatus(newStatus)
                    self.postPermissionResultToJS(
                        ok: true,
                        requestId: requestId,
                        permissionType: permissionType,
                        status: status
                    )
                }

            case "notifications":
                let center = UNUserNotificationCenter.current()
                center.getNotificationSettings { [weak self] settings in
                    switch settings.authorizationStatus {
                    case .notDetermined:
                        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                            if granted {
                                DispatchQueue.main.async {
                                    UIApplication.shared.registerForRemoteNotifications()
                                }
                            }
                            // Re-check actual status
                            center.getNotificationSettings { updated in
                                Task { @MainActor in
                                    guard let self else { return }
                                    let status = self.mapNotificationStatus(updated.authorizationStatus)
                                    self.postPermissionResultToJS(
                                        ok: (error == nil),
                                        requestId: requestId,
                                        permissionType: permissionType,
                                        status: status,
                                        error: error?.localizedDescription
                                    )
                                }
                            }
                        }

                    default:
                        Task { @MainActor in
                            guard let self else { return }
                            let status = self.mapNotificationStatus(settings.authorizationStatus)
                            self.postPermissionResultToJS(ok: true, requestId: requestId, permissionType: permissionType, status: status)
                        }
                    }
                }

            default:
                postPermissionResultToJS(
                    ok: false,
                    requestId: requestId,
                    permissionType: permissionType,
                    status: "unknown",
                    error: "Unsupported permissionType: \(permissionType)"
                )
            }
        }

        private func mapTrackingStatus(_ status: ATTrackingManager.AuthorizationStatus) -> String {
            switch status {
            case .notDetermined: return "not_determined"
            case .restricted:    return "restricted"
            case .denied:        return "denied"
            case .authorized:    return "authorized"
            @unknown default:    return "unknown"
            }
        }

        @MainActor
        private func requestTrackingAuthorizationCompat() async -> ATTrackingManager.AuthorizationStatus {
            if #available(iOS 17, *) {
                return await ATTrackingManager.requestTrackingAuthorization()
            }

            return await withCheckedContinuation { continuation in
                ATTrackingManager.requestTrackingAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        }

        private func mapNotificationStatus(_ status: UNAuthorizationStatus) -> String {
            switch status {
            case .notDetermined: return "not_determined"
            case .denied:        return "denied"
            case .authorized:    return "authorized"
            case .provisional:   return "provisional"
            case .ephemeral:     return "ephemeral"
            @unknown default:    return "unknown"
            }
        }

        private func postPermissionResultToJS(
            ok: Bool,
            requestId: String,
            permissionType: String,
            status: String,
            error: String? = nil
        ) {
            DispatchQueue.main.async { [weak self] in
                guard let webView = self?.webView else {
                    print("⚠️ [OnboardingWebView] WebView is nil, cannot post permission result to JS")
                    return
                }

                var payload: [String: Any] = [
                    "ok": ok,
                    "requestId": requestId,
                    "permissionType": permissionType,
                    "status": status
                ]
                if let error = error {
                    payload["error"] = error
                }

                guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
                      let _ = String(data: jsonData, encoding: .utf8) else {
                    print("❌ [OnboardingWebView] Failed to serialize permission payload to JSON")
                    return
                }

                let base64String = jsonData.base64EncodedString()

                let js = """
                (function() {
                  try {
                    var jsonString = atob('\(base64String)');
                    var detail = JSON.parse(jsonString);
                    window.dispatchEvent(new CustomEvent('permission_result_native', { detail: detail }));
                  } catch (e) {
                    console.error('Failed to parse permission result:', e);
                  }
                })();
                """

                webView.evaluateJavaScript(js) { _, err in
                    if let err = err {
                        print("❌ [OnboardingWebView] Failed to post permission result to JS: \(err.localizedDescription)")
                    }
                }
            }
        }

        private func handleGenerateGoalsViaNative(payload: [String: Any]) {
            print("📱 [OnboardingWebView] ===== Generate Goals Via Native Handler ======")
            print("📱 [OnboardingWebView] Full payload: \(payload)")
            print("📱 [OnboardingWebView] Payload keys: \(payload.keys)")
            
            guard let answers = payload["answers"] as? [String: Any] else {
                print("❌ [OnboardingWebView] Missing answers in payload")
                print("❌ [OnboardingWebView] Payload content: \(payload)")
                postGoalsGeneratedToJS(ok: false, error: "Missing answers data")
                return
            }
            
            print("📱 [OnboardingWebView] Answers extracted: \(answers)")
            print("📱 [OnboardingWebView] Answers keys: \(answers.keys)")
            
            Task {
                do {
                    print("🔵 [OnboardingWebView] Calling GoalsGenerationService...")
                    let goals = try await GoalsGenerationService.shared.generateGoals(from: answers)
                    
                    print("✅ [OnboardingWebView] Goals generated successfully via native")
                    print("   - Calories: \(goals.calories)")
                    print("   - Protein: \(goals.proteinG)g")
                    print("   - Carbs: \(goals.carbsG)g")
                    print("   - Fat: \(goals.fatG)g")
                    
                    // Send success response back to JavaScript
                    let goalsData: [String: Any] = [
                        "calories": goals.calories,
                        "proteinG": goals.proteinG,
                        "carbsG": goals.carbsG,
                        "fatG": goals.fatG
                    ]
                    
                    postGoalsGeneratedToJS(ok: true, goals: goalsData)
                } catch {
                    print("❌ [OnboardingWebView] Failed to generate goals via native: \(error)")
                    print("❌ [OnboardingWebView] Error type: \(type(of: error))")
                    print("❌ [OnboardingWebView] Error description: \(error.localizedDescription)")
                    if let nsError = error as NSError? {
                        print("❌ [OnboardingWebView] NSError domain: \(nsError.domain)")
                        print("❌ [OnboardingWebView] NSError code: \(nsError.code)")
                        print("❌ [OnboardingWebView] NSError userInfo: \(nsError.userInfo)")
                    }
                    let errorMsg = (error as? GoalsGenerationError)?.errorDescription ?? error.localizedDescription
                    postGoalsGeneratedToJS(ok: false, error: errorMsg)
                }
            }
        }
        
        private func postGoalsGeneratedToJS(ok: Bool, goals: [String: Any]? = nil, error: String? = nil) {
            DispatchQueue.main.async { [weak self] in
                guard let webView = self?.webView else {
                    print("⚠️ [OnboardingWebView] WebView is nil, cannot post goals to JS")
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
                guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
                    print("❌ [OnboardingWebView] Failed to serialize payload to JSON")
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
                    if let error = error {
                        print("❌ [OnboardingWebView] Failed to post goals to JS: \(error.localizedDescription)")
                    } else {
                        print("✅ [OnboardingWebView] Posted goals to JS successfully")
                    }
                }
            }
        }
        
        private func handleComplete(payload: [String: Any]) {
            print("📱 [OnboardingWebView] Onboarding complete!")

            // Extract answers
            let answers = payload["answers"] as? [String: Any] ?? [:]
            
            // CRITICAL: Log the answers structure to debug gender extraction
            print("📱 [OnboardingWebView] ===== ONBOARDING ANSWERS =====")
            print("📱 [OnboardingWebView] Answer keys: \(answers.keys)")
            if let genderData = answers["gender"] {
                print("📱 [OnboardingWebView] Gender data type: \(type(of: genderData))")
                print("📱 [OnboardingWebView] Gender data value: \(genderData)")
                if let genderDict = genderData as? [String: Any] {
                    print("📱 [OnboardingWebView] Gender dict keys: \(genderDict.keys)")
                    print("📱 [OnboardingWebView] Gender dict: \(genderDict)")
                }
            } else {
                print("⚠️ [OnboardingWebView] No 'gender' key found in answers")
            }
            print("📱 [OnboardingWebView] Full answers JSON: \(answers)")

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
