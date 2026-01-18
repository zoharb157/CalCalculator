//
//  File.swift
//
//
//  Created by Dubon Ya'ar on 23/10/2024.
//


import AppTrackingTransparency
import Combine
import FirebaseAnalytics
import Foundation
import KeychainAccess
import ShipBookSDK
import StoreKit
import SwiftUI
import UIKit
import WebKit

@Observable
public class TheSDK {
    // -------------------------------------------------------------------------
    // Don't change version manually, only git pre-commit hook allows to change
    static let version = "v1.0.86"
    // -------------------------------------------------------------------------

    @ObservationIgnored
    var delegate: SDKViewModelDelegate?

    @ObservationIgnored
    var showSDK: Binding<Bool>?

    public internal(set) var isSubscribed: Bool = false
    public private(set) var userId: String!

    @ObservationIgnored
    private(set) var analyticsSubject: PassthroughSubject<(String, [AnyHashable: Any]?), Never> = .init()

    @ObservationIgnored
    var webView: WKWebView?

    @ObservationIgnored
    private(set) var imidiateInstallTime: String?

    @ObservationIgnored
    private(set) var config: SDKConfig

    @ObservationIgnored
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    @ObservationIgnored
    private(set) var webkitDelegate: SDKWebKitDelegate = .init()

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = .init()

    @ObservationIgnored
    private let cloudLog: Bool = false

    @ObservationIgnored
    var storefront: String?

    @ObservationIgnored
    var isFirstRun: Bool = false

    @ObservationIgnored
    private var jwtHeaderPayload: JWYHeaderPayload?

    deinit {
        cancellables.forEach { $0.cancel() }
    }

