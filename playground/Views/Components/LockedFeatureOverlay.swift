//
//  LockedFeatureOverlay.swift
//  playground
//
//  Reusable lock overlay for premium features
//

import SwiftUI
import SDK

struct LockedFeatureOverlay: View {
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @State private var showPaywall = false
    
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        if !isSubscribed {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    
                    if let message = message {
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Premium Feature")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Button("Unlock") {
                        showPaywall = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
                .padding(40)
            }
            .fullScreenCover(isPresented: $showPaywall) {
                SDKView(
                    model: sdk,
                    page: .splash,
                    show: $showPaywall,
                    backgroundColor: .white,
                    ignoreSafeArea: true
                )
            }
        }
    }
}

/// Blurs content and shows Premium button overlay (matches reference app style)
struct PremiumLockedContent<Content: View>: View {
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @State private var showPaywall = false
    
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
                .blur(radius: isSubscribed ? 0 : 8)
                .opacity(isSubscribed ? 1.0 : 0.3)
            
            if !isSubscribed {
                VStack {
                    Spacer()
                    
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Premium")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            // Gold/yellow gradient matching reference app
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.85, blue: 0.0),  // Gold
                                    Color(red: 1.0, green: 0.92, blue: 0.3)   // Lighter gold
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
                    }
                    
                    Spacer()
                }
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            SDKView(
                model: sdk,
                page: .splash,
                show: $showPaywall,
                backgroundColor: .white,
                ignoreSafeArea: true
            )
        }
    }
}

struct LockedButton: View {
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @State private var showPaywall = false
    
    let action: () -> Void
    let label: () -> AnyView
    
    init<Content: View>(@ViewBuilder label: @escaping () -> Content, action: @escaping () -> Void) {
        self.label = { AnyView(label()) }
        self.action = action
    }
    
    var body: some View {
        Button {
            if isSubscribed {
                action()
            } else {
                showPaywall = true
            }
        } label: {
            label()
        }
        .overlay(alignment: .topTrailing) {
            if !isSubscribed {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.orange)
                    .clipShape(Circle())
                    .offset(x: 4, y: -4)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            SDKView(
                model: sdk,
                page: .splash,
                show: $showPaywall,
                backgroundColor: .white,
                ignoreSafeArea: true
            )
        }
    }
}

