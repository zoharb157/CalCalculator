//
//  SplashView.swift
//  CalCalculatorAiPlaygournd
//
//  Created by Bassam-Hillo on 29/12/2025.
//

import SwiftUI

struct SplashView: View {
    @State private var showApp = false

    // Entrance animation states
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var logoRotation: Double = -10
    @State private var glowOpacity: Double = 0

    @State private var titleOpacity: Double = 0
    @State private var titleOffsetY: CGFloat = 12

    // Looping animation states
    @State private var shimmerPhase: CGFloat = -0.6
    @State private var ringRotation: Double = 0
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    // Soft glow behind everything
                    Circle()
                        .fill(.primary.opacity(0.10))
                        .frame(width: 190, height: 190)
                        .opacity(glowOpacity)
                        .blur(radius: 10)

                    // Rotating conic ring glow
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [
                                    .clear,
                                    .primary.opacity(0.35),
                                    .clear
                                ],
                                center: .center
                            ),
                            lineWidth: 10
                        )
                        .frame(width: 170, height: 170)
                        .opacity(glowOpacity * 0.9)
                        .rotationEffect(.degrees(ringRotation))
                        .blur(radius: 0.5)

                    // Logo container
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 128, height: 128)
                        .overlay(
                            Image(.splashLogo)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(28)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(.primary.opacity(0.10), lineWidth: 1)
                        )
                        // Shimmer overlay
                        .overlay {
                            ShimmerOverlay(phase: shimmerPhase)
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                .opacity(logoOpacity)
                        }
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .rotationEffect(.degrees(logoRotation))
                        .offset(y: floatOffset)
                        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
                }

                VStack(spacing: 8) {
                    Text("AI Calorie Counter")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))

                    HStack(spacing: 8) {
                        Text("Loading")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .opacity(0.6)

                        DotLoader()
                    }
                }
                .opacity(titleOpacity)
                .offset(y: titleOffsetY)
            }
            .padding(.bottom, 10)
            .onAppear {
                runAnimation()
            }
        }
        .animation(.easeInOut(duration: 0.45), value: showApp)
    }

    private func runAnimation() {
        // 1) Logo pop-in
        withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
            logoOpacity = 1
            glowOpacity = 1
            logoScale = 1.0
            logoRotation = 0
        }

        // 2) Title slides in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.45)) {
                titleOpacity = 1
                titleOffsetY = 0
            }
        }

        // 3) Start looping “premium” animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            // Shimmer sweep
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.4
            }
            // Ring rotation
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            // Gentle float
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                floatOffset = -6
            }
            // Gentle breathing glow
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glowOpacity = 0.65
            }
        }

        // 4) Transition to app
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
            withAnimation(.easeInOut(duration: 0.35)) {
                showApp = true
            }
        }
    }
}

private struct ShimmerOverlay: View {
    var phase: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.22), location: 0.5),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: w * 0.55, height: h * 1.4)
                .rotationEffect(.degrees(22))
                .offset(x: w * phase, y: -h * 0.2)
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
    }
}

private struct DotLoader: View {
    @State private var t: Double = 0

    var body: some View {
        HStack(spacing: 4) {
            dot(0)
            dot(1)
            dot(2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                t = 1
            }
        }
    }

    private func dot(_ i: Int) -> some View {
        Circle()
            .frame(width: 6, height: 6)
            .opacity(0.25 + 0.75 * dotValue(i))
            .scaleEffect(0.85 + 0.35 * dotValue(i))
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(Double(i) * 0.12), value: t)
    }

    private func dotValue(_ i: Int) -> Double {
        // phase-shifted wave based on t
        let base = t
        // simple stagger: 0, 0.33, 0.66
        let shifted = base + Double(i) * 0.33
        // wrap 0...1
        let x = shifted - floor(shifted)
        // triangle wave
        return x < 0.5 ? x * 2 : (1 - x) * 2
    }
}

#Preview {
    SplashView()
}
