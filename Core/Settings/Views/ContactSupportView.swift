// File: Core/Settings/Views/ContactSupportView.swift
// Contact Support: one honest action, an email to AppInfo.supportEmail with the
// app version and iOS version filled in so we can help faster.

import SwiftUI
import UIKit

struct ContactSupportView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    headerSection
                    EmailSupportButton()
                    tipsSection
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.l)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .screenBackground()
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.goldText)
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            IconWell(systemName: "envelope.fill", size: 52)

            Text("How can we help?")
                .font(.system(size: 28, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            Text("Email us with a question, a bug or an idea. Your app version and iOS version are added to the message for you.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Tips
    private var tipsSection: some View {
        SettingsGroupCard(title: "To help us help you") {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                tipRow(icon: "text.bubble", text: "Say what you were trying to do and what happened instead.")
                tipRow(icon: "photo", text: "Attach a screenshot if something looks wrong.")
                tipRow(icon: "person.crop.circle", text: "Send it from the email address you sign in with, so we can find your account.")
            }
            .padding(DS.Spacing.l)
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            IconWell(systemName: icon, size: 30)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Support Email

/// Builds the mailto: link used by Contact Support, the Help Center and About.
enum SupportEmail {
    static var address: String { AppInfo.supportEmail }

    @MainActor
    static func url(subject: String = "Arkad Support") -> URL? {
        let body = """


        ---
        Please keep the details below, they help us look into your request.
        App: Arkad \(AppInfo.version) (\(AppInfo.build))
        iOS: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

/// A button that opens Mail with a pre-filled support email. If no mail app can
/// handle the link, it shows the address with a Copy option instead.
struct EmailSupportButton: View {
    var title: String = "Email support"
    var subject: String = "Arkad Support"

    @Environment(\.openURL) private var openURL
    @State private var showNoMailAlert = false

    var body: some View {
        VStack(spacing: DS.Spacing.s) {
            Button(action: sendEmail) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                    Text(title)
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            Text(SupportEmail.address)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity)
        .alert("Couldn't Open Mail", isPresented: $showNoMailAlert) {
            Button("Copy Address") {
                UIPasteboard.general.string = SupportEmail.address
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("No mail app is set up on this device. You can email us at \(SupportEmail.address).")
        }
    }

    private func sendEmail() {
        guard let url = SupportEmail.url(subject: subject) else {
            showNoMailAlert = true
            return
        }
        openURL(url) { accepted in
            if !accepted {
                showNoMailAlert = true
            }
        }
    }
}

#Preview {
    ContactSupportView()
}
