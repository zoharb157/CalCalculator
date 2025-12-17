//
//  MealNameSection.swift
//  playground
//
//  Results view - Editable meal name section
//

import SwiftUI

struct MealNameSection: View {
    @Binding var name: String
    @Binding var isEditing: Bool
    let onSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            contentView
        }
    }
    
    // MARK: - Private Views
    
    @ViewBuilder
    private var contentView: some View {
        if isEditing {
            editingView
        } else {
            displayView
        }
    }
    
    private var editingView: some View {
        TextField("Meal name", text: $name)
            .font(.title2)
            .fontWeight(.bold)
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                isEditing = false
                onSave()
            }
    }
    
    private var displayView: some View {
        HStack {
            Text(name)
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            editButton
        }
    }
    
    private var editButton: some View {
        Button {
            isEditing = true
        } label: {
            Image(systemName: "pencil.circle.fill")
                .font(.title3)
                .foregroundColor(.accentColor)
        }
    }
}
