//
//  AppDelegate.swift
//  playground
//
//  Created by OpenCode on 22/12/2025.
//

import UIKit
import UserNotifications
import SwiftUI

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register notification categories with actions
        registerNotificationCategories()
        
        // Register for remote notifications (APNs)
        // This requests a device token from Apple Push Notification service
        application.registerForRemoteNotifications()
        
        return true
    }
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // SDK handles URL opening
        return true
    }
    
    // MARK: - Notification Categories
    
    private func registerNotificationCategories() {
        let saveAction = UNNotificationAction(
            identifier: "SAVE_MEAL",
            title: "Save Meal",
            options: []
        )
        
        let editAction = UNNotificationAction(
            identifier: "EDIT_MEAL",
            title: "Edit & Add",
            options: []
        )
        
        let addNewAction = UNNotificationAction(
            identifier: "ADD_NEW",
            title: "Add New Food",
            options: []
        )
        
        let skipAction = UNNotificationAction(
            identifier: "SKIP_MEAL",
            title: "Skip",
            options: [.destructive]
        )
        
        let mealReminderCategory = UNNotificationCategory(
            identifier: "MEAL_REMINDER",
            actions: [saveAction, editAction, addNewAction, skipAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Weight reminder category
        let logWeightAction = UNNotificationAction(
            identifier: "LOG_WEIGHT",
            title: "Log Weight",
            options: []
        )
        
        let weightReminderCategory = UNNotificationCategory(
            identifier: "WEIGHT_REMINDER",
            actions: [logWeightAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([mealReminderCategory, weightReminderCategory])
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap and actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle meal reminder notifications
        if response.notification.request.content.categoryIdentifier == "MEAL_REMINDER" {
            handleMealReminderResponse(response: response, userInfo: userInfo)
        }
        
        // Handle weight reminder notifications
        if response.notification.request.content.categoryIdentifier == "WEIGHT_REMINDER" {
            handleWeightReminderResponse(response: response, userInfo: userInfo)
        }
        
        completionHandler()
    }
    
    private func handleMealReminderResponse(response: UNNotificationResponse, userInfo: [AnyHashable: Any]) {
        guard let scheduledMealIdString = userInfo["scheduledMealId"] as? String,
              let scheduledMealId = UUID(uuidString: scheduledMealIdString),
              let mealName = userInfo["mealName"] as? String,
              let categoryString = userInfo["category"] as? String,
              let _ = MealCategory(rawValue: categoryString) else {
            return
        }
        
        let actionIdentifier = response.actionIdentifier
        
        // Include expected calories if available
        var notificationUserInfo: [String: Any] = [
            "action": actionIdentifier,
            "scheduledMealId": scheduledMealId,
            "mealName": mealName,
            "category": categoryString
        ]
        
        if let expectedCalories = userInfo["expectedCalories"] as? Int {
            notificationUserInfo["expectedCalories"] = expectedCalories
        }
        
        // Post notification to handle in SwiftUI
        NotificationCenter.default.post(
            name: .mealReminderAction,
            object: nil,
            userInfo: notificationUserInfo
        )
    }
    
    private func handleWeightReminderResponse(response: UNNotificationResponse, userInfo: [AnyHashable: Any]) {
        let actionIdentifier = response.actionIdentifier
        
        // Post notification to handle in SwiftUI
        NotificationCenter.default.post(
            name: .weightReminderAction,
            object: nil,
            userInfo: [
                "action": actionIdentifier,
                "type": "weight_reminder"
            ]
        )
    }
    
    // MARK: - Remote Notifications (APNs)
    
    /// Called when device token is successfully registered with APNs
    /// This token should be sent to your server to enable push notifications
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Convert device token to string format
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        print("✅ [AppDelegate] Successfully registered for remote notifications")
        print("📱 [AppDelegate] Device Token: \(token)")
        
        // Store token locally (for debugging and retry logic)
        UserDefaults.standard.set(token, forKey: "apns_device_token")
        
        // Send token to server
        Task {
            guard let userId = AuthenticationManager.shared.userId else {
                print("⚠️ [AppDelegate] Cannot send token: No user ID. Will retry when user is authenticated.")
                // Store token to send later when user is authenticated
                return
            }
            
            // Send with retry logic
            await NotificationService.shared.sendDeviceTokenWithRetry(token: token, userId: userId)
        }
    }
    
    /// Called when remote notification registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ [AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
        
        // Common causes:
        // 1. App is running in simulator (simulators don't support push notifications)
        // 2. Push Notifications capability not enabled in Xcode
        // 3. Invalid provisioning profile
        // 4. Network issues
    }
    
    /// Called when a remote notification is received while app is in background or terminated
    /// This is called before the notification is delivered to the user
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📬 [AppDelegate] Received remote notification: \(userInfo)")
        
        // Handle the notification payload here
        // You can update app state, refresh data, etc.
        
        // Notify SDK about the remote notification (if needed)
        // The SDK's apnsHandler in playgroundApp.swift will also be called
        
        // Call completion handler to indicate result
        completionHandler(.newData)
    }
}

