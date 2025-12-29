//
//  WeightInputSheet.swift
//  playground
//
//  Sheet for entering new weight measurements
//

import SwiftUI

struct WeightInputSheet: View {
    let currentWeight: Double
    let unit: String
    let onSave: (Double) -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @Environment(\.dismiss) private var dismiss
    @State private var weightValue: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                }
                
                // Title
                VStack(spacing: 8) {
                    Text(localizationManager.localizedString(for: AppStrings.Weight.saveWeight))
                        .font(.title2)
                        .fontWeight(.bold)
                        .id("save-your-weight-\(localizationManager.currentLanguage)")
                    
                    Text(localizationManager.localizedString(for: AppStrings.Weight.trackProgress))
                        .id("track-progress-weight-\(localizationManager.currentLanguage)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Weight Input
                VStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("0.0", text: $weightValue)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .focused($isFocused)
                            .frame(maxWidth: 150)
                            .keyboardDoneButton()
                        
                        Text(unit)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(localizationManager.localizedString(for: AppStrings.Progress.previousWeight, arguments: String(format: "%.1f", currentWeight), unit))
                        .id("previous-weight-\(localizationManager.currentLanguage)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                // Save Button pinned to bottom
                Button {
                    if let weight = Double(weightValue), weight > 0 {
                        onSave(weight)
                        dismiss()
                    }
                } label: {
                    Text(localizationManager.localizedString(for: AppStrings.Progress.saveWeight))
                        .id("save-weight-btn-\(localizationManager.currentLanguage)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidWeight ? Color.blue : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isValidWeight)
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(Color(.systemGroupedBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            weightValue = String(format: "%.1f", currentWeight)
            // Focus immediately
            isFocused = true
        }
    }
    
    private var isValidWeight: Bool {
        guard let weight = Double(weightValue) else { return false }
        return weight > 0 && weight < 500
    }
}

#Preview {
    WeightInputSheet(
        currentWeight: 75.5,
        unit: "kg",
        onSave: { _ in }
    )
}
