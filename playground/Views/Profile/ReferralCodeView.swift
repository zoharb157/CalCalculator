//
//  ReferralCodeView.swift
//  playground
//
//  Referral code page for sharing and applying friend codes
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ReferralCodeView: View {
    
    // MARK: - State
    
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ProfileViewModel()
    @State private var friendCode: String = ""
    @State private var showCopiedAlert = false
    @State private var showAppliedAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var appliedFriendCode: String = UserDefaults.standard.string(forKey: "appliedFriendCode") ?? ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    yourCodeSection
                    applyCodeSection
                    
                    if !appliedFriendCode.isEmpty {
                        appliedCodeSection
                    }
                    
                    howItWorksSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Referral Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Copied!", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your referral code has been copied to clipboard.")
        }
        .alert("Success!", isPresented: $showAppliedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Friend's referral code has been applied successfully.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Invite Friends & Earn Rewards")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Share your unique code with friends and both of you will receive special benefits!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Your Code Section
    
    @ViewBuilder
    private var yourCodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Referral Code")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Code display
                HStack {
                    Text(viewModel.promoCode)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .tracking(4)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                
                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        copyCode()
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                    
                    Button {
                        shareCode()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Apply Code Section
    
    @ViewBuilder
    private var applyCodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Have a Friend's Code?")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                TextField("Enter referral code", text: $friendCode)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(10)
                
                Button {
                    applyFriendCode()
                } label: {
                    Text("Apply Code")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            friendCode.count >= 6
                                ? LinearGradient(
                                    colors: [.green, .teal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [.gray, .gray],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                        .cornerRadius(10)
                }
                .disabled(friendCode.count < 6)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Applied Code Section
    
    @ViewBuilder
    private var appliedCodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Applied Code")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(appliedFriendCode)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                    
                    Text("Code applied successfully")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.green.opacity(0.1))
            .cornerRadius(16)
        }
    }
    
    // MARK: - How It Works Section
    
    @ViewBuilder
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How It Works")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                HowItWorksRow(
                    step: "1",
                    icon: "paperplane.fill",
                    title: "Share Your Code",
                    description: "Send your unique code to friends"
                )
                
                Divider()
                    .padding(.leading, 56)
                
                HowItWorksRow(
                    step: "2",
                    icon: "person.badge.plus",
                    title: "Friend Signs Up",
                    description: "They enter your code when joining"
                )
                
                Divider()
                    .padding(.leading, 56)
                
                HowItWorksRow(
                    step: "3",
                    icon: "gift.fill",
                    title: "Both Get Rewards",
                    description: "You and your friend earn benefits"
                )
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Actions
    
    private func copyCode() {
        UIPasteboard.general.string = viewModel.promoCode
        HapticManager.shared.notification(.success)
        showCopiedAlert = true
    }
    
    private func shareCode() {
        let message = "Use my referral code \(viewModel.promoCode) to get started with CalCalculator!"
        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        HapticManager.shared.impact(.light)
    }
    
    private func applyFriendCode() {
        let code = friendCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Validate code
        guard code.count >= 6 else {
            errorMessage = "Please enter a valid 6-character code."
            showErrorAlert = true
            return
        }
        
        // Can't use own code
        guard code != viewModel.promoCode else {
            errorMessage = "You cannot use your own referral code."
            showErrorAlert = true
            return
        }
        
        // Check if already applied
        guard appliedFriendCode.isEmpty else {
            errorMessage = "You have already applied a referral code."
            showErrorAlert = true
            return
        }
        
        // Save the applied code
        UserDefaults.standard.set(code, forKey: "appliedFriendCode")
        appliedFriendCode = code
        friendCode = ""
        
        HapticManager.shared.notification(.success)
        showAppliedAlert = true
    }
}

// MARK: - Supporting Views

private struct HowItWorksRow: View {
    let step: String
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.2), .pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Preview

#Preview {
    ReferralCodeView()
}
