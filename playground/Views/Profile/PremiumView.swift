//
//  PremiumView.swift
//
//  Premium subscription screen
//

import SwiftUI

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PlanType = .annual
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Banner
                    VStack(spacing: 12) {
                        Text("Premium")
                            .font(.system(size: 48, weight: .bold))
                        
                        Text("Simplify your journey with faster logging tools and custom settings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.brown.opacity(0.3), Color.orange.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Plans
                    HStack(spacing: 12) {
                        PlanCard(
                            type: .monthly,
                            isSelected: selectedPlan == .monthly
                        ) {
                            selectedPlan = .monthly
                        }
                        
                        PlanCard(
                            type: .annual,
                            isSelected: selectedPlan == .annual
                        ) {
                            selectedPlan = .annual
                        }
                    }
                    .padding(.horizontal)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Premium helps you:")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        PremiumFeature(
                            icon: "camera.fill",
                            title: "Track your meals with just a photo",
                            description: "Snap a photo to log your food instantly."
                        )
                        
                        PremiumFeature(
                            icon: "brain.head.profile",
                            title: "Best in class AI meal analysis",
                            description: "AI analyzes calories, macros, and portions."
                        )
                        
                        PremiumFeature(
                            icon: "barcode.viewfinder",
                            title: "Barcode scanner",
                            description: "Quickly log packaged foods with one tap."
                        )
                        
                        PremiumFeature(
                            icon: "mic.fill",
                            title: "Voice logging",
                            description: "Log meals hands-free with voice."
                        )
                        
                        PremiumFeature(
                            icon: "magnifyingglass",
                            title: "Log foods from our database",
                            description: "Access over 1 million foods instantly."
                        )
                        
                        PremiumFeature(
                            icon: "photo.fill",
                            title: "Take progress photos",
                            description: "See how your body changes over time."
                        )
                        
                        PremiumFeature(
                            icon: "person.fill",
                            title: "Monitor your BMI",
                            description: ""
                        )
                    }
                    .padding(.horizontal)
                    
                    // CTA Button
                    Button {
                        // Start trial
                    } label: {
                        Text("Start 3-day free trial")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.brown.opacity(0.3), Color.orange.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
                .padding(.top)
            }
            .navigationTitle("Premium")
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

enum PlanType {
    case monthly
    case annual
}

struct PlanCard: View {
    let type: PlanType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                if type == .annual {
                    Text("$2.49/mo")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brown)
                        .cornerRadius(4)
                }
                
                Text(type == .monthly ? "1 month" : "12 months")
                    .font(.headline)
                
                Text(type == .monthly ? "$9.99/mo" : "$29.99")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(type == .monthly ? "Billed monthly" : "Billed annually")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.brown : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PremiumFeature: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.brown)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                if !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    PremiumView()
}

