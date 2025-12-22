//
//  WidgetsView.swift
//
//  Widgets setup screen
//

import SwiftUI

struct WidgetsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: WidgetTab = .homeScreen
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tabs
                Picker("Widget Type", selection: $selectedTab) {
                    Text("Home Screen").tag(WidgetTab.homeScreen)
                    Text("Lock Screen").tag(WidgetTab.lockScreen)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        if selectedTab == .homeScreen {
                            HomeScreenWidgetSection()
                        } else {
                            LockScreenWidgetSection()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Widgets")
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

enum WidgetTab {
    case homeScreen
    case lockScreen
}

struct HomeScreenWidgetSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Home Screen Widget")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Track calories from your home screen")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // iPhone Mockup
            iPhoneMockup(
                widgetContent: AnyView(
                    VStack(alignment: .leading, spacing: 8) {
                        Text("2135 Calories left")
                            .font(.headline)
                        Text("+ Log your food")
                            .font(.caption)
                        Text("Cal AI")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                )
            )
            
            Text("How to add widget")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            HStack(alignment: .top, spacing: 16) {
                Circle()
                    .fill(Color.black)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("1")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    )
                
                iPhoneMockup(
                    widgetContent: AnyView(
                        VStack {
                            Text("Edit")
                            Text("Done")
                        }
                    ),
                    isEditMode: true
                )
            }
        }
    }
}

struct LockScreenWidgetSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Lock Screen Widget")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Track calories from your lock screen")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            iPhoneMockup(
                widgetContent: AnyView(
                    VStack {
                        Text("Mon Jul 28")
                        Text("9:41")
                            .font(.system(size: 48, weight: .bold))
                        Text("1456 Calories left")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                ),
                isLockScreen: true
            )
            
            Text("How to add widget")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            HStack(alignment: .top, spacing: 16) {
                Circle()
                    .fill(Color.black)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("1")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    )
                
                iPhoneMockup(
                    widgetContent: AnyView(
                        VStack {
                            Text("9:41")
                                .font(.system(size: 48, weight: .bold))
                        }
                    ),
                    isLockScreen: true,
                    showTapIndicator: true
                )
            }
        }
    }
}

struct iPhoneMockup: View {
    let widgetContent: AnyView
    var isEditMode: Bool = false
    var isLockScreen: Bool = false
    var showTapIndicator: Bool = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black)
                .frame(width: 200, height: 400)
            
            if isLockScreen {
                // Lock screen background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 380)
                    .overlay(
                        widgetContent
                            .foregroundColor(.white)
                    )
            } else {
                // Home screen
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .frame(width: 180, height: 380)
                    .overlay(
                        VStack {
                            if isEditMode {
                                HStack {
                                    Text("Edit")
                                    Spacer()
                                    Text("Done")
                                }
                                .font(.caption)
                                .padding()
                            }
                            
                            widgetContent
                            
                            Spacer()
                        }
                    )
            }
            
            if showTapIndicator {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .offset(x: 0, y: -50)
            }
        }
    }
}

#Preview {
    WidgetsView()
}

