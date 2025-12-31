//
//  NotesSection.swift
//  playground
//
//  Results view - Notes section
//

import SwiftUI

struct NotesSection: View {
    let notes: String
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(alignment: .leading, spacing: 8) {
            headerLabel
            notesText
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Private Views
    
    private var headerLabel: some View {
        Label(localizationManager.localizedString(for: AppStrings.Results.notes), systemImage: "info.circle")
            .id("notes-label-\(localizationManager.currentLanguage)")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    
    private var notesText: some View {
        Text(notes)
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
}

// MARK: - Preview

#Preview {
    NotesSection(
        notes: "This meal is high in protein and perfect for post-workout recovery. Consider adding more vegetables for fiber."
    )
    .padding()
}
