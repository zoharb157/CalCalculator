//
//  HapticManager.swift
//  playground
//
//  CalAI Clone - Haptic feedback management
//

import UIKit

/// Manages haptic feedback throughout the app
final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    /// Check if running on a physical device (haptics don't work well on simulator)
    private var isPhysicalDevice: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        // Skip haptics on simulator to avoid errors
        guard isPhysicalDevice else { return }
        
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        // Skip haptics on simulator to avoid errors
        guard isPhysicalDevice else { return }
        
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    func selection() {
        // Skip haptics on simulator to avoid errors
        guard isPhysicalDevice else { return }
        
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
