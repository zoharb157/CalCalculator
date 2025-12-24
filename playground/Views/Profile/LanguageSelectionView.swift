//
//  LanguageSelectionView.swift
//
//  Language selection modal using ProfileViewModel
//

import SwiftUI

struct LanguageSelectionView: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(ProfileViewModel.supportedLanguages, id: \.code) { language in
                    LanguageRow(
                        language: language,
                        isSelected: viewModel.selectedLanguage == language.name,
                        onSelect: {
                            viewModel.selectedLanguage = language.name
                            dismiss()
                        }
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Language")
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
