//
//  OnboardingPickerViews.swift
//  playground
//
//  Created by OpenCode on 21/12/2025.
//

import SwiftUI

// MARK: - Date Picker View
struct DatePickerView: View {
    @Binding var date: Date
    
    var body: some View {
        DatePicker("", selection: $date, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .padding(16)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Integer Picker View
struct IntegerPickerView: View {
    let min: Int
    let max: Int
    let step: Int
    let unit: String?
    @Binding var value: Int
    
    var values: [Int] {
        Array(stride(from: min, through: max, by: step))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Display current value
            HStack(spacing: 8) {
                Text("\(value)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                if let unit {
                    Text(unit)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            
            // Picker wheel
            Picker("", selection: $value) {
                ForEach(values, id: \.self) { val in
                    Text("\(val)").tag(val)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            .clipped()
        }
    }
}

// MARK: - Slider Question View
struct SliderQuestionView: View {
    let min: Double
    let max: Double
    let step: Double
    let unit: String?
    @Binding var value: Double

    var body: some View {
        VStack(spacing: 20) {
            // Display value
            HStack(spacing: 8) {
                Text(displayValue(value))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                if let unit {
                    Text(unit)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)

            // Slider
            VStack(spacing: 8) {
                Slider(value: Binding(
                    get: { value },
                    set: { newVal in
                        // snap to step
                        let snapped = (newVal / step).rounded() * step
                        value = Swift.min(Swift.max(snapped, self.min), self.max)
                    }
                ), in: min...max)
                .tint(.accentColor)
                
                HStack {
                    Text("\(Int(min))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(max))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        }
    }

    private func displayValue(_ v: Double) -> String {
        // show fewer decimals when possible
        if abs(v.rounded() - v) < 0.000001 { return "\(Int(v.rounded()))" }
        return String(format: "%.2f", v)
    }
}

// MARK: - Toggle Question View
struct ToggleQuestionView: View {
    @Binding var isOn: Bool
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return HStack {
            Text(localizationManager.localizedString(for: AppStrings.Common.enabled))
                .id("enabled-toggle-\(localizationManager.currentLanguage)")
                .font(.headline)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(20)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Previews
#Preview("Date Picker") {
    DatePickerView(date: .constant(Date()))
        .padding()
}

#Preview("Integer Picker") {
    IntegerPickerView(
        min: 18,
        max: 100,
        step: 1,
        unit: "years",
        value: .constant(25)
    )
    .padding()
}

#Preview("Slider") {
    SliderQuestionView(
        min: 0,
        max: 100,
        step: 5,
        unit: "kg",
        value: .constant(70)
    )
    .padding()
}

#Preview("Toggle") {
    ToggleQuestionView(isOn: .constant(true))
        .padding()
}