    public init(config: SDKConfig) {
        self.config = config

        print("🚀 TheSDK initializing...")

        Logger.logFilters = config.logOptions
        print("📝 Logger filters set to: \(config.logOptions)")

        // First Run
        isFirstRun = SDKStore.userId == nil

        // User Id - Use stored UUID or generate new one
        // The userId is always a UUID stored in keychain for persistence
        userId = SDKStore.userId ?? UUID().uuidString
        SDKStore.userId = userId
        
        Logger.log(level: .native, "🆔 User ID initialized: \(userId ?? "nil") (isFirstRun: \(isFirstRun))")

        InstallService.run(config: config, userId: userId)

        webkitDelegate.model = self

        //
        // JWTToken
        //
        if let jwtSettings = config.jWTAuthHeader {
            jwtHeaderPayload = .init(userId: userId,
                secret: jwtSettings.secret,
                key: jwtSettings.key,
                experation: jwtSettings.experation)
        }

        // MARK: ShipBook

        // ShipBook.start(appId: "66a2147841bb78001154c8a5", appKey: "d974ba10694bfcd6e853570863e86a4d")

        // MARK: APNS

        if let handler = config.apnsHandler {
            APNSManager.shared.apnsAction.sink {
                handler($0)
            }
            .store(in: &cancellables)
        }

        // MARK: IAP Transaction Observer

        API.IAP.observeTransactions()

        // Generate global Header JWTToken

        // MARK: lifecycle

        NotificationCenter.default
        .publisher(for: UIApplication.willResignActiveNotification)
        .sink { [weak self] _ in
            self?.sendLifecycle(event: .inactive)
        }
        .store(in: &cancellables)

        NotificationCenter.default
        .publisher(for: UIApplication.didBecomeActiveNotification)
        .sink { [weak self] _ in
            Task {
                do {
                    try await self?.updateIsSubscribed()
                } catch {
                    Logger.log(level: .native, "⚠️ Failed to update subscription status on app active: \(error)")
                    // Continue anyway - don't let backend errors block the app
                }
            }

            self?.sendLifecycle(event: .active)
        }
        .store(in: &cancellables)

        NotificationCenter.default
        .publisher(for: UIApplication.willEnterForegroundNotification)
        .sink { [weak self] _ in
            self?.sendLifecycle(event: .foreground)
        }
        .store(in: &cancellables)


        NotificationCenter.default
        .publisher(for: UIApplication.didEnterBackgroundNotification)
        .sink { [weak self] _ in
            self?.sendLifecycle(event: .background)
        }
        .store(in: &cancellables)

        //        NotificationCenter.default
        //            .publisher(for: UIApplication.willTerminateNotification)
        //            .sink { [weak self] _ in
        //                // willTerminate
        //            }
        //            .store(in: &cancellables)

        Task {
            storefront = await Storefront.current?.countryCode
        }

        // Listen for subscription updates
        API.IAP.subscriptionUpdates
        .sink { [weak self] update in
Logger.log(level: .native, "📱 Subscription Update: productId=\(update.productId), isRenewal=\(update.isRenewal), isRestoration=\(update.isRestoration)")

// Handle renewal or restoration
if update.isRenewal || update.isRestoration {
Task { @MainActor in
let isSubscribed = await API.IAP.updateSubscriptionState()
self?.isSubscribed = isSubscribed

// Send analytics event
let eventName = update.isRenewal ? "subscription_renewed" : "subscription_restored"
Logger.log(level: .native, "📊 DEBUG: sendPixelEvent - name: \(eventName), productId: \(update.productId), transactionId: \(update.transactionId), isSubscribed: \(isSubscribed)")
self?.sendPixelEvent(
name: eventName,
payload: [
"productId": update.productId,
"transactionId": "\(update.transactionId)",
"isSubscribed": isSubscribed
]
)
}
}
}
.store(in: &cancellables)
}

private func sendLifecycle(event: LifecycleEventName) {
sendPixelEvent(name: "appLifecycle", payload: ["status": event.rawValue])
}

func handle(event: JSEventWrapper) {
//  sendPixelEvent(name: "handleNative", payload: ["info": "\(event.name):\(event.id)"])
Task {
do {
_ = try await action(event: event)

} catch {
send(event: .init(id: event.id, name: event.name, parameters: [:], error: String(describing: error)))
}
}
}

func send(event: JSEventWrapper) {
delegate?.handle(event: event)

// Don't block the main thread
Task { @MainActor in
do {
let arguments: [String: Any] = [
"id": event.id,
"parameters": event.parameters,
"error": event.error as Any
]

_ = try await self.webView?.callAsyncJavaScript(
"__handleEvent__(id, parameters, error)",
arguments: arguments,
in: nil,
contentWorld: .page
)
} catch {
Logger.log(level: .native, "Failed to send event to JS: \(error)")
}
}
}
}

// MARK: external API

