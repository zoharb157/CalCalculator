//
//  KeyboardToolbar.swift
//  playground
//
//  Helper view for adding Done button to number pad keyboards
//

import SwiftUI

extension View {
    /// Adds a Done button toolbar to number pad keyboards
    func keyboardDoneButton() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(LocalizationManager.shared.localizedString(for: AppStrings.Common.done)) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .accessibilityLabel(LocalizationManager.shared.localizedString(for: AppStrings.Common.dismissKeyboard))
            }
        }
    }
}

