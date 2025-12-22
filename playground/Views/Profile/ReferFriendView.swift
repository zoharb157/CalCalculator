//
//  ReferFriendView.swift
//
//  Refer a friend screen
//

import SwiftUI

struct ReferFriendView: View {
    @State private var profile = UserProfile.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Title
                    Text("Refer your friend")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    // Avatars and icon
                    HStack(spacing: 16) {
                        AvatarView(color: .blue)
                        AvatarView(color: .green)
                        AvatarView(color: .blue)
                    }
                    .overlay(
                        HStack {
                            AvatarView(color: .red)
                            Image(systemName: "apple.logo")
                                .font(.title)
                                .foregroundColor(.gray)
                            AvatarView(color: .purple)
                        }
                        .offset(y: 40)
                    )
                    
                    // Motto
                    VStack(spacing: 8) {
                        Text("Empower your friends")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("& lose weight together")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    // Promo Code Card
                    VStack(spacing: 12) {
                        Text("Your personal promo code")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(profile.promoCode)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                            
                            Button {
                                UIPasteboard.general.string = profile.promoCode
                            } label: {
                                Image(systemName: "square.on.square")
                                    .font(.title3)
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Share Button
                    Button {
                        showingShareSheet = true
                    } label: {
                        Text("Share")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // How to Earn
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("How to earn")
                                .font(.headline)
                            
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text("$")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Share your promo code to your friends")
                            Text("• Earn $10 per friend that signs up with your code")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Refer your friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: ["Use my promo code \(profile.promoCode) to join Cal AI!"])
            }
        }
    }
}

struct AvatarView: View {
    let color: Color
    
    var body: some View {
        Circle()
            .fill(color.opacity(0.3))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(color)
            )
    }
}

#Preview {
    ReferFriendView()
}

