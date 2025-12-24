//
//  SupportEmailView.swift
//
//  Support Email screen with dynamic user information
//

import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif
#if canImport(UIKit)
import UIKit
#endif

struct SupportEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var issueDescription = ""
    @State private var showingMailComposer = false
    @State private var showCopiedAlert = false
    
    private let supportEmail = "support@calai.app"
    
    // Device and app info
    private var deviceInfo: DeviceInfo {
        DeviceInfo()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                recipientSection
                senderSection
                subjectSection
                messageSection
                deviceInfoSection
            }
            .navigationTitle("Support Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
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
                    recipients: [supportEmail],
                    subject: "Support Request",
                    body: generateEmailBody()
                )
            }
            #endif
            .alert("Copied to Clipboard", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Email content has been copied. Please paste it into your email app.")
            }
        }
    }
    
    // MARK: - Sections
    
    private var recipientSection: some View {
        Section {
            Text(supportEmail)
                .foregroundStyle(.blue)
        } header: {
            Text("To:")
        }
    }
    
    private var senderSection: some View {
        Section {
            Text(deviceInfo.userName)
                .foregroundStyle(.secondary)
        } header: {
            Text("From:")
        }
    }
    
    private var subjectSection: some View {
        Section {
            Text("Support Request")
        } header: {
            Text("Subject:")
        }
    }
    
    private var messageSection: some View {
        Section {
            TextEditor(text: $issueDescription)
                .frame(minHeight: 150)
        } header: {
            Text("Please describe your issue:")
        }
    }
    
    private var deviceInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                InfoRow(label: "User ID", value: deviceInfo.userId)
                InfoRow(label: "App Version", value: deviceInfo.appVersion)
                InfoRow(label: "Platform", value: "iOS")
                InfoRow(label: "iOS Version", value: deviceInfo.osVersion)
                InfoRow(label: "Device", value: deviceInfo.deviceModel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
            Text("Debug Information")
        } footer: {
            Text("This information helps us diagnose issues faster.")
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
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
        }
        .disabled(issueDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    // MARK: - Helpers
    
    private func generateEmailBody() -> String {
        """
        \(issueDescription)
        
        ---
        User ID: \(deviceInfo.userId)
        App Version: \(deviceInfo.appVersion)
        Platform: iOS
        iOS Version: \(deviceInfo.osVersion)
        Device: \(deviceInfo.deviceModel)
        """
    }
    
    private func copyEmailToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = """
        To: \(supportEmail)
        Subject: Support Request
        
        \(generateEmailBody())
        """
        showCopiedAlert = true
        #endif
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
    @Environment(\.dismiss) private var dismiss
    
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
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}
#endif

#Preview {
    SupportEmailView()
}
