//
//  JSView.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 02/07/2024.
//

import Combine
import Foundation
import SwiftUI
import WebKit

public typealias SDKViewDismissCallback = ([String: Any]) -> Void?
public struct SDKView: UIViewRepresentable, SDKViewModelDelegate {
    private var model: TheSDK
    private var urlRequest: URLRequest
    private let webView: WKWebView
    private var dismissCallback: SDKViewDismissCallback?
    private let opeque: Bool
    private let ignoreSafeArea: Bool
    private let backgroundColor: Color?
    private let overrideLocale: String?

    public init(model: TheSDK,
                page: Page,
                show: Binding<Bool>,
                initialPayload: [String: Any]? = nil,
                opeque: Bool = true,
                backgroundColor: Color? = nil,
                ignoreSafeArea: Bool = false,
                overrideLocale: String? = nil,
                _ callback: SDKViewDismissCallback? = nil)
    {
        // set url

        dismissCallback = callback
        self.model = model
        self.model.showSDK = show
        self.opeque = opeque
        self.backgroundColor = backgroundColor
        self.ignoreSafeArea = ignoreSafeArea
        model.webkitDelegate.initialPayload = initialPayload
        self.overrideLocale = overrideLocale

        var url: URL!
        switch page {
        case .splash:
            url = model.config.domainURL.appendingPathComponent("splash")

        case .unlockContent:
            url = model.config.domainURL.appendingPathComponent("unlock")

        case .premium:
            url = model.config.domainURL.appendingPathComponent("premium")

        case let .custom(customURL):
            url = customURL
        }

        url = url.appending(queryItems:
            [
                .init(name: "uid", value: model.userId),
                .init(name: "ver", value: model.appVersion),
                .init(name: "deviceModel", value: Utils.deviceModel),
                .init(name: "marketingDeviceName", value: Utils.marketingDeviceName ?? ""),
                .init(name: "deviceLanguage", value: overrideLocale ?? Locale.preferredLanguages.first ?? "en"),
                .init(name: "storefront", value: model.storefront)
            ]
        )

        urlRequest = URLRequest(url: url)
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        // Keep the original header name for backward compatibility
        urlRequest.setValue(bundleId, forHTTPHeaderField: "appBundleId")
        // Add the exact header name some servers expect (case/format sensitive implementations)
        urlRequest.setValue(bundleId, forHTTPHeaderField: "Appbundleid")

        let contentController: WKUserContentController = .init()

//        let config = WKWebViewConfiguration()
//        config.userContentController = contentController

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        config.userContentController = contentController
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.processPool = WKProcessPool()

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = model.webkitDelegate
        webView.uiDelegate = model.webkitDelegate
        // webView.scrollView.isScrollEnabled = false
        webView.scrollView.maximumZoomScale = 1
        webView.scrollView.minimumZoomScale = 1
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        if ignoreSafeArea {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }

        let disableZoomScript = """
        var meta = document.createElement('meta'); 
        meta.name = 'viewport'; 
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'; 
        document.getElementsByTagName('head')[0].appendChild(meta);
        """
        let scriptInjection = WKUserScript(source: disableZoomScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)

        contentController.add(model.webkitDelegate, name: "jsToSwift")
        model.delegate = self

        Task.detached {
            contentController.addUserScript(scriptInjection)
        }
    }

    func handle(event: JSEventWrapper) {
        switch event.name {
        case "dismiss":
            model.delegate = nil
            DispatchQueue.main.async {
                webView.configuration.userContentController.removeAllScriptMessageHandlers()
                dismissCallback?(event.parameters)
            }
        default: break
        }
    }

    public func makeUIView(context: Context) -> UIView {
        let container: UIView = .init()
        container.addSubview(webView)
        container.backgroundColor = .clear // opeque ? .white : .clear

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true
        webView.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true

        if let backgroundColor {
            webView.backgroundColor = UIColor(backgroundColor)
            webView.isOpaque = false
        } else {
            webView.isOpaque = opeque
        }

        DispatchQueue.main.async { [weak webView] in
            webView?.load(urlRequest)
        }

        return container
    }

    public func updateUIView(_ uiView: UIView, context: Context) {}
}
