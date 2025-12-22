//
//  PreferencesView.swift
//  playground
//
//  Preferences screen with appearance and toggle settings
//

import SwiftUI

struct PreferencesView: View {
    @State private var profile = UserProfile.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    
    var body: some View {
        NavigationStack {
            Form {
                // Appearance Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Choose light, dark, or system appearance")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            AppearanceOption(
                                mode: .system,
                                isSelected: profile.appearanceMode == .system
                            ) {
                                profile.appearanceMode = .system
                            }
                            
                            AppearanceOption(
                                mode: .light,
                                isSelected: profile.appearanceMode == .light
                            ) {
                                profile.appearanceMode = .light
                            }
                            
                            AppearanceOption(
                                mode: .dark,
                                isSelected: profile.appearanceMode == .dark
                            ) {
                                profile.appearanceMode = .dark
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Appearance")
                }
                
                // Settings Section
                Section {
                    ToggleRow(
                        title: "Badge celebrations",
                        description: "Show a full-screen badge animation when you unlock a new badge",
                        isOn: $profile.badgeCelebrations
                    )
                    
                    ToggleRow(
                        title: "Live activity",
                        description: "Show your daily calories and macros on your lock screen and dynamic island",
                        isOn: $profile.liveActivity
                    )
                    
                    ToggleRow(
                        title: "Add burned calories",
                        description: "Add burned calories back to daily goal",
                        isOn: $profile.addBurnedCalories
                    )
                    
                    ToggleRow(
                        title: "Rollover calories",
                        description: "Add up to 200 left over calories from yesterday into today's daily goal",
                        isOn: $profile.rolloverCalories
                    )
                    
                    ToggleRow(
                        title: "Auto adjust macros",
                        description: "When editing calories or macronutrients, automatically adjust the other values proportionally",
                        isOn: $profile.autoAdjustMacros
                    )
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AppearanceOption: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 60)
                    
                    if mode == .system {
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .frame(width: 30)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black)
                                .frame(width: 30)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(mode == .light ? Color.white : Color.black)
                            .frame(height: 60)
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: mode == .light ? "sun.max" : "moon")
                        .font(.caption)
                    Text(mode.displayName)
                        .font(.caption)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    PreferencesView()
}

