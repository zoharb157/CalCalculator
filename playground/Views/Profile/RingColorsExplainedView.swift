//
//  RingColorsExplainedView.swift
//
//  Ring Colors Explained screen
//

import SwiftUI

struct RingColorsExplainedView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Calendar Preview
                    CalendarPreviewCard()
                    
                    // Explanation
                    Text("On the homepage calendar, the colored rings around each date show how close you were to your daily calorie goal:")
                        .font(.body)
                        .padding(.horizontal)
                    
                    // Color Legend
                    VStack(alignment: .leading, spacing: 16) {
                        ColorLegendItem(
                            color: .green,
                            title: "Green",
                            description: "Up to 100 calories over your deficit target"
                        )
                        
                        ColorLegendItem(
                            color: .yellow,
                            title: "Yellow",
                            description: "100-200 calories over your goal"
                        )
                        
                        ColorLegendItem(
                            color: .red,
                            title: "Red",
                            description: "More than 200 calories over your goal"
                        )
                        
                        ColorLegendItem(
                            color: .gray,
                            title: "Dotted",
                            description: "No meals logged that day",
                            isDotted: true
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.ringColorsExplained))
                .id("ring-colors-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                        dismiss()
                    }
                    .id("done-ring-colors-\(localizationManager.currentLanguage)")
                }
            }
        }
    }
}

struct CalendarPreviewCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "apple.logo")
                Text("Cal AI")
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("15")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            .padding()
            
            // Days of week
            HStack {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            // Dates with rings
            HStack {
                DateRing(date: "10", color: .red, isDotted: false)
                DateRing(date: "11", color: .gray, isDotted: true)
                DateRing(date: "12", color: .green, isDotted: false)
                DateRing(date: "13", color: .black, isDotted: false, isSelected: true)
                DateRing(date: "14", color: .gray, isDotted: false)
                DateRing(date: "15", color: .gray, isDotted: false)
                DateRing(date: "16", color: .gray, isDotted: false)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct DateRing: View {
    let date: String
    let color: Color
    let isDotted: Bool
    var isSelected: Bool = false
    
    var body: some View {
        ZStack {
            if isDotted {
                Circle()
                    .strokeBorder(color, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .frame(width: 40, height: 40)
            } else {
                Circle()
                    .strokeBorder(color, lineWidth: isSelected ? 3 : 2)
                    .frame(width: 40, height: 40)
            }
            
            Text(date)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .primary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ColorLegendItem: View {
    let color: Color
    let title: String
    let description: String
    var isDotted: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            if isDotted {
                Circle()
                    .strokeBorder(color, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .frame(width: 24, height: 24)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    RingColorsExplainedView()
}

