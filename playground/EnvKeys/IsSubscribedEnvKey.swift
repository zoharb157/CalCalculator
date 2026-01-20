//
//  IsSubscribedEnvKey.swift
//  playground
//
//  Environment key for accessing subscription status throughout the app
//
//  NOTE: Temporarily set to true to make all features free (no paywall)
//  This bypasses all premium checks until payment integration is ready
//

import SwiftUI

extension EnvironmentValues {
    // TEMPORARY: All features are free - no premium gating
    @Entry var isSubscribed: Bool = true
}



