//
//  JSActionGetProducts.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 15/07/2024.
//

import Foundation

struct JSActionGetProducts: JSActionProtocol {
    weak var model: TheSDK?

    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        guard let model else {
            throw SDKError.generic
        }

        guard let list = parameters["productIdList"] as? [String] else {
            throw SDKError.withReason("missing parameter productIdList of string array type")
        }

        async let getProductsTask = API.IAP.fetchProducs(productIdList: list)
        async let getProductQuantity = API.Maven.getProductQuantities(userId: model.userId,
                                                                      sessionId: SDKStore.sessionId,
                                                                      baseURL: model.config.domainURL,
                                                                      installTime: SDKStore.lastInstallTime)

        let getProductsResult = try await getProductsTask
        let getQuantityResult = try? await getProductQuantity

        var stringified = getProductsResult
            .map { $0.jsonRepresentation }
            .compactMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }

        if let getQuantityResult {
            stringified = stringified.map {
                var item = $0
                if var attributes = item["attributes"] as? [String: Any] {
                    if let productName = attributes["offerName"] as? String,
                       let quantity = getQuantityResult[productName] {
                        attributes["quantity"] = quantity
                    }
                    item["attributes"] = attributes
                }
                return item
            }
        }

        return ["programs": stringified]
    }
}
