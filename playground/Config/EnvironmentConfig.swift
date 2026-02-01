import Foundation

// MARK: - Environment Configuration
/// Reads environment values from Info.plist (injected from xcconfig at build time)
/// This allows runtime switching without compile-time #if DEBUG preprocessor directives

enum AppEnvironment: String {
    case debug
    case release
    case prod
    
    /// Current environment based on APP_ENVIRONMENT in Info.plist
    static var current: AppEnvironment {
        guard let envString = Bundle.main.infoDictionary?["APP_ENVIRONMENT"] as? String,
              let env = AppEnvironment(rawValue: envString.lowercased()) else {
            // Default to debug if not set (safety fallback)
            #if DEBUG
            return .debug
            #else
            return .prod
            #endif
        }
        return env
    }
    
    var isProduction: Bool {
        return self == .prod
    }
    
    var isDebug: Bool {
        return self == .debug
    }
}

// MARK: - Environment Configuration Manager
@MainActor
final class EnvironmentConfig {
    
    static let shared = EnvironmentConfig()
    
    private init() {}
    
    // MARK: - API Configuration
    
    /// Base URL for API requests, read from Info.plist
    var apiBaseURL: URL {
        guard let urlString = Bundle.main.infoDictionary?["API_BASE_URL"] as? String,
              let url = URL(string: urlString) else {
            // Fallback - should never happen if xcconfig is properly set
            fatalError("API_BASE_URL not configured in Info.plist. Check your xcconfig files.")
        }
        return url
    }
    
    /// Current environment
    var environment: AppEnvironment {
        return AppEnvironment.current
    }
    
    // MARK: - Feature Flags
    
    /// Whether debug menu should be shown
    var isDebugMenuEnabled: Bool {
        return boolFromInfoPlist(key: "ENABLE_DEBUG_MENU", default: false)
    }
    
    /// Whether logging is enabled
    var isLoggingEnabled: Bool {
        return boolFromInfoPlist(key: "ENABLE_LOGGING", default: true)
    }
    
    /// Whether auto-subscribe is enabled (for QA builds only)
    /// In Prod, this is always false - users must purchase through StoreKit
    var isAutoSubscribeEnabled: Bool {
        return boolFromInfoPlist(key: "ENABLE_AUTO_SUBSCRIBE", default: false)
    }
    
    // MARK: - Convenience Properties
    
    var isProduction: Bool {
        return environment.isProduction
    }
    
    var isDebug: Bool {
        return environment.isDebug
    }
    
    // MARK: - Helpers
    
    private func boolFromInfoPlist(key: String, default defaultValue: Bool) -> Bool {
        guard let value = Bundle.main.infoDictionary?[key] as? String else {
            return defaultValue
        }
        return value.uppercased() == "YES" || value == "1" || value.uppercased() == "TRUE"
    }
    
    private func stringFromInfoPlist(key: String) -> String? {
        return Bundle.main.infoDictionary?[key] as? String
    }
}

// MARK: - Usage Examples
/*
 
 // In your networking layer:
 let baseURL = EnvironmentConfig.shared.apiBaseURL
 
 // For conditional logging:
 if EnvironmentConfig.shared.isLoggingEnabled {
     print("Debug info: \(data)")
 }
 
 // For showing debug menu:
 if EnvironmentConfig.shared.isDebugMenuEnabled {
     showDebugMenu()
 }
 
 // Environment check:
 switch EnvironmentConfig.shared.environment {
 case .debug:
     // Debug-specific behavior
 case .release:
     // Release/staging behavior
 case .prod:
     // Production behavior (same as App Store)
 }
 
 */
