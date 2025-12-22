# SDK Integration Instructions for CalCalculator

## Overview
This document contains step-by-step instructions to integrate the SDK into the CalCalculator app, following the exact pattern used in the translate-ios-example app.

## Prerequisites
- The SDK package (`Ios-Bundle`) must be added to the Xcode project
- Firebase and Facebook SDK packages must be available
- App must have proper bundle identifier and signing configured

## Step 1: Create Config.swift File

**Location:** `playground/Config/Config.swift`

**Content:**
```swift
//
//  Config.swift
//  playground
//
//  Configuration constants for the app
//

import Foundation

enum Config {
    static let appId: String = "6738996117" // Replace with your actual App Store ID
    static let baseURL: URL = .init(string: "https://app.caloriecount-ai.com")! // Your server URL
    static let termsURL: URL = .init(string: "https://caloriecount-ai.com/terms")!
    static let privacyURL: URL = .init(string: "https://caloriecount-ai.com/privacy")!
    static let eulaURL: URL = .init(string: "https://caloriecount-ai.com/eula")!
    static let supportURL: URL = .init(string: "https://caloriecount-ai.com/support")!
    static let mailTo: String = "info@caloriecount-ai.com"
    static let mailsubject: String = ""
    static let mailbody: String = "Hello! Here are some suggestions to enhance the app:"
    static let sentryDNS: String = "https://17c717a2646ca702fff364f1a8e7dafb@o4505877729116160.ingest.us.sentry.io/4509282019311616"
    static let groupUserDefaultIdentifier: String = "group.com.caloriecount-ai.app"
}
```

**Important:** Replace URLs and identifiers with your actual values.

## Step 2: Create AppDelegate.swift

**Location:** `playground/AppDelegate.swift`

**Content:**
```swift
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

## Step 3: Update playgroundApp.swift

**Location:** `playground/playgroundApp.swift`

**Required imports:**
```swift
import SwiftUI
import SwiftData
import MavenCommonSwiftUI
import SDK
import Firebase
import FirebaseAnalytics
```

**Add AppDelegate:**
```swift
@main
struct playgroundApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    // ... rest of the struct
}
```

**SDK Initialization in `init()`:**
```swift
init() {
    // ... ModelContainer initialization ...
    
    // Initialize SDK synchronously like the translate app
    sdk = .init(config: .init(baseURL: Config.baseURL,
                              logOptions: .all,
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
                              }))
}
```

**Environment injection:**
```swift
var body: some Scene {
    WindowGroup {
        ContentView()
            .modelContainer(modelContainer)
            .environment(sdk) // Use direct environment like example app
    }
}
```

## Step 4: Update ContentView.swift

**Location:** `playground/ContentView.swift`

**Required imports:**
```swift
import SwiftUI
import SwiftData
import MavenCommonSwiftUI
import SDK
```

**PaywallItem struct:**
```swift
struct PaywallItem: Equatable, Identifiable {
    let page: SDK.Page
    let callback: (() -> Void)?
    
    init(page: SDK.Page, callback: (() -> Void)? = nil) {
        self.page = page
        self.callback = callback
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.page == rhs.page
    }
    
    var id: String {
        page.id
    }
}
```

**SDK Environment:**
```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TheSDK.self) private var sdk // SDK is always available
    @State private var paywallItem: PaywallItem?
    // ... other state variables
}
```

**Subscription Check Pattern (match translate app exactly):**
```swift
Task {
    do {
        async let timewasteTask: () = Task.sleep(nanoseconds: 1_000_000_000) // 1 second like example app
        async let updateSubscriptionStateTask = sdk.updateIsSubscribed()
        
        let _ = try await (timewasteTask, updateSubscriptionStateTask)
        
        await MainActor.run {
            // Use sdk.isSubscribed after updateIsSubscribed completes
            if !sdk.isSubscribed {
                paywallItem = .init(page: .splash, callback: {
                    authState = .authenticated
                })
            } else {
                authState = .authenticated
            }
        }
    } catch {
        // If subscription check fails, proceed to app
        await MainActor.run {
            authState = .authenticated
        }
    }
}
```

**Paywall Presentation:**
```swift
.fullScreenCover(item: $paywallItem) { page in
    let show: Binding<Bool> = .init(
        get: { true },
        set: { _ in
            page.callback?()
            paywallItem = nil
        }
    )
    
    SDKView(
        model: sdk,
        page: page.page,
        show: show,
        backgroundColor: .white,
        ignoreSafeArea: true
    )
    .ignoresSafeArea()
    .id(page.id)
}
.onChange(of: sdk.isSubscribed) { oldValue, newValue in
    if newValue && paywallItem != nil {
        paywallItem?.callback?()
        paywallItem = nil
    }
}
```

## Step 5: Update Entitlements

**Location:** `playground/playground.entitlements`

**Required entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>development</string>
	<key>com.apple.developer.healthkit</key>
	<true/>
</dict>
</plist>
```

