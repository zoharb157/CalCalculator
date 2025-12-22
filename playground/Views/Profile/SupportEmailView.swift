//
//  SupportEmailView.swift
//
//  Support Email screen
//

import SwiftUI
import MessageUI

struct SupportEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var issueDescription = ""
    @State private var showingMailComposer = false
    @State private var mailResult: Result<MFMailComposeResult, Error>?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("support@calai.app")
                        .foregroundColor(.blue)
                } header: {
                    Text("To:")
                }
                
                Section {
                    Text("robobjack1996@icloud.com")
                        .foregroundColor(.secondary)
                } header: {
                    Text("Cc/Bcc, From:")
                }
                
                Section {
                    Text("Support Request")
                } header: {
                    Text("Subject:")
                }
                
                Section {
                    TextEditor(text: $issueDescription)
                        .frame(height: 200)
                } header: {
                    Text("Please describe your issue above this line.")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("User ID: bnKJERYpKoUs0mmHvONizg51krf1")
                        Text("Email: robobjack1996@icloud.com")
                        Text("Version: 3.1.4")
                        Text("Provider Id: Ym5LSKVSWXBLb1VzMG1tSHZPTml6ZzUxa3JmMQ==")
                        Text("Platform: iOS")
                        Text("iOS Version: 18.5")
                        Text("Device: iPhone")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
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
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showingMailComposer = true
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingMailComposer) {
                MailComposeView(
                    recipients: ["support@calai.app"],
                    subject: "Support Request",
                    body: generateEmailBody(),
                    result: $mailResult
                )
            }
        }
    }
    
    private func generateEmailBody() -> String {
        """
        \(issueDescription)
        
        ---
        User ID: bnKJERYpKoUs0mmHvONizg51krf1
        Email: robobjack1996@icloud.com
        Version: 3.1.4
        Provider Id: Ym5LSKVSWXBLb1VzMG1tSHZPTml6ZzUxa3JmMQ==
        Platform: iOS
        iOS Version: 18.5
        Device: iPhone
        
        Sent from my iPhone
        """
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    @Binding var result: Result<MFMailComposeResult, Error>?
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
            if let error = error {
                parent.result = .failure(error)
            } else {
                parent.result = .success(result)
            }
            parent.dismiss()
        }
    }
}

#Preview {
    SupportEmailView()
}

