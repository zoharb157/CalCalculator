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
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var isListening = false
    @State private var transcribedText: String = ""
    @State private var showingPermissionAlert = false
    @State private var showingComingSoonAlert = false
    @State private var animationAmount: CGFloat = 1.0
    @State private var isViewPresented = false

    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
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
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Food.voiceLog))
                .id("voice-log-title-\(localizationManager.currentLanguage)")
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
            .task {
                // Mark view as presented after a small delay to ensure hierarchy is stable
                // This prevents UIAlertController assertion failures
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                isViewPresented = true
            }
            .onDisappear {
                // Mark view as not presented to prevent alerts after dismissal
                isViewPresented = false
                // Also reset alert state to prevent showing after dismissal
                showingComingSoonAlert = false
                showingPermissionAlert = false
            }
            .alert(localizationManager.localizedString(for: AppStrings.Food.comingSoon), isPresented: $showingComingSoonAlert) {
                Button(localizationManager.localizedString(for: AppStrings.Common.ok), role: .cancel) {}
                    .id("ok-coming-soon-\(localizationManager.currentLanguage)")
            } message: {
                Text(localizationManager.localizedString(for: AppStrings.Food.voiceLoggingInDevelopment))
                    .id("coming-soon-message-\(localizationManager.currentLanguage)")
            }
            .alert(localizationManager.localizedString(for: AppStrings.Food.microphoneAccess), isPresented: $showingPermissionAlert) {
                Button(localizationManager.localizedString(for: AppStrings.Common.settings), role: .none) {
                    openSettings()
                }
                Button(localizationManager.localizedString(for: AppStrings.Common.cancel), role: .cancel) {}
            } message: {
                Text(localizationManager.localizedString(for: AppStrings.Food.voiceLoggingRequiresMicrophone))
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
            Text(isListening ? localizationManager.localizedString(for: AppStrings.Food.listening) : localizationManager.localizedString(for: AppStrings.Food.tapToStart))
                .font(.title2)
                .fontWeight(.semibold)
                .id("status-text-\(localizationManager.currentLanguage)")

            Text(isListening ? localizationManager.localizedString(for: AppStrings.Food.describeWhatYouAte) : localizationManager.localizedString(for: AppStrings.Food.voiceLoggingWillBeAvailableSoon))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .id("status-subtitle-\(localizationManager.currentLanguage)")
        }
    }

    // MARK: - Transcribed Text View

    private var transcribedTextView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizationManager.localizedString(for: AppStrings.Food.transcribed))
                .id("transcribed-\(localizationManager.currentLanguage)")
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
                Text(isListening ? localizationManager.localizedString(for: AppStrings.Food.stop) : localizationManager.localizedString(for: AppStrings.Food.startListening))
                    .id("mic-button-\(localizationManager.currentLanguage)")
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
            Text(localizationManager.localizedString(for: AppStrings.Food.comingSoon))
                .id("coming-soon-\(localizationManager.currentLanguage)")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(localizationManager.localizedString(for: AppStrings.Food.voiceLoggingInDevelopment))
                .id("voice-dev-text-\(localizationManager.currentLanguage)")
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

        // Only show alert if view is fully presented and stable
        // This prevents crashes when the view is being dismissed or not fully in the hierarchy
        guard isViewPresented else {
            print("⚠️ [VoiceLogView] Skipping alert - view not fully presented")
            return
        }
        
        // Use a small delay to ensure the view hierarchy is stable before presenting alert
        // This prevents UIAlertController assertion failures
        Task { @MainActor in
            // Small delay to ensure view is stable
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Double-check view is still presented before showing alert
            guard isViewPresented else { return }
            
            showingComingSoonAlert = true
        }

        // Auto-stop removed - user should manually stop listening
        // Voice recognition will complete when actual transcription finishes
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
