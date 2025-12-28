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
    
    var body: some View {
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
                        Button("Previous") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    if currentPage < 2 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Get Started") {
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
            
            Text("Welcome to Diet Plans!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Create personalized meal schedules and track your adherence to reach your nutrition goals.")
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
            
            Text("Smart Reminders")
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
            
            Text("Track Your Progress")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Monitor your diet adherence, see insights about your eating patterns, and stay on track with your nutrition goals.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Daily adherence tracking")
                        .font(.subheadline)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Weekly progress charts")
                        .font(.subheadline)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Personalized insights")
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


