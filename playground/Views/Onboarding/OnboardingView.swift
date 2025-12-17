//
//  OnboardingView.swift
//  playground
//
//  CalAI Clone - Onboarding flow
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    private var settings = UserSettings.shared
    @State private var currentPage = 0
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "camera.viewfinder",
            title: "Photo-Based Tracking",
            description: "Simply take a photo of your meal and let AI analyze the calories and macros automatically."
        ),
        OnboardingPage(
            icon: "chart.pie.fill",
            title: "Track Your Macros",
            description: "Set personalized goals for protein, carbs, and fat. Monitor your daily intake with ease."
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            title: "Your Data is Private",
            description: "All your data stays on your device. We prioritize your privacy and security."
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            pageContent
            pageIndicators
            continueButton
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Private Views
    
    private var pageContent: some View {
        TabView(selection: $currentPage) {
            pagesForEach
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: currentPage)
    }
    
    private var pagesForEach: some View {
        ForEach(0..<pages.count, id: \.self) { index in
            OnboardingPageView(page: pages[index])
                .tag(index)
        }
    }
    
    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: currentPage)
            }
        }
        .padding(.bottom, 32)
    }
    
    private var continueButton: some View {
        Button(action: handleContinue) {
            Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private func handleContinue() {
        HapticManager.shared.impact(.light)
        
        if currentPage < pages.count - 1 {
            withAnimation {
                currentPage += 1
            }
        } else {
            settings.completeOnboarding()
            isPresented = false
        }
    }
}

// MARK: - Supporting Types

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

#Preview {
    @Previewable @State var isPresented = true
    OnboardingView(isPresented: $isPresented)
}
