# SDK Integration and Premium Lock UI Implementation Guide

This guide provides complete instructions for implementing the SDK integration and premium feature locking system in your app.

## Table of Contents
1. [SDK Integration](#sdk-integration)
2. [Subscription Status Management](#subscription-status-management)
3. [Premium Lock UI Components](#premium-lock-ui-components)
4. [Feature Locking Implementation](#feature-locking-implementation)
5. [Debug Toggle for Testing](#debug-toggle-for-testing)
6. [Complete File List](#complete-file-list)

---

## 1. SDK Integration

### Step 1.1: Create Config.swift File

Create `playground/Config/Config.swift`:

```swift
//
//  Config.swift
//  playground
//
//  Configuration constants for the app
//

import Foundation

enum Config {
    static let appId: String = "YOUR_APP_ID" // Replace with your actual app ID
    static let baseURL: URL = .init(string: "https://app.yourdomain.com")! // Your server URL
    static let termsURL: URL = .init(string: "https://yourdomain.com/terms")!
    static let privacyURL: URL = .init(string: "https://yourdomain.com/privacy")!
    static let eulaURL: URL = .init(string: "https://yourdomain.com/eula")!
    static let supportURL: URL = .init(string: "https://yourdomain.com/support")!
    static let mailTo: String = "support@yourdomain.com"
    static let mailsubject: String = ""
    static let mailbody: String = "Hello! Here are some suggestions to enhance the app:"
    static let sentryDNS: String = "YOUR_SENTRY_DSN" // Optional: Your Sentry DSN
    static let groupUserDefaultIdentifier: String = "group.com.yourdomain.app"
}
```

### Step 1.2: Update App Entry Point (playgroundApp.swift)

**Add imports:**
```swift
import Firebase
import FirebaseAnalytics
import FacebookCore
import SDK
```

**Add AppDelegate:**
```swift
@UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
```

**Initialize SDK in `init()`:**
```swift
@main
struct playgroundApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    let modelContainer: ModelContainer
    @State var sdk: TheSDK
    
    init() {
        // ... your existing ModelContainer initialization ...
        
        // Initialize SDK synchronously
        sdk = .init(config: .init(
            baseURL: Config.baseURL,
            logOptions: .all, // or nil to disable logging
            apnsHandler: { event in
                switch event {
                case let .didReceive(notification, details):
                    guard details == .appOpened else { return }
                    if let urlString = notification["webviewUrl"] as? String,
                       let url = URL(string: urlString) {
                        print("📱 Deep link received: \(url)")
                    }
                default:
                    break
                }
            }
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(sdk) // Inject SDK
                .environment(\.isSubscribed, UserSettings.shared.debugOverrideSubscription ? UserSettings.shared.debugIsSubscribed : sdk.isSubscribed) // Inject subscription status
                .onChange(of: sdk.isSubscribed) { oldValue, newValue in
                    print("📱 SDK Subscription status changed: \(newValue)")
                }
                .onChange(of: UserSettings.shared.debugOverrideSubscription) {
                    print("📱 Debug override subscription changed: \(UserSettings.shared.debugOverrideSubscription)")
                }
                .onChange(of: UserSettings.shared.debugIsSubscribed) {
                    print("📱 Debug isSubscribed changed: \(UserSettings.shared.debugIsSubscribed)")
                }
        }
    }
}
```

### Step 1.3: Create AppDelegate.swift

Create `playground/AppDelegate.swift`:

```swift
//
//  AppDelegate.swift
//  playground
//
//

import FacebookCore
import FirebaseAnalytics
import FirebaseCore
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Initialize Facebook SDK
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
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
}
```

### Step 1.4: Add Firebase Configuration

Create `playground/Resources/GoogleService-Info.plist` with your Firebase configuration.

### Step 1.5: Update Entitlements

Add to `playground/playground.entitlements`:
```xml
<key>aps-environment</key>
<string>development</string>
```

### Step 1.6: Update ContentView for Subscription Checks

In `ContentView.swift`, add subscription checks:

```swift
@Environment(TheSDK.self) private var sdk
@Environment(\.isSubscribed) private var isSubscribed

// In your onboarding/sign-in states:
Task {
    async let _ = Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
    await sdk.updateIsSubscribed()
}
```

---

## 2. Subscription Status Management

### Step 2.1: Create Environment Key

Create `playground/EnvKeys/IsSubscribedEnvKey.swift`:

```swift
//
//  IsSubscribedEnvKey.swift
//  playground
//
//  Environment key for accessing subscription status throughout the app
//

import SwiftUI

extension EnvironmentValues {
    @Entry var isSubscribed: Bool = false
}
```

### Step 2.2: Update UserSettings for Debug Override

In `playground/Models/UserSettings.swift`, add:

```swift
// MARK: - Debug Properties
var debugOverrideSubscription: Bool {
    didSet { defaults.set(debugOverrideSubscription, forKey: Keys.debugOverrideSubscription) }
}

var debugIsSubscribed: Bool {
    didSet { defaults.set(debugIsSubscribed, forKey: Keys.debugIsSubscribed) }
}

// In Keys enum:
static let debugOverrideSubscription = "debugOverrideSubscription"
static let debugIsSubscribed = "debugIsSubscribed"

// In init():
self.debugOverrideSubscription = defaults.object(forKey: Keys.debugOverrideSubscription) as? Bool ?? false
self.debugIsSubscribed = defaults.object(forKey: Keys.debugIsSubscribed) as? Bool ?? false
```

---

## 3. Premium Lock UI Components

### Step 3.1: Create LockedFeatureOverlay Component

Create/Update `playground/Views/Components/LockedFeatureOverlay.swift`:

```swift
//
//  LockedFeatureOverlay.swift
//  playground
//
//  Reusable lock overlay for premium features
//

import SwiftUI
import SDK

struct LockedFeatureOverlay: View {
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @State private var showPaywall = false
    
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        if !isSubscribed {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    
                    if let message = message {
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Premium Feature")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Button("Unlock") {
                        showPaywall = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
                .padding(40)
            }
            .fullScreenCover(isPresented: $showPaywall) {
                SDKView(
                    model: sdk,
                    page: .splash,
                    show: $showPaywall,
                    backgroundColor: .white,
                    ignoreSafeArea: true
                )
            }
        }
    }
}

/// Blurs content and shows Premium button overlay (matches reference app style)
struct PremiumLockedContent<Content: View>: View {
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @State private var showPaywall = false
    
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
                .blur(radius: isSubscribed ? 0 : 8)
                .opacity(isSubscribed ? 1.0 : 0.3)
            
            if !isSubscribed {
                VStack {
                    Spacer()
                    
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Premium")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            // Gold/yellow gradient matching reference app
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.85, blue: 0.0),  // Gold
                                    Color(red: 1.0, green: 0.92, blue: 0.3)   // Lighter gold
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
                    }
                    
                    Spacer()
                }
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            SDKView(
                model: sdk,
                page: .splash,
                show: $showPaywall,
                backgroundColor: .white,
                ignoreSafeArea: true
            )
        }
    }
}
```

---

## 4. Feature Locking Implementation

### Step 4.1: Lock Macronutrients Section (HomeView)

In `playground/Views/Home/HomeView.swift`:

```swift
@Environment(\.isSubscribed) private var isSubscribed
@Environment(TheSDK.self) private var sdk

private var macroSection: some View {
    PremiumLockedContent {
        MacroCardsSection(
            summary: viewModel.todaysSummary,
            goals: settings.macroGoals
        )
    }
    .listRowInsets(EdgeInsets(.zero))
    .listRowSeparator(.hidden)
    .listRowBackground(Color.clear)
}
```

### Step 4.2: Lock Progress Features (ProgressView)

In `playground/Views/Progress/ProgressView.swift`:

```swift
@Environment(\.isSubscribed) private var isSubscribed
@Environment(TheSDK.self) private var sdk

var body: some View {
    NavigationStack {
        ScrollView {
            VStack(spacing: 20) {
                // Current Weight Card (can remain unlocked or lock specific actions)
                CurrentWeightCard(...)
                
                // BMI Card - Locked with blur + Premium button
                if let bmi = viewModel.bmi, let category = viewModel.bmiCategory {
                    PremiumLockedContent {
                        BMICard(bmi: bmi, category: category, isSubscribed: true)
                    }
                }
                
                // Daily Calories Card - Locked with blur + Premium button
                PremiumLockedContent {
                    DailyCaloriesCard(
                        averageCalories: viewModel.averageCalories,
                        calorieGoal: UserSettings.shared.calorieGoal,
                        isSubscribed: true,
                        onViewDetails: { ... }
                    )
                }
                
                // HealthKit Data Section - Locked with blur + Premium button
                PremiumLockedContent {
                    HealthDataSection(
                        steps: viewModel.steps,
                        activeCalories: viewModel.activeCalories,
                        exerciseMinutes: viewModel.exerciseMinutes,
                        heartRate: viewModel.heartRate,
                        distance: viewModel.distance,
                        sleepHours: viewModel.sleepHours,
                        isSubscribed: true
                    )
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Progress")
    }
}
```

**Update card initializers to make `isSubscribed` optional with default:**

```swift
struct BMICard: View {
    let bmi: Double
    let category: BMICategory
    let isSubscribed: Bool
    
    init(bmi: Double, category: BMICategory, isSubscribed: Bool = true) {
        self.bmi = bmi
        self.category = category
        self.isSubscribed = isSubscribed
    }
    // ... rest of implementation
}

struct DailyCaloriesCard: View {
    let averageCalories: Int
    let calorieGoal: Int
    let isSubscribed: Bool
    let onViewDetails: () -> Void
    
    init(averageCalories: Int, calorieGoal: Int, isSubscribed: Bool = true, onViewDetails: @escaping () -> Void) {
        self.averageCalories = averageCalories
        self.calorieGoal = calorieGoal
        self.isSubscribed = isSubscribed
        self.onViewDetails = onViewDetails
    }
    // ... rest of implementation
}

struct HealthDataSection: View {
    // ... properties ...
    
    init(steps: Int, activeCalories: Int, exerciseMinutes: Int, heartRate: Int, distance: Double, sleepHours: Double, isSubscribed: Bool = true) {
        self.steps = steps
        self.activeCalories = activeCalories
        self.exerciseMinutes = exerciseMinutes
        self.heartRate = heartRate
        self.distance = distance
        self.sleepHours = sleepHours
        self.isSubscribed = isSubscribed
    }
    // ... rest of implementation
}
```

**Remove lock icons and opacity changes from cards** - the `PremiumLockedContent` wrapper handles the locking:

```swift
// Remove these from card implementations:
// .opacity(isSubscribed ? 1.0 : 0.6)
// .overlay(alignment: .topTrailing) { if !isSubscribed { lock icon } }
```

### Step 4.3: Lock Scan Feature (ScanView)

In `playground/Views/Scan/ScanView.swift`:

```swift
@Environment(\.isSubscribed) private var isSubscribed
@Environment(TheSDK.self) private var sdk
@State private var showPaywall = false

// In handlePhotoSelection:
private func handlePhotoSelection(_ newValue: PhotosPickerItem?) {
    Task {
        guard isSubscribed else {
            showPaywall = true
            return
        }
        // ... handle photo selection
    }
}

// In cameraSheet:
private var cameraSheet: some View {
    CameraView { image in
        guard isSubscribed else {
            showPaywall = true
            return
        }
        viewModel.handleSelectedImage(image)
    }
}

// Add fullScreenCover:
.fullScreenCover(isPresented: $showPaywall) {
    SDKView(
        model: sdk,
        page: .splash,
        show: $showPaywall,
        backgroundColor: .white,
        ignoreSafeArea: true
    )
}
```

---

## 5. Debug Toggle for Testing

### Step 5.1: Add Debug Section to Settings

In `playground/Views/Settings/SettingsView.swift`:

```swift
@Environment(TheSDK.self) private var sdk
@StateObject private var settings = UserSettings.shared

private var settingsForm: some View {
    Form {
        // ... existing sections ...
        
        #if DEBUG // Only show in debug builds
        debugSection
        #endif
    }
}

#if DEBUG
private var debugSection: some View {
    Section {
        Toggle(isOn: $settings.debugOverrideSubscription) {
            Label("Override Subscription", systemImage: "hammer.fill")
        }
        
        if settings.debugOverrideSubscription {
            Toggle(isOn: $settings.debugIsSubscribed) {
                HStack {
                    Label("Debug: Is Subscribed", systemImage: "checkmark.circle.fill")
                    Spacer()
                    Text(settings.debugIsSubscribed ? "Premium" : "Free")
                        .foregroundColor(settings.debugIsSubscribed ? .green : .gray)
                }
            }
            HStack {
                Text("SDK Status")
                Spacer()
                Text(sdk.isSubscribed ? "Premium" : "Free")
                    .foregroundColor(sdk.isSubscribed ? .green : .gray)
            }
        }
    } header: {
        Text("Debug")
    } footer: {
        Text("Override subscription status for testing purposes. Only visible in DEBUG builds.")
    }
}
#endif
```

---

## 6. Complete File List

### Files to Create:
1. `playground/Config/Config.swift`
2. `playground/AppDelegate.swift`
3. `playground/EnvKeys/IsSubscribedEnvKey.swift`
4. `playground/Resources/GoogleService-Info.plist`
5. `playground/Views/Components/LockedFeatureOverlay.swift` (or update existing)

### Files to Modify:
1. `playground/playgroundApp.swift` - Add SDK initialization and environment injection
2. `playground/ContentView.swift` - Add subscription checks
3. `playground/Models/UserSettings.swift` - Add debug properties
4. `playground/Views/Home/HomeView.swift` - Wrap macro section with `PremiumLockedContent`
5. `playground/Views/Progress/ProgressView.swift` - Wrap cards with `PremiumLockedContent`
6. `playground/Views/Scan/ScanView.swift` - Add subscription checks to photo/camera actions
7. `playground/Views/Settings/SettingsView.swift` - Add debug section
8. `playground/playground.entitlements` - Add `aps-environment`

### Key Patterns:

**Pattern 1: Blur + Premium Button (for cards/sections)**
```swift
PremiumLockedContent {
    YourCardView(...)
}
```

**Pattern 2: Action Locking (for buttons/actions)**
```swift
guard isSubscribed else {
    showPaywall = true
    return
}
// Perform action
```

**Pattern 3: Full Screen Lock (for entire screens)**
```swift
ZStack {
    YourContentView()
    
    if !isSubscribed {
        LockedFeatureOverlay(message: "Upgrade to Premium")
    }
}
```

---

## 7. Testing Checklist

- [ ] SDK initializes without blocking UI
- [ ] Subscription status updates correctly
- [ ] Premium features show blur + Premium button when locked
- [ ] Tapping Premium button opens paywall
- [ ] Debug toggle works in Settings (DEBUG builds only)
- [ ] Scan feature locks when taking/selecting photos
- [ ] All locked features respect `isSubscribed` status
- [ ] Paywall closes and updates subscription status after purchase

---

## 8. Important Notes

1. **SDK Initialization**: Must be synchronous in `init()`, not in `onAppear` or `task`
2. **Subscription Checks**: Use `async let` with 1-second delay pattern for initial checks
3. **Environment Injection**: Always inject both `sdk` and `isSubscribed` at app root
4. **Blur Radius**: Use 8px blur for locked content
5. **Premium Button**: Gold gradient (#FFD700 to #FFEB3D), black text, crown icon
6. **Debug Override**: Only available in DEBUG builds for testing

---

## 9. Troubleshooting

**Issue**: SDK not initializing
- Check `Config.baseURL` is correct
- Verify Firebase configuration file exists
- Check entitlements include `aps-environment`

**Issue**: Subscription status not updating
- Verify `sdk.updateIsSubscribed()` is called
- Check environment injection in app root
- Verify debug override is disabled if testing real subscription

**Issue**: Premium button not showing
- Check `isSubscribed` is `false`
- Verify `PremiumLockedContent` wrapper is used
- Check environment values are injected correctly

---

## Summary

This implementation provides:
- ✅ Complete SDK integration with proper initialization
- ✅ Subscription status management via environment
- ✅ Premium lock UI matching reference app (blur + gold Premium button)
- ✅ Feature locking for macronutrients, progress cards, and scan actions
- ✅ Debug toggle for testing subscription states
- ✅ Clean, reusable components for future features

All changes follow the exact patterns from the working reference app to ensure compatibility and maintainability.

