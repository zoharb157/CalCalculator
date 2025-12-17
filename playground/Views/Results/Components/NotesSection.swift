//
//  NotesSection.swift
//  playground
//
//  Results view - Notes section
//

import SwiftUI

struct NotesSection: View {
    let notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        Label("Notes", systemImage: "info.circle")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    
    private var notesText: some View {
        Text(notes)
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
}
