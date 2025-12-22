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
    
    var body: some View {
        Button(action: action) {
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
        FloatingMenuButton(icon: "camera.fill", title: "Scan food", color: .purple, isPremium: true) {}
        FloatingMenuButton(icon: "dumbbell.fill", title: "Log exercise", color: .blue) {}
    }
}