public extension TheSDK {
var isPresented: Bool {
delegate != nil
}

func isSimulatorOrTestFlight() -> Bool {
guard let path = Bundle.main.appStoreReceiptURL?.path else {
return false
}

return path.contains("CoreSimulator") || path.contains("sandboxReceipt")
}

func updateIsSubscribed(extensive: Bool = true) async throws -> Bool {
Logger.log(level: .native, "Checking if user is subscribed")

var isSubscribed = await API.IAP.fetchPurchasedProducts().count > 0

if !isSubscribed, extensive {
isSubscribed = (try? await API.Maven.isUserSubscrbied(userId: userId, sessionId: SDKStore.sessionId, baseURL: config.domainURL, installTime: SDKStore.lastInstallTime)) ?? false
}

let sendableIsSubscribed = isSubscribed
return await MainActor.run {
self.isSubscribed = sendableIsSubscribed
return sendableIsSubscribed
}
}

//    func restorePurchases() {
//        Task.detached(priority: .background) {
//            guard let userId = self.userId else { return }
//            let config = self.config
//            guard let result = try? await API.Subscritpion.restore(baseURL: config.domainURL, userId: userId) else { return }
//
//            await MainActor.run {
//                self.isSubscribed = result
//            }
//        }
//    }

func restorePurchasesAsync() async throws -> Bool {
await Task.detached(priority: .background) {
guard let userId = self.userId else { return false }
let config = self.config
guard let result = try? await API.Subscritpion.restore(baseURL: config.domainURL, userId: userId) else { return false }
await MainActor.run {
self.isSubscribed = result
}
return result
}.result.get()
}

func sendPixelEvent(name: String, queryItems: [URLQueryItem]? = nil, payload: [String: Any]? = nil) {
var immutablePayload = payload ?? [:]
immutablePayload["timestamp"] = Date.now.timeIntervalSince1970

Task(priority: .background) {
try? await API.Events.send(userId: userId,
sessionId: SDKStore.sessionId,
baseURL: config.domainURL,
name: name,
installTime: SDKStore.lastInstallTime,
info: immutablePayload,
queryItems: queryItems,
jwtToken: jwtHeaderPayload?.jwtToken())

config.analyticvCallback?(name, payload)
}
}

/// Log event to Google Analytics 4 via Firebase
/// - Parameters:
///   - name: Event name
///   - parameters: Event parameters dictionary
func logGA4Event(name: String, parameters: [String: Any]? = nil) {
Logger.log(level: .native, "📊 DEBUG: FirebaseAnalytics.logEvent - name: \(name), parameters: \(parameters ?? [:])")
FirebaseAnalytics.Analytics.logEvent(name, parameters: parameters)
}

/// Get the APN (Apple Push Notification) token
/// - Returns: The APN token string, or empty string if not available yet
func getAPNToken() -> String {
let token = APNSManager.shared.token ?? ""

// Send pixel event to track token retrieval
Logger.log(level: .native, "📊 DEBUG: sendPixelEvent - name: APNToken, token: \(token), source: sdk")
sendPixelEvent(name: "APNToken", payload: ["token": token, "source": "sdk"])

return token
}

func deleteUser() {
userId = nil

SDKStore.reset()
}

@discardableResult
func resetUserId() -> String {
    // Generate new UUID for user
    userId = UUID().uuidString
    SDKStore.userId = userId
    
    Logger.log(level: .native, "🆔 User ID reset: New UUID generated: \(userId ?? "nil")")

    if let jwtSettings = config.jWTAuthHeader {
        jwtHeaderPayload = .init(userId: userId, secret: jwtSettings.secret, key: jwtSettings.key, experation: jwtSettings.experation)
    }
    return userId
}
}


public extension TheSDK {
func presentSDKView(page: Page,
show: Binding<Bool>? = nil,
modalPresentationStyle: UIModalPresentationStyle = .fullScreen,
initialPayload: [String: Any]? = nil,
opeque: Bool = true,
backgroundColor: Color? = nil,
ignoreSafeArea: Bool = false,
overrideLocale: String? = nil,
_ callback: SDKViewDismissCallback? = nil)
{
guard let topController = UIApplication.topViewController else {
show?.wrappedValue = false
return
}

topController.modalPresentationStyle = .fullScreen

var vc: SDKViewController!
vc = SDKViewController(sdk: self,
page: page,
initialPayload: initialPayload,
opaque: opeque,
backgroundColor: backgroundColor,
ignoreSafeArea: ignoreSafeArea,
overridLocale: overrideLocale)
{
vc.dismiss(animated: true)
show?.wrappedValue = false
callback?($0)
}

vc.modalPresentationStyle = modalPresentationStyle
topController.present(vc, animated: true)
}
}

public extension UIApplication {
static var topViewController: UIViewController? {
guard let keyWindow = UIApplication.shared.connectedScenes
.compactMap({ $0 as? UIWindowScene })
.flatMap({ $0.windows })
.first(where: { $0.isKeyWindow }) else { return nil }

var topController = keyWindow.rootViewController
while let presentedController = topController?.presentedViewController {
topController = presentedController
}

return topController
}
}
