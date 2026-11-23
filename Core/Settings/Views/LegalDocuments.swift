// File: Core/Settings/Views/LegalDocuments.swift
// Terms of Service and Privacy Policy, shown from About and from sign-up.

import SwiftUI

// MARK: - Legal Document View

/// Shows the in-app Terms of Service or Privacy Policy summary.
/// Also presented from RegisterView.
struct LegalDocumentView: View {
    let documentType: LegalDocumentType
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(documentType.sections, id: \.heading) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.heading)
                                .font(.headline)
                            Text(section.body)
                                .font(.body)
                                .foregroundColor(.textSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle(documentType.title)
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
}

struct LegalSection {
    let heading: String
    let body: String
}

enum LegalDocumentType: String, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: return "Terms of Service"
        case .privacy: return "Privacy Policy"
        }
    }

    var sections: [LegalSection] {
        switch self {
        case .terms: return Self.termsSections
        case .privacy: return Self.privacySections
        }
    }

    private static var termsSections: [LegalSection] {
        [
            LegalSection(
                heading: "What ArkadTrader is",
                body: "ArkadTrader is a trading journal and community app. You log your own trades by hand, track your results, and share posts and trade ideas with other traders. The app does not place trades, connect to a brokerage, or hold or move money."
            ),
            LegalSection(
                heading: "Not financial advice",
                body: "Posts, callouts, leaderboards and market news in the app are for information only and are not investment advice. Other users' results are based on numbers they enter themselves and may not be accurate. Trading involves risk, including the loss of money. Make your own decisions."
            ),
            LegalSection(
                heading: "Market data",
                body: "Market news and stock quotes come from Finnhub. They may be delayed, incomplete or unavailable."
            ),
            LegalSection(
                heading: "Your account",
                body: "You need an account to use the app. Keep your password safe; you are responsible for activity on your account. You can delete your account at any time in Settings."
            ),
            LegalSection(
                heading: "Your content",
                body: "You are responsible for what you post, including posts, comments, images, community messages and callouts. Don't post anything illegal, abusive, misleading or that you don't have the right to share, and don't impersonate others or spam. You can report posts that break these rules, and we may remove content or accounts that do."
            ),
            LegalSection(
                heading: "Changes and contact",
                body: "These terms may be updated as the app changes. Questions? Email \(AppInfo.supportEmail)."
            )
        ]
    }

    private static var privacySections: [LegalSection] {
        [
            LegalSection(
                heading: "What the app stores",
                body: "• Your account: email address and password, handled by Firebase Authentication (the app never stores your password itself).\n• Your profile: full name, username, bio and profile photo.\n• Your portfolio: the trades you log, your starting balance, deposits and withdrawals.\n• Your activity: posts, images, comments, likes, bookmarks, follows, communities you join, channel messages, files you share in channels, and reports you submit."
            ),
            LegalSection(
                heading: "Where it is stored",
                body: "Your data is stored with Google Firebase: Firebase Authentication for sign-in, Cloud Firestore for your profile, trades, posts and messages, and Cloud Storage for images and files you upload."
            ),
            LegalSection(
                heading: "Who can see it",
                body: "Other signed-in users can see your profile, posts and comments. Members of a community can see its channel messages. Trades you log can appear in search results, and your closed trades are used to rank you on leaderboards."
            ),
            LegalSection(
                heading: "Other services",
                body: "To show market news and quotes, the app requests data from Finnhub. For quotes it sends the ticker symbols of your open stock positions. Finnhub does not receive your account details.\n\nThe app includes Google's Firebase Analytics SDK, which can record basic app usage (such as app opens and sessions) and device information."
            ),
            LegalSection(
                heading: "On your device",
                body: "If you turn on Remember me, your email address is saved on this device so it is filled in next time. Data exports are created on your device and only leave it when you share them."
            ),
            LegalSection(
                heading: "Deleting your data",
                body: "Settings > Delete Account permanently deletes your sign-in and your profile. Trades, posts, comments, images and messages you created are not removed by that step; email \(AppInfo.supportEmail) to have them removed. You can also delete individual trades and posts in the app at any time."
            ),
            LegalSection(
                heading: "Contact",
                body: "Questions about your data? Email \(AppInfo.supportEmail)."
            )
        ]
    }
}
