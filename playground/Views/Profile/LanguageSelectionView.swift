//
//  LanguageSelectionView.swift
//
//  Language selection modal using ProfileViewModel
//

import SwiftUI

struct LanguageSelectionView: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            List {
                ForEach(ProfileViewModel.supportedLanguages, id: \.code) { language in
                    LanguageRow(
                        language: language,
                        isSelected: viewModel.selectedLanguage == language.name,
                        onSelect: {
                            // Update language immediately
                            viewModel.selectedLanguage = language.name
                            
                            // Close the sheet after language change with a small delay
                            // This ensures the language change is processed before dismissing
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                                dismiss()
                            }
                        }
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.selectLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Language Row

private struct LanguageRow: View {
    let language: (name: String, flag: String, code: String)
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Flag emoji from country code
                Text(flagEmoji(from: language.flag))
                    .font(.title2)
                
                Text(language.name)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    /// Convert country code to flag emoji
    private func flagEmoji(from countryCode: String) -> String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let flagScalar = UnicodeScalar(base + scalar.value) {
                emoji.append(String(flagScalar))
            }
        }
        return emoji
    }
}

#Preview {
    LanguageSelectionView(viewModel: ProfileViewModel())
}
