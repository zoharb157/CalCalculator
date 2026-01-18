//
//  File.swift
//  SDK
//
//  Created by Dubon Ya'ar on 05/11/2025.
//

import Foundation

public extension TheSDK {
    @discardableResult
    func action(event: JSEventWrapper) async throws -> [String: Any]? {
        Logger.log(level: .native, "🤪 js call", event.name)

        var result: [String: Any]?


        switch event.name {
        case "hello":
            result = try await JSActionHello().perform(parameters: event.parameters)

        case "initializeFirebase":
            result = try await JSActionInitFirebase(sdk: self).perform(parameters: event.parameters)

        case "initializeFacebook":
            result = try await JSActionInitFacebook(sdk: self).perform(parameters: event.parameters)

        case "firebaseEvent":
            result = try await JSActionFirebaseEvent(model: self).perform(parameters: event.parameters)

        case "getGalleryAuthStatus":
            result = try await JSActionGetGalleryAuthStatus().perform(parameters: event.parameters)

        case "authGallery":
            result = try await JSActionAuthGallery().perform(parameters: event.parameters)

        case "getCameraAuthStatus":
            result = try await JSActionGetCameraAuthStatus().perform(parameters: event.parameters)

        case "authCamera":
            result = try await JSActionAuthCamera().perform(parameters: event.parameters)

        case "getLocationAuthStatus":
            result = try await JSActionGetLocationAuthStatus().perform(parameters: event.parameters)

        case "authLocation":
            result = try await JSActionAuthLocation().perform(parameters: event.parameters)

        case "getPersistentValue":
            result = try await JSActionGetPersistantValue().perform(parameters: event.parameters)

        case "setPersistentValue":
            result = try await JSActionSetPersistantValue().perform(parameters: event.parameters)

        case "getSubscriptionStatus":
            result = try await JSActionGetSubscriptionStatus().perform(parameters: event.parameters)

        case "hepticFeedback":
            result = try await JSActionHepticFeedback().perform(parameters: event.parameters)

        case "requestNotifications":
            result = try await JSActionPresentAPNDialog(model: self).perform(parameters: event.parameters)

        case "windowLoad":
            result = try await JSActionsWindowLoad(model: self).perform(parameters: event.parameters)

        case "getAppleTrancperancyStatus":
            result = try await JSActionshowGetTrancperancyStatus().perform(parameters: event.parameters)

        case "showAppleTrancperancyDialog":
            result = try await JSActionshowAppleTransperacnyDialog(model: self).perform(parameters: event.parameters)

        case "facebookEvent":
            result = try await JSActionFacebookEvent(model: self).perform(parameters: event.parameters)

        case "sendFacebookPixel":
            result = try await JSActionSendFacebookPixel(model: self).perform(parameters: event.parameters)

        case "analyticsEvent":
            result = try await JSActionAnalyticsEvent(model: self).perform(parameters: event.parameters)

        case "dismiss":
            showSDK?.wrappedValue = false
            showSDK = nil
            result = event.parameters

        case "getProducts":
            result = try await JSActionGetProducts(model: self).perform(parameters: event.parameters)

        case "buyProduct":
            result = try await JSActionBuyProduct(model: self).perform(parameters: event.parameters)

        case "setCId":
            result = try await JSActionSetCID().perform(parameters: event.parameters)

        case "getCId":
            result = try await JSActionGetCID().perform(parameters: event.parameters)

        case "getAPNToken":
            result = try await JSActionGetAPNToken(model: self).perform(parameters: event.parameters)

        case "getUserId":
            result = try await JSActionGetUserId(model: self).perform(parameters: event.parameters)

        case "getIsSubscribed":
            result = try await JSActionGetIsSubscribed(model: self).perform(parameters: event.parameters)

        case "setIsSubscribed":
            result = try await JSActionSetIsSubscribed(model: self).perform(parameters: event.parameters)

        case "canOpenSchema":
            result = try await JSActionCanOpenSchema().perform(parameters: event.parameters)

        case "log":
            result = try await JSActionLog(config: config).perform(parameters: event.parameters)

        case "showDialog":
            result = try await JSActionPresentDialog().perform(parameters: event.parameters)

        case "resturePurchases":
            result = try await JSActionRestorePurchases(model: self).perform(parameters: event.parameters)

        case "syncTransactions":
            result = try await JSActionSyncTransactions(model: self).perform(parameters: event.parameters)

        default: break
        }

        Logger.log(level: .native, "⬇️ sending reply", event.name)

        send(event: .init(id: event.id, name: event.name, parameters: result ?? [:]))

        return result
    }
}
