//
//  VoiceLogView.swift
//  playground
//
//  Voice-based food logging view (placeholder for future implementation)
//

import SwiftUI

struct VoiceLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isListening = false
    @State private var transcribedText: String = ""
    @State private var showingPermissionAlert = false
    @State private var animationAmount: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Voice visualization
                voiceVisualization

                // Status text
                statusText

                // Transcribed text display
                if !transcribedText.isEmpty {
                    transcribedTextView
                }

                Spacer()

                // Microphone button
                microphoneButton

                // Help text
                helpText
            }
            .padding()
            .navigationTitle("Voice Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .alert("Microphone Access", isPresented: $showingPermissionAlert) {
                Button("Settings", role: .none) {
                    openSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Voice logging requires microphone access. Please enable it in Settings to use this feature."
                )
            }
        }
    }

    // MARK: - Voice Visualization

    private var voiceVisualization: some View {
        ZStack {
            // Outer pulsing circles (when listening)
            if isListening {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .scaleEffect(animationAmount)
                    .opacity(2 - animationAmount)

                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 160, height: 160)
                    .scaleEffect(animationAmount * 0.9)
                    .opacity(2 - animationAmount)
            }

            // Main circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: isListening
                            ? [.blue, .purple] : [.gray.opacity(0.3), .gray.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(
                    color: isListening ? .blue.opacity(0.3) : .clear,
                    radius: isListening ? 20 : 0
                )

            // Microphone icon
            Image(systemName: isListening ? "waveform" : "mic.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isListening)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animationAmount = 1.3
            }
        }
    }

    // MARK: - Status Text

    private var statusText: some View {
        VStack(spacing: 8) {
            Text(isListening ? "Listening..." : "Tap to start")
                .font(.title2)
                .fontWeight(.semibold)

            Text(isListening ? "Describe what you ate" : "Voice logging will be available soon")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Transcribed Text View

    private var transcribedTextView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcribed:")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(transcribedText)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
        .padding(.horizontal)
    }

    // MARK: - Microphone Button

    private var microphoneButton: some View {
        Button {
            toggleListening()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isListening ? "stop.fill" : "mic.fill")
                Text(isListening ? "Stop" : "Start Listening")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: isListening ? [.red, .orange] : [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
        }
        .padding(.horizontal)
    }

    // MARK: - Help Text

    private var helpText: some View {
        VStack(spacing: 8) {
            Text("Coming Soon")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(
                "Voice logging is currently in development. Soon you'll be able to describe your meals naturally and have them automatically logged."
            )
            .font(.caption)
            .foregroundColor(Color(.tertiaryLabel))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Actions

    private func toggleListening() {
        HapticManager.shared.impact(.medium)

        // Show coming soon message for now
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isListening.toggle()
        }

        // Auto-stop after 3 seconds for demo purposes
        if isListening {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isListening = false
                    transcribedText = "Voice recognition coming soon..."
                }
            }
        }
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Voice Waveform View (placeholder for future use)

struct VoiceWaveformView: View {
    @Binding var isAnimating: Bool
    let barCount: Int = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    isAnimating: isAnimating,
                    delay: Double(index) * 0.1
                )
            }
        }
    }
}

struct WaveformBar: View {
    let isAnimating: Bool
    let delay: Double

    @State private var height: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.blue)
            .frame(width: 4, height: height)
            .onAppear {
                guard isAnimating else { return }
                withAnimation(
                    .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                ) {
                    height = CGFloat.random(in: 10...40)
                }
            }
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    withAnimation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(delay)
                    ) {
                        height = CGFloat.random(in: 10...40)
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        height = 10
                    }
                }
            }
    }
}

#Preview {
    VoiceLogView()
}
