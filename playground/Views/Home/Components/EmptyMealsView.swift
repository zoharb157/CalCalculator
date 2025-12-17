//
//  EmptyMealsView.swift
//  playground
//
//  Empty state view for meals
//

import SwiftUI

struct EmptyMealsView: View {
    var body: some View {
        VStack(spacing: 16) {
            emptyIcon
            titleText
            descriptionText
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Private Views
    
    private var emptyIcon: some View {
        Image(systemName: "fork.knife.circle")
            .font(.system(size: 60))
            .foregroundColor(.gray.opacity(0.5))
    }
    
    private var titleText: some View {
        Text("No meals yet")
            .font(.headline)
            .foregroundColor(.secondary)
    }
    
    private var descriptionText: some View {
        Text("Scan your first meal to start tracking")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
    }
}

#Preview("Empty State") {
    EmptyMealsView()
}
