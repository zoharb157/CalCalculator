

//
// A simplified implementation of https://gist.github.com/sturdysturge/e5163a9e95826adbeff9824d5aa1d111
// Which has an associated article here: https://betterprogramming.pub/build-a-secure-swiftui-property-wrapper-for-the-keychain-e0f8e39d554b
// Requires the Keychain Access package: https://github.com/kishikawakatsumi/KeychainAccess
//

import KeychainAccess
import SwiftUI

@propertyWrapper
struct SDKKeychainStorage<Value: Codable>: DynamicProperty {
    // Use a specific service identifier to ensure data isolation and persistence
    // NOT synchronizable - non-synced keychain items persist better across app reinstalls on iOS
    // Using .afterFirstUnlockThisDeviceOnly for maximum persistence on device
    private let keychain = Keychain(service: "com.maven.sdk.persistent")
        .synchronizable(false)
        .accessibility(.afterFirstUnlockThisDeviceOnly)

    // Legacy keychain for migration purposes (includes old synchronizable keychain)
    private let legacyKeychain = Keychain()
    
    // Also check the old synchronizable keychain for migration
    private let oldSyncKeychain = Keychain(service: "com.maven.sdk.persistent")
        .synchronizable(true)
        .accessibility(.afterFirstUnlock)

    private let valueKey: String
    @State private var value: Value?

    init(wrappedValue defaultValue: Value? = nil, _ key: String) {
        valueKey = key

        do {
            // First, try to read from the new persistent keychain
            if let data = try keychain.getData(key) {
                _value = try State(initialValue: JSONDecoder().decode(Value.self, from: data))
                print("🔐 SDKKeychainStorage: Retrieved '\(key)' from persistent keychain")
            }
            // Check old synchronizable keychain for migration
            else if let oldSyncData = try oldSyncKeychain.getData(key) {
                let migratedValue = try JSONDecoder().decode(Value.self, from: oldSyncData)
                _value = State(initialValue: migratedValue)
                
                // Migrate to new persistent keychain
                try keychain.set(oldSyncData, key: key)
                
                // Remove from old sync keychain
                try? oldSyncKeychain.remove(key)
                
                print("🔐 SDKKeychainStorage: Migrated '\(key)' from sync keychain to persistent keychain")
            }
            // Check legacy keychain (no service identifier) for migration
            else if let legacyData = try legacyKeychain.getData(key) {
                let migratedValue = try JSONDecoder().decode(Value.self, from: legacyData)
                _value = State(initialValue: migratedValue)

                // Migrate to new persistent keychain
                try keychain.set(legacyData, key: key)

                // Remove from legacy keychain after successful migration
                try? legacyKeychain.remove(key)

                print("🔐 SDKKeychainStorage: Migrated '\(key)' from legacy keychain to persistent keychain")
            } else {
                // No data in any keychain, use default (new user)
                _value = State(initialValue: defaultValue)
                print("🔐 SDKKeychainStorage: No existing data for '\(key)', new user")
            }
        } catch {
            // Log error instead of crashing - ensures app continues even if keychain has issues
            print("🔐 SDKKeychainStorage: Error reading/migrating key '\(key)': \(error)")
            _value = State(initialValue: defaultValue)
        }
    }

    var wrappedValue: Value? {
        get {
            return value
        }
        nonmutating set {
            value = newValue

            do {
                if let storeValue = newValue {
                    try keychain.set(JSONEncoder().encode(storeValue), key: valueKey)
                    print("🔐 SDKKeychainStorage: Saved '\(valueKey)' to persistent keychain")
                } else {
                    try keychain.remove(valueKey)
                    print("🔐 SDKKeychainStorage: Removed '\(valueKey)' from keychain")
                }
            } catch {
                // Log error instead of crashing - ensures data persistence even with temporary keychain issues
                print("🔐 SDKKeychainStorage: Error writing key '\(valueKey)': \(error)")
            }
        }
    }

    var projectedValue: Binding<Value?> {
        return Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
