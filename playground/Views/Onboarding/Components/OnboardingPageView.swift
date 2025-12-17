//
//  OnboardingPageView.swift
//  playground
//
//  Onboarding view - Individual page view
//

import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            pageIcon
            titleSection
            Spacer()
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Private Views
    
    private var pageIcon: some View {
        Image(systemName: page.icon)
            .font(.system(size: 80))
            .foregroundStyle(gradientStyle)
            .padding(.bottom, 20)
    }
    
    private var gradientStyle: LinearGradient {
        .linearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var titleSection: some View {
        VStack(spacing: 16) {
            titleText
            descriptionText
        }
    }
    
    private var titleText: some View {
        Text(page.title)
            .font(.largeTitle)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
    }
    
    private var descriptionText: some View {
        Text(page.description)
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }
}
