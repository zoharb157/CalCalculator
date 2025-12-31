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
    @ObservedObject private var localizationManager = LocalizationManager.shared
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
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            Form {
                recipientSection
                senderSection
                subjectSection
                messageSection
                deviceInfoSection
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.supportRequest))
                
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
                    recipients: [supportEmail],
                    subject: localizationManager.localizedString(for: AppStrings.Profile.supportRequest),
                    body: generateEmailBody()
                )
            }
            #endif
            .alert(localizationManager.localizedString(for: AppStrings.Common.success), isPresented: $showCopiedAlert) {
                Button(localizationManager.localizedString(for: AppStrings.Common.ok), role: .cancel) { }
                    
            } message: {
                Text(localizationManager.localizedString(for: AppStrings.Profile.emailContentCopied))
                    
            }
        }
    }
    
    // MARK: - Sections
    
    private var recipientSection: some View {
        Section {
            Text(supportEmail)
                .foregroundStyle(.blue)
        } header: {
            Text(localizationManager.localizedString(for: AppStrings.Profile.to))
                
        }
    }
    
    private var senderSection: some View {
        Section {
            Text(deviceInfo.userName)
                .foregroundStyle(.secondary)
        } header: {
            Text(localizationManager.localizedString(for: AppStrings.Profile.from))
                
        }
    }
    
    private var subjectSection: some View {
        Section {
            Text(localizationManager.localizedString(for: AppStrings.Profile.supportRequest))
                
        } header: {
            Text(localizationManager.localizedString(for: AppStrings.Profile.subject))
                
        }
    }
    
    private var messageSection: some View {
        Section {
            TextEditor(text: $issueDescription)
                .frame(minHeight: 150)
        } header: {
            Text(localizationManager.localizedString(for: AppStrings.Profile.pleaseDescribeIssue))
                
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
        \(localizationManager.localizedString(for: AppStrings.Profile.userId)): \(deviceInfo.userId)
        \(localizationManager.localizedString(for: AppStrings.Profile.appVersion)): \(deviceInfo.appVersion)
        \(localizationManager.localizedString(for: AppStrings.Profile.platform)): \(localizationManager.localizedString(for: AppStrings.Profile.ios))
        \(localizationManager.localizedString(for: AppStrings.Profile.iosVersion)): \(deviceInfo.osVersion)
        \(localizationManager.localizedString(for: AppStrings.Profile.device)): \(deviceInfo.deviceModel)
        """
    }
    
    private func copyEmailToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = """
        \(localizationManager.localizedString(for: AppStrings.Profile.to)) \(supportEmail)
        \(localizationManager.localizedString(for: AppStrings.Profile.subject)) \(localizationManager.localizedString(for: AppStrings.Profile.supportRequest))
        
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
