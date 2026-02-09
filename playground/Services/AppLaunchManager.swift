//
//  AppLaunchManager.swift
//  playground
//
//  Manages app launch tracking for paywall and rate us triggers.
//  Tracks app open count and determines when to show paywall/rate us.
//

import Foundation
import UIKit

/// Manages app launch tracking and determines when to show paywall/rate us
@MainActor
final class AppLaunchManager {
    
    // MARK: - Singleton
    
    static let shared = AppLaunchManager()
    
    // MARK: - UserDefaults Keys
    
    private let appOpenCountKey = "appOpenCount"
    private let hasShownRateUsOnSecondOpenKey = "hasShownRateUsOnSecondOpen"
    private let hasShownRateUsOnFirstHomeScreenKey = "hasShownRateUsOnFirstHomeScreen"
    private let lastForegroundTimestampKey = "lastForegroundTimestamp"
    
    // MARK: - Properties
    
    /// Number of times the app has been opened (foreground events)
    private(set) var appOpenCount: Int {
        get { UserDefaults.standard.integer(forKey: appOpenCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: appOpenCountKey) }
    }
    
    /// Whether Rate Us has been shown on the second app open
    var hasShownRateUsOnSecondOpen: Bool {
        get { UserDefaults.standard.bool(forKey: hasShownRateUsOnSecondOpenKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasShownRateUsOnSecondOpenKey) }
    }
    
    /// Whether Rate Us has been shown when user first reaches HomeScreen after onboarding
    var hasShownRateUsOnFirstHomeScreen: Bool {
        get { UserDefaults.standard.bool(forKey: hasShownRateUsOnFirstHomeScreenKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasShownRateUsOnFirstHomeScreenKey) }
    }
    
    /// Minimum time between app open counts (to avoid counting quick background/foreground cycles)
    private let minimumTimeBetweenOpens: TimeInterval = 30 // 30 seconds
    
    /// Callbacks for showing paywall and rate us
    var onShowPaywall: (() -> Void)?
    var onShowRateUs: (() -> Void)?
    
    /// Tracks if we should show rate us after paywall dismissal
    private var shouldShowRateUsAfterPaywall = false
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Setup
    
    private func setupNotificationObservers() {
        // Listen for app becoming active (foreground)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppBecameActive()
            }
        }
        
        // Listen for subscription status updates (paywall dismissed)
        NotificationCenter.default.addObserver(
            forName: .subscriptionStatusUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSubscriptionStatusUpdated()
            }
        }
    }
    
    // MARK: - App Lifecycle
    
    /// Called when the app becomes active (foreground)
    private func handleAppBecameActive() {
        // Check if enough time has passed since last foreground event
        let lastTimestamp = UserDefaults.standard.double(forKey: lastForegroundTimestampKey)
        let now = Date().timeIntervalSince1970
        
        // Only count as a new "open" if enough time has passed
        // This prevents counting quick background/foreground cycles
        if now - lastTimestamp > minimumTimeBetweenOpens {
            appOpenCount += 1
            print("📱 [AppLaunchManager] App open count: \(appOpenCount)")
        }
        
        // Update timestamp
        UserDefaults.standard.set(now, forKey: lastForegroundTimestampKey)
        
        // Check if user is subscribed
        let isSubscribed = UserDefaults.standard.bool(forKey: "subscriptionStatus")
        
        // If not subscribed, show paywall on every reopen (after first open/onboarding)
        if !isSubscribed && appOpenCount > 1 {
            // Check if we should also show rate us after paywall (on 2nd open)
            if appOpenCount == 2 && !hasShownRateUsOnSecondOpen {
                shouldShowRateUsAfterPaywall = true
            }
            
            // Show paywall
            print("📱 [AppLaunchManager] Showing paywall for non-subscribed user on app open #\(appOpenCount)")
            
            // Delay slightly to ensure the app UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.onShowPaywall?()
            }
        }
    }
    
    /// Called when subscription status is updated (e.g., paywall dismissed)
    private func handleSubscriptionStatusUpdated() {
        // Check if we should show rate us after paywall was dismissed
        if shouldShowRateUsAfterPaywall {
            shouldShowRateUsAfterPaywall = false
            
            // Check if user subscribed
            let isSubscribed = UserDefaults.standard.bool(forKey: "subscriptionStatus")
            
            // Only show rate us if user still hasn't subscribed
            if !isSubscribed && !hasShownRateUsOnSecondOpen {
                hasShownRateUsOnSecondOpen = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("⭐ [AppLaunchManager] Showing Rate Us after paywall on 2nd app open")
                    self.onShowRateUs?()
                }
            }
        }
    }
    
    // MARK: - First HomeScreen Rate Us
    
    /// Called when user first reaches the HomeScreen after onboarding
    /// Shows Rate Us popup if not already shown
    func handleFirstHomeScreenReached() {
        guard !hasShownRateUsOnFirstHomeScreen else {
            print("⭐ [AppLaunchManager] Rate Us already shown on first HomeScreen, skipping")
            return
        }
        
        hasShownRateUsOnFirstHomeScreen = true
        
        // Delay slightly to ensure the HomeScreen is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("⭐ [AppLaunchManager] Showing Rate Us on first HomeScreen after onboarding")
            self.onShowRateUs?()
        }
    }
    
    // MARK: - Reset (for testing)
    
    /// Resets all tracking state (useful for testing)
    func resetState() {
        appOpenCount = 0
        hasShownRateUsOnSecondOpen = false
        hasShownRateUsOnFirstHomeScreen = false
        UserDefaults.standard.set(0, forKey: lastForegroundTimestampKey)
        shouldShowRateUsAfterPaywall = false
        print("📱 [AppLaunchManager] State reset")
    }
}
