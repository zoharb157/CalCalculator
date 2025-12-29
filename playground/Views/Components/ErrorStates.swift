//
//  ErrorStates.swift
//  playground
//
//  Reusable error state components
//

import SwiftUI

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let action: (() -> Void)?
    let dismiss: (() -> Void)?
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    init(message: String, action: (() -> Void)? = nil, dismiss: (() -> Void)? = nil) {
        self.message = message
        self.action = action
        self.dismiss = dismiss
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            if let action = action {
                Button(action: action) {
                    Text(localizationManager.localizedString(for: AppStrings.Common.retry))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .id("retry-btn-\(localizationManager.currentLanguage)")
                }
            }
            
            if let dismiss = dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Full Screen Error

struct FullScreenErrorView: View {
    let error: Error
    let retry: (() -> Void)?
    let dismiss: (() -> Void)?
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text(localizationManager.localizedString(for: AppStrings.Common.somethingWentWrong))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .id("something-wrong-\(localizationManager.currentLanguage)")
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if let retry = retry {
                Button(action: retry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(localizationManager.localizedString(for: AppStrings.Common.tryAgain))
                            .id("try-again-fullscreen-\(localizationManager.currentLanguage)")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
            }
            
            if let dismiss = dismiss {
                Button(action: dismiss) {
                    Text(localizationManager.localizedString(for: AppStrings.Common.dismiss))
                        .id("dismiss-\(localizationManager.currentLanguage)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Inline Error

struct InlineErrorView: View {
    let message: String
    let retry: (() -> Void)?
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if let retry = retry {
                Button(action: retry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(self.localizationManager.localizedString(for: AppStrings.Common.retry))
                            .id("retry-fullscreen-\(self.localizationManager.currentLanguage)")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}


