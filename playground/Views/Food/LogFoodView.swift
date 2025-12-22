//
//  LogFoodView.swift
//
//  Log Food screen with search and suggestions
//

import SwiftUI

struct LogFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedTab: FoodTab = .all
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tabs
                HStack(spacing: 0) {
                    FoodTabButton(title: "All", isSelected: selectedTab == .all) {
                        selectedTab = .all
                    }
                    FoodTabButton(title: "My foods", isSelected: selectedTab == .myFoods) {
                        selectedTab = .myFoods
                    }
                    FoodTabButton(title: "My meals", isSelected: selectedTab == .myMeals) {
                        selectedTab = .myMeals
                    }
                    FoodTabButton(title: "Saved foods", isSelected: selectedTab == .savedFoods) {
                        selectedTab = .savedFoods
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Describe what you ate", text: $searchText)
                        .focused($isSearchFocused)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        if selectedTab == .savedFoods {
                            SavedFoodsContent()
                        } else {
                            // Suggestions
                            if !searchText.isEmpty {
                                SuggestionsSection()
                            } else {
                                SuggestionsSection()
                            }
                        }
                    }
                    .padding()
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    ActionButton(
                        icon: "list.bullet",
                        title: "Manual Add"
                    ) {
                        // Manual add
                    }
                    
                    ActionButton(
                        icon: "mic.fill",
                        title: "Voice Log"
                    ) {
                        // Voice log
                    }
                }
                .padding()
            }
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
}

enum FoodTab {
    case all
    case myFoods
    case myMeals
    case savedFoods
}

struct FoodTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                if isSelected {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct SuggestionsSection: View {
    let suggestions = [
        FoodSuggestion(name: "Peanut Butter", calories: 94, unit: "tbsp"),
        FoodSuggestion(name: "Avocado", calories: 130, unit: "serving")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggestions")
                .font(.headline)
                .padding(.horizontal, 4)
            
            ForEach(suggestions) { suggestion in
                FoodSuggestionRow(suggestion: suggestion)
            }
        }
    }
}

struct FoodSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let calories: Int
    let unit: String
}

struct FoodSuggestionRow: View {
    let suggestion: FoodSuggestion
    
    var body: some View {
        Button {
            // Add food
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text("\(suggestion.calories) cal")
                        Text("•")
                        Text(suggestion.unit)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .cornerRadius(12)
        }
    }
}

struct SavedFoodsContent: View {
    var body: some View {
        VStack(spacing: 16) {
            // Embedded card preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .rotationEffect(.degrees(-5))
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bookmark")
                        Text("9 AM")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    Text("Smoked Salmon Avocado Salad")
                        .font(.headline)
                    
                    HStack {
                        Button {
                            // Decrease
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        
                        Text("1")
                        
                        Button {
                            // Increase
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            
            VStack(spacing: 8) {
                Text("No saved foods yet")
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Image(systemName: "bookmark")
                    Text("Tap on any logged food to save here.")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    LogFoodView()
}

