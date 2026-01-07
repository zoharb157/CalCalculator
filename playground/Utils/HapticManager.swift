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
        
        do {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        } catch {
            // Silently fail - haptics are optional
            // This prevents console spam on simulator
        }
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        // Skip haptics on simulator to avoid errors
        guard isPhysicalDevice else { return }
        
        do {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        } catch {
            // Silently fail - haptics are optional
            // This prevents console spam on simulator
        }
    }
    
    func selection() {
        // Skip haptics on simulator to avoid errors
        guard isPhysicalDevice else { return }
        
        do {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        } catch {
            // Silently fail - haptics are optional
            // This prevents console spam on simulator
        }
    }
}
