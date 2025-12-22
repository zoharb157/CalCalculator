# Quick Implementation Checklist

Use this checklist to implement SDK integration and premium locking in your app.

## Phase 1: SDK Setup

- [ ] Create `Config.swift` with your app's URLs and IDs
- [ ] Create `AppDelegate.swift` for Facebook/Firebase initialization
- [ ] Add `GoogleService-Info.plist` (Firebase config)
- [ ] Update `playground.entitlements` - add `aps-environment`
- [ ] Update `playgroundApp.swift`:
  - [ ] Add imports (Firebase, FacebookCore, SDK)
  - [ ] Add `@UIApplicationDelegateAdaptor`
  - [ ] Initialize SDK in `init()` with `Config.baseURL`
  - [ ] Inject `sdk` and `isSubscribed` in environment
  - [ ] Add `onChange` observers for subscription status

## Phase 2: Subscription Management

- [ ] Create `IsSubscribedEnvKey.swift` (environment key)
- [ ] Update `UserSettings.swift`:
  - [ ] Add `debugOverrideSubscription` property
  - [ ] Add `debugIsSubscribed` property
  - [ ] Add UserDefaults keys
  - [ ] Load from UserDefaults in `init()`

## Phase 3: Lock UI Components

- [ ] Create/Update `LockedFeatureOverlay.swift`:
  - [ ] Add `PremiumLockedContent` component
  - [ ] Implement blur + gold Premium button
  - [ ] Add paywall presentation

## Phase 4: Feature Locking

- [ ] **HomeView**: Wrap `MacroCardsSection` with `PremiumLockedContent`
- [ ] **ProgressView**: 
  - [ ] Wrap `BMICard` with `PremiumLockedContent`
  - [ ] Wrap `DailyCaloriesCard` with `PremiumLockedContent`
  - [ ] Wrap `HealthDataSection` with `PremiumLockedContent`
  - [ ] Update card initializers (make `isSubscribed` optional)
  - [ ] Remove old lock icons/opacity from cards
- [ ] **ScanView**: 
  - [ ] Add subscription check in `handlePhotoSelection`
  - [ ] Add subscription check in `cameraSheet`
  - [ ] Add `fullScreenCover` for paywall

## Phase 5: Debug Tools

- [ ] **SettingsView**: Add debug section (DEBUG builds only):
  - [ ] Toggle for `debugOverrideSubscription`
  - [ ] Toggle for `debugIsSubscribed` (when override enabled)
  - [ ] Display actual SDK subscription status

## Phase 6: ContentView Updates

- [ ] Add `@Environment(TheSDK.self)` and `@Environment(\.isSubscribed)`
- [ ] Add subscription check in onboarding/sign-in states:
  ```swift
  Task {
      async let _ = Task.sleep(nanoseconds: 1_000_000_000)
      await sdk.updateIsSubscribed()
  }
  ```

## Testing

- [ ] Test with `isSubscribed = false` - verify blur + Premium button appears
- [ ] Test with `isSubscribed = true` - verify content is visible
- [ ] Test Premium button tap - opens paywall
- [ ] Test debug toggle - overrides subscription status
- [ ] Test scan feature - locks when taking/selecting photos
- [ ] Verify SDK initializes without blocking UI

## Key Files Reference

**Create:**
- `playground/Config/Config.swift`
- `playground/AppDelegate.swift`
- `playground/EnvKeys/IsSubscribedEnvKey.swift`
- `playground/Resources/GoogleService-Info.plist`

**Modify:**
- `playground/playgroundApp.swift`
- `playground/ContentView.swift`
- `playground/Models/UserSettings.swift`
- `playground/Views/Home/HomeView.swift`
- `playground/Views/Progress/ProgressView.swift`
- `playground/Views/Scan/ScanView.swift`
- `playground/Views/Settings/SettingsView.swift`
- `playground/Views/Components/LockedFeatureOverlay.swift`
- `playground/playground.entitlements`

---

**See `SDK_AND_LOCK_UI_IMPLEMENTATION_GUIDE.md` for detailed code examples.**

