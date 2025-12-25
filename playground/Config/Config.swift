//
//  Config.swift
//  playground
//
//  Configuration constants for the app
//

import Foundation

enum Config {
    static let appId: String = "6738996117"
    static let baseURL: URL = .init(string: "https://app.caloriecount-ai.com")!
    static let termsURL: URL = .init(string: "https://caloriecount-ai.com/terms")!
    static let privacyURL: URL = .init(string: "https://caloriecount-ai.com/privacy")!
    static let eulaURL: URL = .init(string: "https://caloriecount-ai.com/eula")!
    static let supportURL: URL = .init(string: "https://caloriecount-ai.com/support")!
    static let mailTo: String = "info@caloriecount-ai.com"
    static let mailsubject: String = ""
    static let mailbody: String = "Hello! Here are some suggestions to enhance the app:"
    static let sentryDNS: String = "https://17c717a2646ca702fff364f1a8e7dafb@o4505877729116160.ingest.us.sentry.io/4509282019311616"
    static let groupUserDefaultIdentifier: String = "group.CalCalculatorAiPlaygournd.shared"
}

