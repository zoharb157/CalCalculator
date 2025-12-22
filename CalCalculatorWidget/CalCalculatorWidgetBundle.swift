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
        CalCalculatorWidget()
        CalCalculatorWidgetControl()
        CalCalculatorWidgetLiveActivity()
    }
}
