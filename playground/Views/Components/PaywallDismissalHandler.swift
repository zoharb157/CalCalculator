//
//  PaywallDismissalHandler.swift
//  playground
//
//  Handles paywall dismissal and subscription status updates
//

import SwiftUI
import SDK

/// Wrapper class to hold a strong reference to the binding and prevent crashes
/// The SDK tries to set showSDK = nil which crashes, so we maintain a strong reference
/// This wrapper creates a binding that can never be deallocated, even if SDK sets its reference to nil
@MainActor
private final class SafeBindingWrapper {
    private final class BindingBox {
        // Mark as nonisolated(unsafe) because Binding access is safe in our MainActor context
        // and we need to access it from @Sendable closures
        nonisolated(unsafe) var binding: Binding<Bool>

        init(_ binding: Binding<Bool>) {
            self.binding = binding
        }
    }

    private let originalBinding: Binding<Bool>
    nonisolated(unsafe) private let sdk: TheSDK
    
    // The actual binding we return to SDK - this is stored to keep it alive
    private var cachedBinding: Binding<Bool>?
    
    // Unique ID for this wrapper instance - exposed for storage
    let wrapperId: UUID
    
    init(originalBinding: Binding<Bool>, sdk: TheSDK) {
        self.originalBinding = originalBinding
        self.sdk = sdk
        self.wrapperId = UUID()
        
        // Create and cache the binding to keep it alive
        // Note: Storage in BindingWrapperStorage maintains strong reference, no need for strongSelf
        self.cachedBinding = self.createBinding()
    }
    
    private func createBinding() -> Binding<Bool> {
        // Create a binding that can NEVER crash, even if SDK sets showSDK = nil
        // Capture all needed values by value (not reference) to avoid any deallocation issues
        
        // Capture the original binding by value - this is safe because Binding is a struct
        let bindingBox = BindingBox(self.originalBinding)
        let wrapperId = self.wrapperId
        
        // Create getter that doesn't capture self
        // Mark as @Sendable to satisfy Binding requirements (safe because we're on MainActor)
        let getValue: @Sendable () -> Bool = {
            // Direct access to captured binding - no self reference
            bindingBox.binding.wrappedValue
        }
        
        // Create setter that doesn't capture self
        // Mark as @Sendable to satisfy Binding requirements (safe because we're on MainActor)
        let setValue: @Sendable (Bool) -> Void = { newValue in
            // Direct access to captured binding - no self reference
            let wasShowing = bindingBox.binding.wrappedValue
            let isDismissing = !newValue && wasShowing
            
            // CRITICAL: Set value IMMEDIATELY and SYNCHRONOUSLY - no delays
            // This allows SwiftUI to dismiss the fullScreenCover immediately when user clicks X
            // The dismissal happens synchronously, so the HTML can close right away
            bindingBox.binding.wrappedValue = newValue
            
            // Handle post-dismissal logic asynchronously (subscription check, etc.)
            // This doesn't block the dismissal - it happens in the background
            // This works even if SDK set showSDK = nil because we look up wrapper from storage
            if isDismissing {
                Task { @MainActor in
                    if let wrapper = BindingWrapperStorage.shared.getWrapper(id: wrapperId) {
                        wrapper.handleDismissal()
                    }
                }
            }
        }
        
        return Binding(get: getValue, set: setValue)
    }
    
    var binding: Binding<Bool> {
        // Return cached binding - this ensures it stays alive even if SDK sets its reference to nil
        return cachedBinding ?? createBinding()
    }
    
