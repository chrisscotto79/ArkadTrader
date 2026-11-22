// File: Core/Settings/Views/ContactSupportView.swift
// Contact Support: one honest action, an email to AppInfo.supportEmail with the
// app version and iOS version filled in so we can help faster.

import SwiftUI
import UIKit

struct ContactSupportView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    EmailSupportButton()
                    tipsSection
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.circle.fill")
                .foregroundColor(.arkadGold)
                .font(.system(size: 56))

            Text("How can we help?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Email us with a question, a bug or an idea. Your app version and iOS version are added to the message for you.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
    }

    // MARK: - Tips
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("To help us help you")
                .font(.headline)
                .fontWeight(.semibold)

            tipRow(icon: "text.bubble", text: "Say what you were trying to do and what happened instead.")
            tipRow(icon: "photo", text: "Attach a screenshot if something looks wrong.")
            tipRow(icon: "person.crop.circle", text: "Send it from the email address you sign in with, so we can find your account.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.arkadGold)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Support Email

/// Builds the mailto: link used by Contact Support, the Help Center and About.
enum SupportEmail {
    static var address: String { AppInfo.supportEmail }

    @MainActor
    static func url(subject: String = "ArkadTrader Support") -> URL? {
        let body = """


        ---
        Please keep the details below, they help us look into your request.
        App: ArkadTrader \(AppInfo.version) (\(AppInfo.build))
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
    var title: String = "Email Support"
    var subject: String = "ArkadTrader Support"

    @Environment(\.openURL) private var openURL
    @State private var showNoMailAlert = false

    var body: some View {
        Button(action: sendEmail) {
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.semibold)
                    Text(SupportEmail.address)
                        .font(.caption)
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
            }
            .foregroundColor(.arkadBlack)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.arkadGold)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
