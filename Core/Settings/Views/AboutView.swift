// File: Core/Settings/Views/AboutView.swift
// About: version, release notes, plain-language terms and privacy summaries,
// open source licenses, and a link to Contact Support.

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    @State private var legalDocument: LegalDocumentType?
    @State private var showingLicenses = false
    @State private var showingReleaseNotes = false
    @State private var showingContactSupport = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    appHeaderSection
                    appInfoSection
                    legalSection
                    developmentSection
                    supportSection

                    Text(AppInfo.copyright)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)

                    Spacer(minLength: 30)
                }
                .padding()
            }
            .navigationTitle("About ArkadTrader")
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
        .sheet(item: $legalDocument) { document in
            LegalDocumentView(documentType: document)
        }
        .sheet(isPresented: $showingLicenses) {
            LicensesView()
        }
        .sheet(isPresented: $showingReleaseNotes) {
            ReleaseNotesView()
        }
        .sheet(isPresented: $showingContactSupport) {
            ContactSupportView()
        }
    }

    // MARK: - App Header Section
    private var appHeaderSection: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.arkadGold, Color.arkadGoldLight]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Text("AT")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                )
                .shadow(color: Color.arkadGold.opacity(0.4), radius: 10, x: 0, y: 5)

            VStack(spacing: 8) {
                Text("ArkadTrader")
                    .font(.title)
                    .fontWeight(.bold)

                Text(AppInfo.versionLine)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Text("Trading. Simplified.")
                    .font(.caption)
                    .foregroundColor(.arkadGoldDark)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
        )
    }

    // MARK: - App Information Section
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Information")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                InfoRow(
                    icon: "iphone",
                    title: "Compatibility",
                    value: "iOS \(AppInfo.minimumIOSVersion) or later",
                    color: .green
                )

                InfoRow(
                    icon: "globe",
                    title: "Language",
                    value: "English",
                    color: .purple
                )

                LegalRow(
                    icon: "doc.text",
                    title: "Release Notes",
                    description: "What's in version \(AppInfo.version)",
                    color: .blue
                ) {
                    showingReleaseNotes = true
                }
            }
        }
    }

    // MARK: - Legal Section
    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Legal & Privacy")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                LegalRow(
                    icon: "doc.text",
                    title: "Terms of Service",
                    description: "The rules for using ArkadTrader",
                    color: .blue
                ) {
                    legalDocument = .terms
                }

                LegalRow(
                    icon: "hand.raised",
                    title: "Privacy Policy",
                    description: "What data the app stores and who can see it",
                    color: .green
                ) {
                    legalDocument = .privacy
                }

                LegalRow(
                    icon: "list.bullet",
                    title: "Open Source Licenses",
                    description: "Third-party software used in the app",
                    color: .purple
                ) {
                    showingLicenses = true
                }
            }
        }
    }

    // MARK: - Development Section
    private var developmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Development")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                InfoRow(
                    icon: "person.circle",
                    title: "Developer",
                    value: "Arkad",
                    color: .blue
                )

                InfoRow(
                    icon: "hammer",
                    title: "Built with",
                    value: "SwiftUI & Firebase",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Support Section
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Support & Feedback")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                SupportActionRow(
                    icon: "envelope",
                    title: "Contact Support",
                    description: "Email us with a question or a problem",
                    color: .blue
                ) {
                    showingContactSupport = true
                }

                ShareLink(item: "I'm using ArkadTrader to log my trades and share results with other traders.") {
                    SupportActionLabel(
                        icon: "square.and.arrow.up",
                        title: "Share ArkadTrader",
                        description: "Tell your friends about the app",
                        color: .green
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.primary)
                .fontWeight(.medium)

            Spacer()

            Text(value)
                .foregroundColor(.gray)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

struct LegalRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SupportActionRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SupportActionLabel(icon: icon, title: title, description: description, color: color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SupportActionLabel: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

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

// MARK: - Licenses View
struct LicensesView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Firebase iOS SDK")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Apache License 2.0")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Copyright Google LLC. Used for sign-in, the database, file storage and analytics. It includes supporting Google libraries under their own open source licenses.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                    .padding(.vertical, 4)

                    Link("Read the Apache License 2.0", destination: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!)
                        .foregroundColor(.arkadGoldDark)
                } header: {
                    Text("Open Source Libraries")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Licenses")
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

// MARK: - Release Notes View
struct ReleaseNotesView: View {
    @Environment(\.dismiss) var dismiss

    private let changes = [
        "Log trades by hand: stocks, options, crypto and forex",
        "Close, edit and delete trades, with a starting balance plus deposits and withdrawals",
        "Realized P&L chart for the last week, month, year or all time",
        "Open stock positions valued with market quotes from Finnhub when available",
        "A feed with text posts, images and trade result cards, plus likes and comments",
        "Follow traders, see a Following feed, and read market news",
        "Communities with channels, chat and trade callouts",
        "Leaderboards ranked by closed trades",
        "Search for people, posts, trades and communities",
        "Export your trades and posts as CSV files, and delete your account in Settings"
    ]

    var body: some View {
        NavigationView {
            List {
                Section("Version \(AppInfo.version): first release") {
                    ForEach(changes, id: \.self) { change in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.arkadGoldDark)
                            Text(change)
                                .font(.body)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Release Notes")
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

#Preview {
    AboutView()
}
