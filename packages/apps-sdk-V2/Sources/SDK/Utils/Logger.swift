//
//  File.swift
//  SDK
//
//  Created by Dubon Ya'ar on 14/02/2025.
//

import Foundation

enum Logger {
    static var logFilters: LogOptions?

    static func log(level: LogOptions, _ items: Any...) {
        if logFilters?.contains(level) ?? false {
            print(items.map { String(describing: $0) }.joined(separator: ", "))
        }
    }
}
