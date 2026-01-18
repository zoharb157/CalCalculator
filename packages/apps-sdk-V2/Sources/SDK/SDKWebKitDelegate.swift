//
//  File.swift
//
//
//  Created by Dubon Ya'ar on 23/10/2024.
//

import Foundation
@preconcurrency import WebKit

class SDKWebKitDelegate: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    weak var model: TheSDK?
    var initialPayload: [String: Any]?
    
    private func requestByEnsuringAppBundleHeaders(_ request: URLRequest) -> URLRequest {
        var copy = request
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        
        // Preserve original header naming used by the SDK historically
        if copy.value(forHTTPHeaderField: "appBundleId") == nil {
            copy.setValue(bundleId, forHTTPHeaderField: "appBundleId")
        }
        
        // Add the header name used by some server-side implementations
        if copy.value(forHTTPHeaderField: "Appbundleid") == nil {
            copy.setValue(bundleId, forHTTPHeaderField: "Appbundleid")
        }
        
        return copy
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let id = body["id"] as? String, let action = body["action"] as? String else { return }
        let params = body["params"] as? [String: Any] ?? [:]

        model?.handle(event: JSEventWrapper(id: id, name: action, parameters: params))
    }
    
    // Ensure custom headers survive redirects / in-page navigations.
    // WKWebView may drop custom headers on redirects or JS-driven navigations, so we re-attach them
    // for main-frame navigations when missing.
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
    {
        // Only patch main-frame navigations; subresource requests don't hit this delegate in a useful way.
        guard navigationAction.targetFrame?.isMainFrame != false else {
            decisionHandler(.allow)
            return
        }
        
        let request = navigationAction.request
        let hasBundleHeader =
            request.value(forHTTPHeaderField: "appBundleId") != nil ||
            request.value(forHTTPHeaderField: "Appbundleid") != nil
        
        if !hasBundleHeader {
            let patched = requestByEnsuringAppBundleHeaders(request)
            webView.load(patched)
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }

    @MainActor
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let model else { return }

        model.webView = webView
        initialPayload = initialPayload ?? [:]
        initialPayload?["deviceLanguage"] = model.config.lang ?? Locale.preferredLanguages.first
        initialPayload?["regionCode"] = Locale.current.region?.identifier
        initialPayload?["storefront"] = model.storefront
        initialPayload?["isRTL"] = Utils.Localization.deviceIsRTL(lang: model.config.lang ?? Locale.preferredLanguages.first ?? "en")
        initialPayload?["sdkVersion"] = TheSDK.version

        Task.detached { @MainActor in
do {
var arguments: [String: Any?] = [
"installTime": SDKStore.lastInstallTime,
"initialPayload": self.initialPayload,
]

arguments["appsFlyerUserId"] = model.userId

if let sessionId = try? await webView.evaluateJavaScript("SESSION_ID") as? String {
await MainActor.run {
SDKStore.sessionId = sessionId
}
}

if model.config.logOptions?.contains(.js) ?? false {
Logger.log(level: .js, "🍏 Calling js function start(installTime,initialPayload)")
}
try await model.webView?.callAsyncJavaScript("start(installTime,initialPayload)", arguments: arguments, in: nil, contentWorld: .page)
//                self.initialPayload = nil
} catch {
model.sendPixelEvent(name: "startError", payload: ["info": "startError:\(String(describing: model.userId)):\(error)"])
}
}
}

func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
Logger.log(level: .js, "🔴 WebView did fail", error)
}

func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
Logger.log(level: .js, "⚠️ \(message)")

completionHandler()
}
}
