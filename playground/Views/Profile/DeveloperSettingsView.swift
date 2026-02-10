//
//  DeveloperSettingsView.swift
//  playground
//

import SwiftUI
import SDK

struct DeveloperSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TheSDK.self) private var sdk
    @ObservedObject private var devManager = DeveloperModeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showCopiedToast = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    userInfoSection
                    developerModeSection
                    
                    if devManager.isDevModeEnabled {
                        premiumOverrideSection
                        dangerZoneSection
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(localizationManager.localizedString(for: "Developer Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert(localizationManager.localizedString(for: "Delete All Data?"), isPresented: $showDeleteConfirmation) {
                Button(localizationManager.localizedString(for: AppStrings.Common.cancel), role: .cancel) { }
                Button(localizationManager.localizedString(for: "Delete Everything"), role: .destructive) {
                    performDataDeletion()
                }
            } message: {
                Text(localizationManager.localizedString(for: "This will permanently delete all your data including meals, exercises, weight history, and settings. The app will restart from the welcome screen. This action cannot be undone."))
            }
            .overlay {
                if showCopiedToast {
                    copiedToastView
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            
            Text(localizationManager.localizedString(for: "Developer Mode"))
                .font(.title2)
                .fontWeight(.bold)
            
            Text(localizationManager.localizedString(for: "Debug and testing options for developers"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
    
    // MARK: - User Info Section
    
    @ViewBuilder
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(localizationManager.localizedString(for: "User Information"))
            
            VStack(spacing: 0) {
                HStack {
                    Label {
                        Text(localizationManager.localizedString(for: "User ID"))
                            .foregroundColor(.primary)
                    } icon: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Text(sdk.userId)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Button {
                        copyUserId()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Developer Mode Section
    
    @ViewBuilder
    private var developerModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(localizationManager.localizedString(for: "Developer Mode"))
            
            VStack(spacing: 0) {
                Toggle(isOn: $devManager.isDevModeEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localizationManager.localizedString(for: "Enable Developer Mode"))
                                .foregroundColor(.primary)
                            Text(localizationManager.localizedString(for: "Unlock debugging options"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.purple)
                    }
                }
                .tint(.purple)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Premium Override Section
    
    @ViewBuilder
    private var premiumOverrideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(localizationManager.localizedString(for: "Premium Status"))
            
            VStack(spacing: 0) {
                Toggle(isOn: $devManager.isPremiumOverrideEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localizationManager.localizedString(for: "Override Premium Status"))
                                .foregroundColor(.primary)
                            Text(localizationManager.localizedString(for: "Manually control subscription for testing"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.orange)
                    }
                }
                .tint(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                if devManager.isPremiumOverrideEnabled {
                    Divider()
                        .padding(.leading, 52)
                    
                    Toggle(isOn: $devManager.overriddenPremiumValue) {
                        Label {
                            HStack {
                                Text(localizationManager.localizedString(for: "Premium Unlocked"))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(devManager.overriddenPremiumValue 
                                     ? localizationManager.localizedString(for: "Premium")
                                     : localizationManager.localizedString(for: "Free"))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(devManager.overriddenPremiumValue ? .green : .orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(devManager.overriddenPremiumValue 
                                                  ? Color.green.opacity(0.15) 
                                                  : Color.orange.opacity(0.15))
                                    )
                            }
                        } icon: {
                            Image(systemName: devManager.overriddenPremiumValue ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .foregroundColor(devManager.overriddenPremiumValue ? .green : .red)
                        }
                    }
                    .tint(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .animation(.easeInOut(duration: 0.2), value: devManager.isPremiumOverrideEnabled)
        }
    }
    
    // MARK: - Danger Zone Section
    
    @ViewBuilder
    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(localizationManager.localizedString(for: "Danger Zone"))
            
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localizationManager.localizedString(for: "Delete All Data"))
                                .foregroundColor(.red)
                                .fontWeight(.medium)
                            Text(localizationManager.localizedString(for: "Reset app to initial state"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    if isDeleting {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .disabled(isDeleting)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }
    
    @ViewBuilder
    private var copiedToastView: some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(localizationManager.localizedString(for: "Copied to clipboard"))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            Spacer().frame(height: 60)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: showCopiedToast)
    }
    
    // MARK: - Actions
    
    private func copyUserId() {
        UIPasteboard.general.string = sdk.userId
        
        withAnimation {
            showCopiedToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
    
    private func performDataDeletion() {
        isDeleting = true
        
        Task {
            let success = await devManager.deleteAllUserData()
            
            await MainActor.run {
                isDeleting = false
                if success {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    DeveloperSettingsView()
}
