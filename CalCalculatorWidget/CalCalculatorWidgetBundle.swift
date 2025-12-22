//
//  CalCalculatorWidgetBundle.swift
//  CalCalculatorWidget
//
//  Created by Bassam-Hillo on 22/12/2025.
//

import WidgetKit
import SwiftUI

@main
struct CalCalculatorWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Main home screen widgets
        CalCalculatorWidget()
        CaloriesSmallWidget()
        MacrosMediumWidget()
        WeeklyLargeWidget()
        QuickLogWidget()
        CompactMacrosWidget()
        
        // Control center widget
        CalCalculatorWidgetControl()
    }
}
