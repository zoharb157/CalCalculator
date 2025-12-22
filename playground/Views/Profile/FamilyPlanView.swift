//
//  FamilyPlanView.swift
//
//  Family Plan upgrade screen
//

import SwiftUI

struct FamilyPlanView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Illustration
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 200, height: 200)
                        
                        // Family icons
                        VStack(spacing: -10) {
                            HStack(spacing: -10) {
                                PersonIcon()
                                PersonIcon()
                            }
                            HStack(spacing: -10) {
                                PersonIcon()
                                PersonIcon()
                            }
                            HStack(spacing: -10) {
                                PersonIcon()
                                PersonIcon()
                            }
                        }
                    }
                    .padding(.top, 40)
                    
                    // Title
                    Text("Cal AI Family Plan")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        FamilyFeature(
                            icon: "person.3.fill",
                            text: "Up to 6 members, one plan"
                        )
                        
                        FamilyFeature(
                            icon: "camera.fill",
                            text: "Unlimited AI meal scanning for all"
                        )
                        
                        FamilyFeature(
                            icon: "doc.badge.plus",
                            text: "Personalized plans for everyone"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Pricing
                    Text("Only $2.50/mo more! ($59.99/yr)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // CTA Button
                    Button {
                        // Upgrade
                    } label: {
                        Text("Upgrade to Family Plan")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brown)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Footer
                    HStack(spacing: 8) {
                        Text("Terms")
                        Text("•")
                        Text("Privacy")
                        Text("•")
                        Text("Restore")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Family Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

struct PersonIcon: View {
    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
            )
    }
}

struct FamilyFeature: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.brown)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    FamilyPlanView()
}

