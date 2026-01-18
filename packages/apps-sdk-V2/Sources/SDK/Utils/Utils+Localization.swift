//
//  File.swift
//  SDK
//
//  Created by Dubon Ya'ar on 28/10/2025.
//

import Foundation

extension Utils {
    enum Localization {
        static func deviceIsRTL(lang: String) -> Bool {
            Foundation.Locale.Language(identifier: lang).characterDirection == .rightToLeft
        }
    }
}
