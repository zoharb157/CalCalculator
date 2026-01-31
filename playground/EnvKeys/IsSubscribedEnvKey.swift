//
//  IsSubscribedEnvKey.swift
//  playground
//
//  Environment key for accessing subscription status throughout the app
//
//  NOTE: Default value is false - actual subscription status is injected
//  from playgroundApp.swift based on StoreKit verification or debug override
//

import SwiftUI

extension EnvironmentValues {
    // Default to false - actual status is injected via .environment(\.isSubscribed, subscriptionStatus)
    // from playgroundApp.swift which reads from StoreKit or debug override
    @Entry var isSubscribed: Bool = false
}



