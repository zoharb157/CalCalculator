//
//  RateUsView.swift
//  playground
//
//  Rate Us screen for App Store rating
//

import SwiftUI
import StoreKit

struct RateUsView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "star.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                        .padding(.top, 40)
                    
                    // Title
                    Text(localizationManager.localizedString(for: AppStrings.Profile.rateUs))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Description
                    Text(localizationManager.localizedString(for: AppStrings.Profile.rateUsDescription))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    // Rate Button
                    Button {
                        rateApp()
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                            Text(localizationManager.localizedString(for: AppStrings.Profile.rateUs))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.rateUs))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.close)) {
                        Pixel.track("rate_us_dismissed", type: .engagement)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func rateApp() {
        Pixel.track("rate_us_tapped", type: .engagement)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
        dismiss()
    }
}

#Preview {
    RateUsView()
}
