//
//  FloatingMenuButton.swift
//
//  Floating menu button component
//

import SwiftUI

struct FloatingMenuButton: View {
    let icon: String
    let title: String
    let color: Color
    var isPremium: Bool = false
    let action: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 44, height: 44)
                    
                    if isPremium {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                            .offset(x: 16, y: -16)
                    }
                    
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
}

#Preview {
    VStack {
        FloatingMenuButton(icon: "camera.fill", title: LocalizationManager.shared.localizedString(for: AppStrings.Home.scanFood), color: .purple, isPremium: true) {}
        FloatingMenuButton(icon: "dumbbell.fill", title: LocalizationManager.shared.localizedString(for: AppStrings.Home.saveExercise), color: .blue) {}
    }
}

