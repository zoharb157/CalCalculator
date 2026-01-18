//
//  File 2.swift
//  SDK
//
//  Created by Dubon Ya'ar on 24/01/2025.
//

import Combine
import UIKit

public enum APNSReciveActionDetails {
    case appOpened, duringSession
}

public enum APNSAction {
    case didRegisterForNotifications(token: String),
         didFailToRegisterForNotifications(error: Error),
         didReceive(notification: [AnyHashable: Any] /* UNNotification */, details: APNSReciveActionDetails)
}

public class APNSManager: NSObject {
    public static let shared: APNSManager = .init()
    private var didInject: Bool = false
    public var apnsAction: PassthroughSubject<APNSAction, Never> = .init()
    public private(set) var token: String?
    override private init() {
        super.init()

        UNUserNotificationCenter.current().delegate = self
    }

    func swizzleAppDelegateMethod(selector: Selector, swizzledSelector: Selector) {
        guard let appDelegate = UIApplication.shared.delegate,
              let originalMethod = class_getInstanceMethod(type(of: appDelegate), selector),
              let swizzledMethod = class_getInstanceMethod(type(of: appDelegate), swizzledSelector) else {
            //   print("Swizzling failed: Could not find methods.")
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func forceInjsectMethods() {
        guard !didInject else { return }
        didInject = true
        
        guard let appDelegate = UIApplication.shared.delegate else {
            assertionFailure("App must have an AppDelegate class")
            return
        }

        let appDelegateClass: AnyClass = type(of: appDelegate)

        //
        // didRegisterForRemoteNotificationsWithDeviceToken
        //
        do {
            let selector = #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:))

            // Define the implementation block
            let implementationBlock: @convention(block) (NSObject, UIApplication, Data) -> Void = { _, _, deviceToken in
                let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
                self.apnsAction.send(.didRegisterForNotifications(token: tokenString))
                self.token = tokenString

                Logger.log(level: .native, "☎️ apns token", tokenString)
            }

            // Create an IMP (implementation) from the block
            let implementation = imp_implementationWithBlock(implementationBlock)

            // Add the method to the AppDelegate class
            let didAddMethod = class_addMethod(
                appDelegateClass,
                selector,
                implementation,
                "v@:@@"
            )

            if !didAddMethod {
                //  print("Failed to inject \(selector) into \(appDelegateClass)")
            }
        }

        //
        // didFailToRegisterForRemoteNotificationsWithError
        //
        do {
            let selector = #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:))

            // Define the implementation block
            let implementationBlock: @convention(block) (NSObject, UIApplication, any Error) -> Void = { _, _, error in
                self.apnsAction.send(.didFailToRegisterForNotifications(error: error))
            }

            // Create an IMP (implementation) from the block
            let implementation = imp_implementationWithBlock(implementationBlock)

            // Add the method to the AppDelegate class
            let didAddMethod = class_addMethod(
                appDelegateClass,
                selector,
                implementation,
                "v@:@@"
            )

            if !didAddMethod {
                // print("Failed to inject \(selector) into \(appDelegateClass)")
            }
        }
    }

    func injectDidRegisterMethod() {
        guard let appDelegate = UIApplication.shared.delegate else {
            //   print("No AppDelegate found")
            return
        }

        let appDelegateClass: AnyClass = type(of: appDelegate)
        let selector = #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:))

        // Check if the method already exists
        if class_getInstanceMethod(appDelegateClass, selector) == nil {
            // Define the implementation block
            let implementationBlock: @convention(block) (NSObject, UIApplication, Data) -> Void = { _, _, deviceToken in
                let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
                self.apnsAction.send(.didRegisterForNotifications(token: tokenString))
                self.token = tokenString

            }

            // Create an IMP (implementation) from the block
            let implementation = imp_implementationWithBlock(implementationBlock)

            // Add the method to the AppDelegate class
            let didAddMethod = class_addMethod(
                appDelegateClass,
                selector,
                implementation,
                "v@:@@"
            )

            if didAddMethod {
                //  print("Successfully injected \(selector) into \(appDelegateClass)")
            } else {
                //  print("Failed to inject \(selector) into \(appDelegateClass)")
            }
        } else {
            //   print("\(selector) is already implemented in \(appDelegateClass)")
        }
    }

    @objc func swizzled_application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Call the original implementation
        //  swizzled_application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)

        // Custom behavior
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        //   print("Swizzled Device Token: \(tokenString)")
    }
}

extension APNSManager: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        //  print("Foreground notification: \(notification.request.content.userInfo)")

        apnsAction.send(.didReceive(notification: notification.request.content.userInfo, details: .duringSession))
        completionHandler([.banner, .sound])
    }

    // Handle notifications when the user taps on them
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
        // print("Notification tapped: \(response.notification.request.content.userInfo)")

        // Add custom behavior (e.g., navigate to a specific screen)
        apnsAction.send(.didReceive(notification: response.notification.request.content.userInfo, details: .appOpened))

        completionHandler()
    }
}
