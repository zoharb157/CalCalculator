//
//  CaloriesCalculatorWidgetsExtensionBundle.swift
//  CaloriesCalculatorWidgetsExtension
//
//  Widget bundle entry point
//

import WidgetKit
import SwiftUI

@main
struct CaloriesCalculatorWidgetsExtensionBundle: WidgetBundle {
    var body: some Widget {
        CaloriesWidget()
        if #available(iOS 16.0, *) {
            WeightWidget()
        }
    }
}
