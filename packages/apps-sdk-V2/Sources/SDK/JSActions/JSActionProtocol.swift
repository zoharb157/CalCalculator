//
//  JSAction.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 15/07/2024.
//

import Foundation

protocol JSActionProtocol {
//    associatedtype T
    func perform(parameters: [String: Any]) async throws -> [String: Any]?
}

