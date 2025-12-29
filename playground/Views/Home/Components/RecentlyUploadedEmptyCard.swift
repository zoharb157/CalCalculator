//
//  RecentlyUploadedEmptyCard.swift
//  playground
//
//  Empty state card for recently uploaded section (matching reference design)
//

import SwiftUI

struct RecentlyUploadedEmptyCard: View {
    let onAddMeal: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onAddMeal) {
                HStack(spacing: 12) {
                    // Placeholder image (matching reference - salad bowl)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.title3)
                                .foregroundColor(.gray)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Placeholder lines (matching reference)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray4))
                            .frame(height: 12)
                            .frame(maxWidth: 150)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray4))
                            .frame(height: 12)
                            .frame(maxWidth: 100)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            
            // Text below card (matching reference)
            Text(localizationManager.localizedString(for: AppStrings.Home.tapToAddFirstMeal))
                .id("tap-add-first-meal-\(localizationManager.currentLanguage)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
    }
}

#Preview {
    RecentlyUploadedEmptyCard {
        print("Add meal tapped")
    }
    .padding()
}

