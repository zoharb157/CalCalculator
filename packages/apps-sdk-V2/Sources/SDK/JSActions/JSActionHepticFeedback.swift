
//  JSActionSetCID.swift
//  QRFun
//
//  Created by Dubon Ya'ar on 15/07/2024.
//

import Foundation
import SwiftUI

struct JSActionHepticFeedback: JSActionProtocol {
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        let styleString = parameters["style"] as? String ?? "medium"
        let repeats: Int = parameters["repeats"] as? Int ?? 1

        var style: UIImpactFeedbackGenerator.FeedbackStyle!

        switch styleString {
        case "medium":
            style = .medium
        case "light":
            style = .light
        case "heavy":
            style = .heavy
        case "rigid":
            style = .rigid
        case "soft":
            style = .soft
        default:
            style = .heavy
        }

        // await MainActor.run {
        let impactFeedbackGenerator = await UIImpactFeedbackGenerator(style: style)
        await impactFeedbackGenerator.prepare()
        await impactFeedbackGenerator.impactOccurred(intensity: 1.0)

        if repeats > 1 {
            Task.detached {
                for _ in 0 ..< repeats - 1 {
                    try await Task.sleep(nanoseconds: 1000000000 / 50)
                    await impactFeedbackGenerator.impactOccurred(intensity: 1.0)
                }
            }
        }

        return nil
    }
}
