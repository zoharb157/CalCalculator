//
//  AppDelegate.swift
//  playground
//
//  Created by OpenCode on 22/12/2025.
//

import FacebookCore
import FirebaseAnalytics
import FirebaseCore
import UIKit
import UserNotifications
import SwiftUI

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Initialize Facebook SDK
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register notification categories with actions
        registerNotificationCategories()
        
        return true
    }
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
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
              let category = MealCategory(rawValue: categoryString) else {
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
}

