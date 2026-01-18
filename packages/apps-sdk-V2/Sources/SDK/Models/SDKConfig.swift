//
//  File.swift
//  SDK
//
//  Created by Dubon Ya'ar on 05/11/2025.
//

import Foundation

public struct SDKConfig {
    public typealias FireBaseConfigType = (appId: String, appInstanceId: String, apiSecret: String)
    public typealias FacebookConfigType = String
    let domainURL: URL
    let firebase: FireBaseConfigType?
    let facebook: FacebookConfigType?
    let logOptions: LogOptions?
    let analyticvCallback: ((String, [String: Any]?) -> Void)?
    let apnsHandler: SDKNotificationHandler?
    let lang: String?

    public private(set) var jWTAuthHeader: JWTAuthHeader?

    public init(baseURL: URL,
                firebase: FireBaseConfigType? = nil,
                facebook: FacebookConfigType? = nil,
                logOptions: LogOptions? = LogOptions.all,
                lang: String? = nil,
                apnsHandler: SDKNotificationHandler? = nil,
                jWTAuthHeader: JWTAuthHeader? = nil,
                analyticvCallback: ((String, [String: Any]?) -> Void)? = nil)

    {
        domainURL = baseURL
        self.firebase = firebase
        self.facebook = facebook
        self.logOptions = logOptions
        self.apnsHandler = apnsHandler
        self.jWTAuthHeader = jWTAuthHeader
        self.analyticvCallback = analyticvCallback
        self.lang = lang
    }
}
