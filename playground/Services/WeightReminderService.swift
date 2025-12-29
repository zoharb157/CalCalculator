//
//  WeightReminderService.swift
//  playground
//
//  Service for scheduling daily weight reminder notifications
//

import Foundation
import UserNotifications

@MainActor
final class WeightReminderService {
    static let shared = WeightReminderService()
    
    private let notificationIdentifier = "daily_weight_reminder"
    
    private init() {}
    
    // MARK: - Notification Authorization
    
    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        
        if !granted {
            throw WeightReminderError.authorizationDenied
        }
    }
    
    // MARK: - Schedule Reminder
    
    /// Schedule daily weight reminder at 8 AM
    func scheduleDailyReminder() async throws {
        // Request authorization first
        try await requestAuthorization()
        
        // Remove any existing weight reminder notifications
        await cancelReminder()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Time to Log Your Weight"
        content.body = "Track your progress by logging your weight this morning"
        content.sound = .default
        content.categoryIdentifier = "WEIGHT_REMINDER"
        content.userInfo = [
            "type": "weight_reminder",
            "action": "log_weight"
        ]
        
        // Create daily trigger at 8 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create notification request
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )
        
        // Schedule the notification
        let center = UNUserNotificationCenter.current()
        try await center.add(request)
        
        print("📅 Scheduled daily weight reminder at 8:00 AM")
    }
    
    /// Cancel the weight reminder
    func cancelReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        print("📅 Cancelled weight reminder")
    }
    
    /// Check if reminder is scheduled
    func isReminderScheduled() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        return pendingRequests.contains { $0.identifier == notificationIdentifier }
    }
}

// MARK: - Errors

enum WeightReminderError: LocalizedError {
    case authorizationDenied
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Notification authorization was denied"
        }
    }
}

