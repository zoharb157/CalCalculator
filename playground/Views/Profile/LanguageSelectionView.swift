//
//  LanguageSelectionView.swift
//
//  Language selection modal
//

import SwiftUI

struct LanguageSelectionView: View {
    @State private var profile = UserProfile.shared
    @Environment(\.dismiss) private var dismiss
    
    let languages: [(name: String, flag: String, code: String)] = [
        ("English", "🇺🇸", "en"),
        ("中国人", "🇨🇳", "zh"),
        ("हिन्दी", "🇮🇳", "hi"),
        ("Español", "🇪🇸", "es"),
        ("Français", "🇫🇷", "fr"),
        ("Deutsch", "🇩🇪", "de"),
        ("Русский", "🇷🇺", "ru"),
        ("Português", "🇧🇷", "pt"),
        ("Italiano", "🇮🇹", "it"),
        ("Română", "🇷🇴", "ro"),
        ("Azərbaycanca", "🇦🇿", "az"),
        ("Nederlands", "🇳🇱", "nl")
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(languages, id: \.code) { language in
                    Button {
                        profile.selectedLanguage = language.name
                        dismiss()
                    } label: {
                        HStack {
                            Text(language.flag)
                                .font(.title2)
                            
                            Text(language.name)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if profile.selectedLanguage == language.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    LanguageSelectionView()
}

