// File: Core/Settings/Views/AboutView.swift
// About: version, release notes, Terms of Service and Privacy Policy,
// open source licenses, and a link to Contact Support.

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    @State private var legalDocument: LegalDocumentType?
    @State private var showingLicenses = false
    @State private var showingReleaseNotes = false
    @State private var showingContactSupport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    appHeaderSection
                    appInfoSection
                    legalSection
                    developmentSection
                    supportSection

                    Text(AppInfo.copyright)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, DS.Spacing.xs)
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .screenBackground()
            .navigationTitle("About Arkad")
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

    // MARK: - App Header

    private var appHeaderSection: some View {
        VStack(spacing: DS.Spacing.l) {
            ArkadLogo(height: 56)
                .frame(maxWidth: 220)

            VStack(spacing: 6) {
                Text("Trading. Simplified.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.goldText)

                Text(AppInfo.versionLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.l)
        .cardStyle(padding: DS.Spacing.xl)
    }

    // MARK: - App Information

    private var appInfoSection: some View {
        SettingsGroupCard(title: "App") {
            SettingsRowLabel(
                icon: "iphone",
                title: "Compatibility",
                value: "iOS \(AppInfo.minimumIOSVersion) or later",
                accessory: .none
            )
            SettingsRowDivider()
            SettingsRowLabel(icon: "globe", title: "Language", value: "English", accessory: .none)
            SettingsRowDivider()
            SettingsListRow(
                icon: "sparkles",
                title: "Release notes",
                subtitle: "What's in version \(AppInfo.version)"
            ) {
                showingReleaseNotes = true
            }
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        SettingsGroupCard(title: "Legal & privacy") {
            SettingsListRow(
                icon: "doc.text",
                title: "Terms of Service",
                subtitle: "The rules for using Arkad"
            ) {
                legalDocument = .terms
            }
            SettingsRowDivider()
            SettingsListRow(
                icon: "hand.raised",
                title: "Privacy Policy",
                subtitle: "What data the app stores and who can see it"
            ) {
                legalDocument = .privacy
            }
            SettingsRowDivider()
            SettingsListRow(
                icon: "list.bullet.rectangle",
                title: "Open source licenses",
                subtitle: "Third-party software used in the app"
            ) {
                showingLicenses = true
            }
        }
    }

    // MARK: - Development

    private var developmentSection: some View {
        SettingsGroupCard(title: "Development") {
            SettingsRowLabel(icon: "person.circle", title: "Developer", value: "Arkad", accessory: .none)
            SettingsRowDivider()
            SettingsRowLabel(icon: "hammer", title: "Built with", value: "SwiftUI & Firebase", accessory: .none)
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        SettingsGroupCard(title: "Support & feedback") {
            SettingsListRow(
                icon: "envelope",
                title: "Contact support",
                subtitle: "Email us with a question or a problem"
            ) {
                showingContactSupport = true
            }
            SettingsRowDivider()
            ShareLink(item: "I'm using Arkad to journal my trades and learn with other traders in communities.") {
                SettingsRowLabel(
                    icon: "square.and.arrow.up",
                    title: "Share Arkad",
                    subtitle: "Tell your friends about the app"
                )
            }
            .buttonStyle(SettingsRowButtonStyle())
        }
    }
}

// MARK: - Licenses View

struct LicensesView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    SettingsGroupCard(title: "Open source libraries") {
                        VStack(alignment: .leading, spacing: DS.Spacing.s) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Firebase iOS SDK")
                                    .font(.headline)
                                Spacer()
                                Tag(text: "Apache 2.0")
                            }
                            Text("Copyright Google LLC. Used for sign-in, the database, file storage and analytics. It includes supporting Google libraries under their own open source licenses.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(DS.Spacing.l)

                        SettingsRowDivider()

                        Link(destination: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!) {
                            SettingsRowLabel(
                                icon: "doc.plaintext",
                                title: "Read the Apache License 2.0",
                                accessory: .external
                            )
                        }
                        .buttonStyle(SettingsRowButtonStyle())
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .screenBackground()
            .navigationTitle("Licenses")
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
        "Export your trades and posts as CSV files, and delete your account in Settings",
        "Light and dark mode"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version \(AppInfo.version)")
                            .font(.system(size: 28, weight: .bold))
                        Text("First release")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.m) {
                        ForEach(changes, id: \.self) { change in
                            HStack(alignment: .top, spacing: DS.Spacing.m) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.goldText)
                                    .padding(.top, 1)
                                Text(change)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .cardStyle()
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .screenBackground()
            .navigationTitle("Release Notes")
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
}

#Preview {
    AboutView()
}