**Important:** `aps-environment` is required for push notifications to work with the SDK.

## Step 6: Add GoogleService-Info.plist

**Location:** `playground/Resources/GoogleService-Info.plist`

**Note:** You need to download your own `GoogleService-Info.plist` from Firebase Console. For now, create a placeholder:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>YOUR_API_KEY</string>
	<key>GCM_SENDER_ID</key>
	<string>YOUR_SENDER_ID</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>CalCalculatorAi</string>
	<key>PROJECT_ID</key>
	<string>YOUR_PROJECT_ID</string>
	<key>STORAGE_BUCKET</key>
	<string>YOUR_STORAGE_BUCKET</string>
	<key>IS_ADS_ENABLED</key>
	<false/>
	<key>IS_ANALYTICS_ENABLED</key>
	<true/>
	<key>IS_APPINVITE_ENABLED</key>
	<true/>
	<key>IS_GCM_ENABLED</key>
	<true/>
	<key>IS_SIGNIN_ENABLED</key>
	<true/>
	<key>GOOGLE_APP_ID</key>
	<string>YOUR_GOOGLE_APP_ID</string>
	<key>GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS</key>
	<true/>
</dict>
</plist>
```

## Step 7: Verify Project Settings

**In Xcode project settings:**

1. **Signing & Capabilities:**
   - Push Notifications capability enabled
   - HealthKit capability (if needed)
   - App Groups (if using shared data)

2. **Info.plist keys (via project.pbxproj or Info.plist):**
   - `NSUserTrackingUsageDescription` - Required for tracking
   - `NSHealthShareUsageDescription` - If using HealthKit
   - `NSHealthUpdateUsageDescription` - If using HealthKit
   - `NSCameraUsageDescription` - If using camera
   - `NSPhotoLibraryUsageDescription` - If using photo library

3. **Build Settings:**
   - `CODE_SIGN_ENTITLEMENTS` should point to `playground/playground.entitlements`

## Step 8: Server Configuration

**CRITICAL:** Your server at `Config.baseURL` must serve proper HTML/JavaScript for the paywall pages.

**Required endpoints:**
- `{baseURL}/splash` - Must return HTML with SDK JavaScript included
- The HTML must define:
  - `start(installTime, initialPayload)` function
  - `SESSION_ID` variable
  - SDK's JavaScript bridge code

**To verify server is working:**
```bash
curl -s "https://app.caloriecount-ai.com/splash" | head -100
```

Should return HTML content, not empty response.

## Step 9: Testing Checklist

- [ ] App builds without errors
- [ ] SDK initializes without crashing
- [ ] Paywall appears when user is not subscribed
- [ ] JavaScript bridge works (check console logs for `🤪 js call` messages)
- [ ] Push notifications work (check for APNS token in logs)
- [ ] Subscription status updates correctly
- [ ] No JavaScript errors (`start` function found, `SESSION_ID` found)

## Common Issues and Solutions

### Issue: "Can't find variable: start" or "Can't find variable: SESSION_ID"
**Solution:** Server is returning empty content. Verify server serves proper HTML/JavaScript at `/splash` endpoint.

### Issue: "no valid aps-environment entitlement"
**Solution:** Add `aps-environment` key to `playground.entitlements` file.

### Issue: Firebase crash on startup
**Solution:** Ensure `GoogleService-Info.plist` exists in `playground/Resources/` and is properly configured.

### Issue: SDK loading screen appears
**Solution:** Ensure `MealRepository` initialization is synchronous (fast operation).

## Key Patterns to Follow

1. **SDK Initialization:** Always synchronous in `init()`, never async
2. **Subscription Checks:** Use `async let` pattern with 1-second delay, exactly like translate app
3. **Environment:** Use `@Environment(TheSDK.self)` directly, not custom environment keys
4. **Paywall Presentation:** Use `.fullScreenCover(item:)` with `SDKView`
5. **Config:** Always use `Config.baseURL` from `Config.swift`, never hardcode URLs

## Notes

- The SDK package is from: `https://git-codecommit.us-east-1.amazonaws.com/v1/repos/Ios-Bundle`
- Match the translate app's patterns exactly - it's the reference implementation
- Server-side configuration is critical - client code is correct but won't work without proper server setup