    @MainActor
    private func handleDismissal() {
        // Debounce to prevent multiple simultaneous checks
        guard PaywallDismissalState.shared.shouldCheck() else {
            return
        }
        
        defer {
            PaywallDismissalState.shared.finishCheck()
        }
        
        // Update subscription status from SDK
        // Since we're already on MainActor, we can access SDK directly
        let sdk = self.sdk
        
        Task { @MainActor in
            do {
                // Access SDK methods - we're on MainActor so this is safe
                _ = try await sdk.updateIsSubscribed()
                // Update reactive subscription status in app
                NotificationCenter.default.post(name: .subscriptionStatusUpdated, object: nil)
            } catch {
                print("Failed to update subscription status: \(error)")
            }
            
            // If user subscribed, reset analysis, meal save, and exercise save counts
            if sdk.isSubscribed {
                AnalysisLimitManager.shared.resetAnalysisCount()
                MealSaveLimitManager.shared.resetMealSaveCount()
                ExerciseSaveLimitManager.shared.resetExerciseSaveCount()
            }
        }
    }
    
    deinit {
        // Remove from storage when deallocated to prevent memory leaks
        // Capture wrapperId since deinit is nonisolated and can't access MainActor properties directly
        let id = wrapperId
        Task { @MainActor in
            BindingWrapperStorage.shared.remove(id: id)
        }
    }
}

/// Global state to prevent multiple subscription checks from happening simultaneously
@MainActor
private final class PaywallDismissalState {
    static let shared = PaywallDismissalState()
    private var isChecking = false
    private var lastCheckTime: Date = .distantPast
    
    private init() {}
    
    /// Check if we should proceed with subscription check (debouncing)
    func shouldCheck() -> Bool {
        let now = Date()
        // Debounce: only allow one check per 0.5 seconds
        guard !isChecking && now.timeIntervalSince(lastCheckTime) > 0.5 else {
            return false
        }
        isChecking = true
        lastCheckTime = now
        return true
    }
    
    func finishCheck() {
        isChecking = false
    }
}

// Global storage to keep strong references to binding wrappers
// This prevents the SDK from deallocating the binding when it tries to set showSDK = nil
@MainActor
private final class BindingWrapperStorage {
    static let shared = BindingWrapperStorage()
    private var wrappers: [UUID: SafeBindingWrapper] = [:]
    
    private init() {}
    
    func store(_ wrapper: SafeBindingWrapper) -> UUID {
        let id = UUID()
        wrappers[id] = wrapper
        return id
    }
    
    func storeWrapper(_ wrapper: SafeBindingWrapper, id: UUID) {
        wrappers[id] = wrapper
    }
    
    func getWrapper(id: UUID) -> SafeBindingWrapper? {
        wrappers[id]
    }
    
    func remove(id: UUID) {
        wrappers.removeValue(forKey: id)
    }
}

/// Helper function to create a paywall binding with subscription check
/// 
/// Usage:
/// ```swift
/// @State private var showPaywall = false
/// @Environment(TheSDK.self) private var sdk
/// 
/// YourView()
///     .fullScreenCover(isPresented: $showPaywall) {
///         SDKView(
///             model: sdk,
///             page: .splash,
///             show: paywallBinding(showPaywall: $showPaywall, sdk: sdk),
///             backgroundColor: .white,
///             ignoreSafeArea: true
///         )
///     }
/// ```
func paywallBinding(showPaywall: Binding<Bool>, sdk: TheSDK) -> Binding<Bool> {
    // Create a wrapper that maintains a strong reference to prevent crashes
    // The SDK tries to set showSDK = nil which crashes, so we keep a strong reference
    // This is done synchronously with no delays to ensure instant paywall presentation
    let wrapper = SafeBindingWrapper(
        originalBinding: showPaywall,
        sdk: sdk
    )
    
    // Store wrapper in global storage to maintain strong reference (prevents deallocation)
    // This ensures the wrapper stays alive even if SDK sets showSDK = nil
    BindingWrapperStorage.shared.storeWrapper(wrapper, id: wrapper.wrapperId)
    
    // Return binding immediately - no async operations or delays
    // The binding's setter will immediately update showPaywall, allowing SwiftUI to dismiss
    return wrapper.binding
}
