//
//  QuestionStepBody.swift
//  playground
//
//  Created by OpenCode on 21/12/2025.
//

import SwiftUI

struct QuestionStepBody: View {
    let step: OnboardingStep
    @ObservedObject var store: OnboardingStore
    @ObservedObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        guard let input = step.input else {
            return AnyView(Text(localizationManager.localizedString(for: AppStrings.Onboarding.missingInputDefinition)).foregroundStyle(.secondary))
        }

        switch input.type {
        case .single_select:
            return AnyView(SingleSelectView(
                title: nil,
                options: input.options ?? [],
                selection: Binding(
                    get: {
                        if case .string(let s) = store.stepAnswer(stepID: step.id) { return s }
                        return ""
                    },
                    set: { store.setStepAnswer(stepID: step.id, value: .string($0)) }
                )
            ))

        case .multi_select:
            return AnyView(MultiSelectView(
                options: input.options ?? [],
                selected: Binding(
                    get: {
                        if case .array(let arr) = store.stepAnswer(stepID: step.id) {
                            return Set(arr.compactMap {
                                if case .string(let s) = $0 { return s }
                                return nil
                            })
                        }
                        return []
                    },
                    set: { newSet in
                        store.setStepAnswer(stepID: step.id, value: .array(newSet.sorted().map { .string($0) }))
                    }
                )
            ))

        case .text:
            return AnyView(TextEntryView(
                placeholder: input.placeholder ?? "",
                text: Binding(
                    get: {
                        if case .string(let s) = store.stepAnswer(stepID: step.id) { return s }
                        return ""
                    },
                    set: { store.setStepAnswer(stepID: step.id, value: .string($0)) }
                )
            ))

        case .number:
            // For integer ranges, use picker wheel
            if let min = input.min, let max = input.max, let stepSize = input.step,
               stepSize >= 1.0 && min.truncatingRemainder(dividingBy: 1) == 0 && max.truncatingRemainder(dividingBy: 1) == 0 {
                return AnyView(IntegerPickerView(
                    min: Int(min),
                    max: Int(max),
                    step: Int(stepSize),
                    unit: input.unit,
                    value: Binding(
                        get: {
                            if case .double(let d) = store.stepAnswer(stepID: self.step.id) { return Int(d) }
                            return Int((min + max) / 2)
                        },
                        set: { store.setStepAnswer(stepID: self.step.id, value: .double(Double($0))) }
                    )
                ))
            } else {
                // question-level number (no unit UI)
                return AnyView(NumberEntryView(
                    placeholder: input.placeholder ?? "",
                    unitText: input.unit,
                    initialText: {
                        if case .double(let d) = store.stepAnswer(stepID: self.step.id) { return trimDouble(d) }
                        return ""
                    }(),
                    onChanged: { parsed in
                        store.setStepAnswer(stepID: self.step.id, value: parsed)
                    }
                ))
            }

        case .date:
            return AnyView(DatePickerView(
                date: Binding(
                    get: {
                        if case .date(let d) = store.stepAnswer(stepID: step.id) { return d }
                        // reasonable default
                        return Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
                    },
                    set: { store.setStepAnswer(stepID: step.id, value: .date($0)) }
                )
            ))

        case .slider:
            let minV = input.min ?? 0
            let maxV = input.max ?? 1
            let stepV = input.step ?? 0.1
            let unit = input.unit

            return AnyView(SliderQuestionView(
                min: minV,
                max: maxV,
                step: stepV,
                unit: unit,
                value: Binding(
                    get: {
                        if case .double(let d) = store.stepAnswer(stepID: step.id) { return d }
                        return (minV + maxV) / 2
                    },
                    set: { store.setStepAnswer(stepID: step.id, value: .double($0)) }
                )
            ))

        case .toggle:
            return AnyView(ToggleQuestionView(
                isOn: Binding(
                    get: {
                        if case .bool(let b) = store.stepAnswer(stepID: step.id) { return b }
                        return false
                    },
                    set: { store.setStepAnswer(stepID: step.id, value: .bool($0)) }
                )
            ))
        }
    }
}

private func trimDouble(_ d: Double) -> String {
    if abs(d.rounded() - d) < 0.000001 { return "\(Int(d.rounded()))" }
    return String(d)
}

#Preview {
    QuestionStepBody(
        step: OnboardingStep(
            id: "gender",
            type: .question,
            title: "What is your gender?",
            description: nil,
            next: nil,
            fields: nil,
            input: OnboardingInput(
                type: .single_select,
                options: ["Male", "Female", "Other"],
                placeholder: nil,
                min: nil,
                max: nil,
                step: nil,
                unit: nil,
                unitOptions: nil,
                defaultUnit: nil
            ),
            optional: false,
            permission: nil,
            primaryButton: nil
        ),
        store: OnboardingStore()
    )
    .padding()
}
