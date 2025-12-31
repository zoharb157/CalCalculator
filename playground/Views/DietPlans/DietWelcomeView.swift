//
//  DietWelcomeView.swift
//  playground
//
//  Welcome pop-up explaining the diet feature
//

import SwiftUI

struct DietWelcomeView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // Content
                TabView(selection: $currentPage) {
                    welcomePage1
                        .tag(0)
                    
                    welcomePage2
                        .tag(1)
                    
                    welcomePage3
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button(localizationManager.localizedString(for: AppStrings.Common.previous)) {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    if currentPage < 2 {
                        Button(localizationManager.localizedString(for: AppStrings.Common.next)) {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(localizationManager.localizedString(for: AppStrings.Onboarding.getStarted)) {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 20)
            .padding(.vertical, 40)
        }
    }
    
    private var welcomePage1: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.welcomeToDietPlans))
                .font(.title)
                .fontWeight(.bold)
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.createPersonalizedMealSchedules))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 40)
    }
    
    private var welcomePage2: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange.gradient)
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.smartReminders))
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "clock.fill",
                    text: "Get notified when it's time to eat"
                )
                
                FeatureRow(
                    icon: "checkmark.circle.fill",
                    text: "Track which meals you completed"
                )
                
                FeatureRow(
                    icon: "chart.bar.fill",
                    text: "See your adherence progress"
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 40)
    }
    
    private var welcomePage3: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 80))
                .foregroundStyle(.green.gradient)
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.trackYourProgress))
                .font(.title)
                .fontWeight(.bold)
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.monitorDietAdherence))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.dailyAdherenceTracking))
                        .font(.subheadline)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.weeklyProgressCharts))
                        .font(.subheadline)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.personalizedInsights))
                        .font(.subheadline)
                    Spacer()
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 40)
    }
    
    private func dismiss() {
        withAnimation {
            isPresented = false
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    DietWelcomeView(isPresented: .constant(true))
}


