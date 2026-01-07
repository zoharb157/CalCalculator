//
//  LoginView.swift
//  playground
//
//  Created by OpenCode on 21/12/2025.
//

import SwiftUI

struct LoginView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false
    
    var onGetStarted: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.1),
                    Color.accentColor.opacity(0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo and branding section
                VStack(spacing: 20) {
                    // App icon/logo
                    Image(.splashLogo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 20, x: 0, y: 10)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isAnimating)
                    
                    VStack(spacing: 8) {
                        Text(LocalizationManager.shared.localizedString(for: AppStrings.Authentication.calorieVisionAI))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                        
                        Text(LocalizationManager.shared.localizedString(for: AppStrings.Authentication.trackNutritionWithEase))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: isAnimating)
                }
                .padding(.bottom, 60)
                
                Spacer()
                
                // Action buttons section
                VStack(spacing: 16) {
                    // Primary button - Get Started
                    Button(action: onGetStarted) {
                        HStack(spacing: 12) {
                            Text(LocalizationManager.shared.localizedString(for: AppStrings.Authentication.getStarted))
                                .font(.system(size: 18, weight: .semibold))
                            
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: isAnimating)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// Custom button style for scale animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    LoginView(
        onGetStarted: { print("Get Started tapped") }
    )
}

#Preview("Dark Mode") {
    LoginView(
        onGetStarted: { print("Get Started tapped") }
    )
    .preferredColorScheme(.dark)
}
