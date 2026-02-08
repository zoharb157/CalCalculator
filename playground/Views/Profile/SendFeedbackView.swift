//
//  SendFeedbackView.swift
//  playground
//
//  Send Feedback screen with email functionality
//

import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif
#if canImport(UIKit)
import UIKit
#endif

struct SendFeedbackView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var showingMailComposer = false
    @State private var showCopiedAlert = false
    @State private var showSentAlert = false
    @State private var showFailedAlert = false
    
    private let feedbackEmail = "feedback@calai.app"
    
    // Device and app info
    private var deviceInfo: DeviceInfo {
        DeviceInfo()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                recipientSection
                messageSection
                deviceInfoSection
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.sendFeedback))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    sendButton
                }
            }
            #if canImport(MessageUI)
            .sheet(isPresented: $showingMailComposer) {
                MailComposeView(
                    recipients: [feedbackEmail],
                    subject: localizationManager.localizedString(for: AppStrings.Profile.sendFeedback),
                    body: generateEmailBody()
                ) { result in
                    switch result {
                    case .sent:
                        showSentAlert = true
                    case .failed:
                        showFailedAlert = true
                    case .cancelled, .saved:
                        break
                    @unknown default:
                        break
                    }
                }
            }
            #endif
            .alert(localizationManager.localizedString(for: AppStrings.Common.success), isPresented: $showCopiedAlert) {
                Button(localizationManager.localizedString(for: AppStrings.Common.ok), role: .cancel) {}
            } message: {
                Text(localizationManager.localizedString(for: AppStrings.Profile.emailContentCopied))
            }
            .alert(localizationManager.localizedString(for: AppStrings.Common.success), isPresented: $showSentAlert) {
                Button(localizationManager.localizedString(for: AppStrings.Common.ok), role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(localizationManager.localizedString(for: AppStrings.Profile.feedbackSent))
            }
            .alert(localizationManager.localizedString(for: AppStrings.Common.error), isPresented: $showFailedAlert) {
                Button(localizationManager.localizedString(for: AppStrings.Common.ok), role: .cancel) {}
            } message: {
                Text(localizationManager.localizedString(for: AppStrings.Profile.feedbackFailed))
            }
        }
    }
    
    // MARK: - Sections
    
    private var recipientSection: some View {
        Section {
            Text(feedbackEmail)
                .foregroundStyle(.blue)
        } header: {
            Text(localizationManager.localizedString(for: AppStrings.Profile.to))
        }
    }
    
    private var messageSection: some View {
        Section {
            TextEditor(text: $feedbackText)
                .frame(minHeight: 150)
        } header: {
            Text(localizationManager.localizedString(for: AppStrings.Profile.feedbackDescription))
        } footer: {
            Text(localizationManager.localizedString(for: AppStrings.Profile.feedbackFooter))
        }
    }
    
    private var deviceInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                InfoRow(label: localizationManager.localizedString(for: AppStrings.Profile.userId), value: deviceInfo.userId)
                InfoRow(label: localizationManager.localizedString(for: AppStrings.Profile.appVersion), value: deviceInfo.appVersion)
                InfoRow(label: localizationManager.localizedString(for: AppStrings.Profile.platform), value: localizationManager.localizedString(for: AppStrings.Profile.ios))
                InfoRow(label: localizationManager.localizedString(for: AppStrings.Profile.iosVersion), value: deviceInfo.osVersion)
                InfoRow(label: localizationManager.localizedString(for: AppStrings.Profile.device), value: deviceInfo.deviceModel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
            Text(localizationManager.localizedString(for: AppStrings.Profile.debugInformation))
        } footer: {
            Text(localizationManager.localizedString(for: AppStrings.Profile.debugInfoHelpsDiagnose))
        }
    }
    
    private var sendButton: some View {
        Button {
            #if canImport(MessageUI)
            if MFMailComposeViewController.canSendMail() {
                showingMailComposer = true
            } else {
                copyEmailToClipboard()
            }
            #else
            copyEmailToClipboard()
            #endif
        } label: {
            Text(localizationManager.localizedString(for: AppStrings.Common.send))
                .fontWeight(.semibold)
        }
        .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    // MARK: - Helpers
    
    private func generateEmailBody() -> String {
        var body = feedbackText
        
        body += "\n\n---\n"
        body += "\(localizationManager.localizedString(for: AppStrings.Profile.debugInformation)):\n"
        body += "\(localizationManager.localizedString(for: AppStrings.Profile.userId)): \(deviceInfo.userId)\n"
        body += "\(localizationManager.localizedString(for: AppStrings.Profile.appVersion)): \(deviceInfo.appVersion)\n"
        body += "\(localizationManager.localizedString(for: AppStrings.Profile.platform)): \(localizationManager.localizedString(for: AppStrings.Profile.ios))\n"
        body += "\(localizationManager.localizedString(for: AppStrings.Profile.iosVersion)): \(deviceInfo.osVersion)\n"
        body += "\(localizationManager.localizedString(for: AppStrings.Profile.device)): \(deviceInfo.deviceModel)"
        
        return body
    }
    
    private func copyEmailToClipboard() {
        let emailBody = generateEmailBody()
        let fullEmail = "To: \(feedbackEmail)\nSubject: \(localizationManager.localizedString(for: AppStrings.Profile.sendFeedback))\n\n\(emailBody)"
        
        UIPasteboard.general.string = fullEmail
        showCopiedAlert = true
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
            Text(value)
        }
    }
}

// MARK: - Device Info

private struct DeviceInfo {
    let userId: String
    let userName: String
    let appVersion: String
    let osVersion: String
    let deviceModel: String
    
    init() {
        // Get user ID from AuthenticationManager
        self.userId = AuthenticationManager.shared.userId ?? "Unknown"
        
        // Get user name from repository
        let repository = UserProfileRepository.shared
        let firstName = repository.getFirstName()
        let lastName = repository.getLastName()
        self.userName = firstName.isEmpty && lastName.isEmpty 
            ? "Not set" 
            : "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        
        // App version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        self.appVersion = "\(version) (\(build))"
        
        // OS version
        #if canImport(UIKit)
        self.osVersion = UIDevice.current.systemVersion
        self.deviceModel = UIDevice.current.model
        #else
        self.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        self.deviceModel = "Mac"
        #endif
    }
}

// MARK: - Mail Compose View

#if canImport(MessageUI)
struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    let onComplete: (MFMailComposeResult) -> Void
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onComplete: (MFMailComposeResult) -> Void
        
        init(onComplete: @escaping (MFMailComposeResult) -> Void) {
            self.onComplete = onComplete
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) {
                self.onComplete(result)
            }
        }
    }
}
#endif

#Preview {
    SendFeedbackView()
}
