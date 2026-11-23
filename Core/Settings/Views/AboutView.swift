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
