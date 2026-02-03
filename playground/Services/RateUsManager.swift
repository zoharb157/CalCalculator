//
//  RateUsManager.swift
//  playground
//
//  Manages the "Rate Us" popup for premium users after their first successful action.
//  Only shows the popup once per user.
//

import Foundation
import StoreKit
import UIKit

/// Manages when to show the rate/review popup for premium users
/// Shows the popup only once, after the first successful action
@MainActor
final class RateUsManager {
    
    // MARK: - Singleton
    
    static let shared = RateUsManager()
    
    // MARK: - UserDefaults Keys
    
    private let hasShownRatePopupKey = "hasShownRatePopup"
    private let premiumSuccessfulActionsCountKey = "premiumSuccessfulActionsCount"
    
    // MARK: - Properties
    
    private var cancellables: [NSObjectProtocol] = []
    
    /// Whether the rate popup has already been shown to the user
    var hasShownRatePopup: Bool {
        get { UserDefaults.standard.bool(forKey: hasShownRatePopupKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasShownRatePopupKey) }
    }
    
    /// Count of successful actions performed while premium (for debugging/analytics)
    private(set) var premiumSuccessfulActionsCount: Int {
        get { UserDefaults.standard.integer(forKey: premiumSuccessfulActionsCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: premiumSuccessfulActionsCountKey) }
    }
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationObservers()
    }
    
    // Note: No deinit needed - singleton lives for app lifetime
    // If cleanup is needed, call removeObservers() explicitly
    
    /// Removes all notification observers (call if needed for testing)
    func removeObservers() {
        cancellables.forEach { NotificationCenter.default.removeObserver($0) }
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    
    /// Sets up observers for successful action notifications
    private func setupNotificationObservers() {
        // Listen for food logged
        let foodObserver = NotificationCenter.default.addObserver(
            forName: .foodLogged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSuccessfulAction()
            }
        }
        cancellables.append(foodObserver)
        
        // Listen for exercise saved
        let exerciseObserver = NotificationCenter.default.addObserver(
            forName: .exerciseSaved,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSuccessfulAction()
            }
        }
        cancellables.append(exerciseObserver)
        
        // Listen for weight updated from widget
        let weightObserver = NotificationCenter.default.addObserver(
            forName: .widgetWeightUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSuccessfulAction()
            }
        }
        cancellables.append(weightObserver)
    }
    
    // MARK: - Public Methods
    
    /// Call this when a successful action occurs (can be called manually if needed)
    /// - Parameter isSubscribed: Whether the user is currently a premium subscriber
    func recordSuccessfulAction(isSubscribed: Bool) {
        guard isSubscribed else { return }
        handleSuccessfulAction(isSubscribed: isSubscribed)
    }
    
    /// Resets the rate popup state (useful for testing)
    func resetRatePopupState() {
        hasShownRatePopup = false
        premiumSuccessfulActionsCount = 0
    }
    
    // MARK: - Private Methods
    
    /// Handles a successful action - checks if we should show the rate popup
    private func handleSuccessfulAction(isSubscribed: Bool? = nil) {
        // Check subscription status
        let subscribed = isSubscribed ?? checkSubscriptionStatus()
        
        guard subscribed else { return }
        guard !hasShownRatePopup else { return }
        
        // Increment counter
        premiumSuccessfulActionsCount += 1
        
        // Show rate popup on first successful action
        if premiumSuccessfulActionsCount == 1 {
            showRatePopup()
        }
    }
    
    private func checkSubscriptionStatus() -> Bool {
        return UserDefaults.standard.bool(forKey: "subscriptionStatus")
    }
    
    /// Shows the App Store review popup
    private func showRatePopup() {
        // Mark as shown immediately to prevent duplicate shows
        hasShownRatePopup = true
        
        // Small delay to allow current action's UI to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
        
        print("⭐ [RateUsManager] Showing rate popup after first successful premium action")
    }
}
