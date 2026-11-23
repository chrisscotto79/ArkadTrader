// File: Core/Settings/Views/SettingsView.swift
// Settings: profile, data export, appearance, help, about, sign out and account deletion.
// Also defines the grouped-card row components shared by the other Settings screens.

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    @AppStorage(AppAppearance.storageKey) private var appearance: String = AppAppearance.system.rawValue

    @State private var showEditProfile = false
    @State private var showDataExport = false
    @State private var showHelpCenter = false
    @State private var showContactSupport = false
    @State private var showAbout = false

    // Account deletion
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    /// Firebase only allows deleting an account shortly after signing in.
    private static let recentLoginWindow: TimeInterval = 5 * 60

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    profileCard
                    accountSection
                    preferencesSection
                    supportSection
                    aboutSection
                    logOutSection
                    deleteSection

                    Text(AppInfo.versionLine)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .screenBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.goldText)
                    .disabled(isDeletingAccount)
                }
            }
        }
        .overlay {
            if isDeletingAccount {
                deletingOverlay
            }
        }
        .interactiveDismissDisabled(isDeletingAccount)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showDataExport) {
            DataExportView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showHelpCenter) {
            HelpCenterView()
        }
        .sheet(isPresented: $showContactSupport) {
            ContactSupportView()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Delete Account", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("""
            This permanently deletes your Arkad sign-in and your profile (name, username and bio). It can't be undone.

            Trades, posts, comments, images and community messages you created are not removed by this step. To have them removed too, email \(AppInfo.supportEmail).
            """)
        }
        .alert("Couldn't Delete Account", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        Button {
            showEditProfile = true
        } label: {
            HStack(spacing: DS.Spacing.m) {
                ProfileImageView(user: authService.currentUser, size: 56)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    if let username = authService.currentUser?.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: DS.Spacing.s)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .cardStyle()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Edit your profile")
    }

    // MARK: - Sections

    private var accountSection: some View {
        SettingsGroupCard(title: "Account") {
            SettingsListRow(icon: "person.crop.circle", title: "Edit profile", subtitle: "Photo, name, username and bio") {
                showEditProfile = true
            }
            SettingsRowDivider()
            SettingsListRow(icon: "square.and.arrow.up", title: "Export data", subtitle: "Your trades and posts as CSV files") {
                showDataExport = true
            }
        }
    }

    private var preferencesSection: some View {
        SettingsGroupCard(title: "Preferences") {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                HStack(spacing: DS.Spacing.m) {
                    IconWell(systemName: "circle.lefthalf.filled", size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Appearance")
                            .font(.body.weight(.medium))
                        Text("Follow your device, or always use light or dark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                SegmentedPicker(options: AppAppearance.allCases, selection: appearanceSelection) { option in
                    option.title
                }
                .accessibilityLabel("Appearance")
            }
            .padding(DS.Spacing.l)
        }
    }

    private var supportSection: some View {
        SettingsGroupCard(title: "Support") {
            SettingsListRow(icon: "questionmark.circle", title: "Help Center", subtitle: "Answers to common questions") {
                showHelpCenter = true
            }
            SettingsRowDivider()
            SettingsListRow(icon: "envelope", title: "Contact support", subtitle: "Email the Arkad team") {
                showContactSupport = true
            }
        }
    }

    private var aboutSection: some View {
        SettingsGroupCard(title: "About") {
            SettingsListRow(icon: "info.circle", title: "About Arkad", value: "v\(AppInfo.version)") {
                showAbout = true
            }
        }
    }

    private var logOutSection: some View {
        SettingsGroupCard {
            SettingsListRow(
                icon: "rectangle.portrait.and.arrow.right",
                title: "Log out",
                tint: .secondary,
                accessory: .none
            ) {
                Task {
                    await authService.logout()
                }
            }
            .disabled(isDeletingAccount)
        }
    }

    private var deleteSection: some View {
        SettingsGroupCard(footer: "Permanently deletes your sign-in and profile. This can't be undone.") {
            SettingsListRow(
                icon: "trash",
                title: "Delete account",
                tint: .marketRed,
                titleColor: .marketRed,
                accessory: .none
            ) {
                showDeleteConfirmation = true
            }
            .disabled(isDeletingAccount)
        }
    }

    private var deletingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            VStack(spacing: DS.Spacing.m) {
                ProgressView()
                    .tint(Color.goldText)
                Text("Deleting account…")
                    .font(.subheadline.weight(.medium))
            }
            .padding(DS.Spacing.xl)
            .cardStyle(padding: 0)
        }
        .transition(.opacity)
    }

    // MARK: - Appearance

    private var appearanceSelection: Binding<AppAppearance> {
        Binding(
            get: { AppAppearance(rawValue: appearance) ?? .system },
            set: { appearance = $0.rawValue }
        )
    }

    // MARK: - Account Deletion

    private func deleteAccount() {
        // FirebaseAuthService.deleteAccount() removes the profile document before the
        // sign-in. Check for a recent sign-in first so Firebase can't reject the second
        // step after the first has already happened.
        if let lastSignIn = Auth.auth().currentUser?.metadata.lastSignInDate,
           Date().timeIntervalSince(lastSignIn) > Self.recentLoginWindow {
            deleteErrorMessage = Self.recentLoginMessage
            showDeleteError = true
            return
        }

        isDeletingAccount = true
        Task {
            do {
                try await authService.deleteAccount()
                UserDefaults.standard.removeObject(forKey: "saved_email")
                isDeletingAccount = false
                // Signed out now: the app returns to the sign-in screen.
            } catch {
                isDeletingAccount = false
                deleteErrorMessage = Self.message(for: error)
                showDeleteError = true
            }
        }
    }

    private static let recentLoginMessage = "For your security, you need to have signed in recently to delete your account. Sign out, sign back in, then come back here and try again."

    private static func message(for error: Error) -> String {
        let nsError = error as NSError
        if AuthErrorCode(rawValue: nsError.code) == .requiresRecentLogin {
            return recentLoginMessage
        }
        return "Something went wrong: \(error.localizedDescription) Please try again."
    }

    // MARK: - Helper Properties

    private var displayName: String {
        guard let user = authService.currentUser else { return "Your account" }
        if !user.fullName.isEmpty { return user.fullName }
        return user.username.isEmpty ? "Your account" : user.username
    }
}

// MARK: - Grouped Card Components (shared by the Settings screens)

/// A titled group of rows on a single card, with an optional footnote underneath.
struct SettingsGroupCard<Content: View>: View {
    var title: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            if let title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.xs)
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
            .cardStyle(padding: 0)

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.xs)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The visual content of a settings row: icon well, title, optional subtitle/value and an accessory.
struct SettingsRowLabel: View {
    enum Accessory {
        case chevron, external, share, none
    }

    let icon: String
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var tint: Color = .goldText
    var titleColor: Color = .primary
    var accessory: Accessory = .chevron

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: icon, tint: tint, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(titleColor)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .multilineTextAlignment(.leading)

            Spacer(minLength: DS.Spacing.s)

            if let value {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            accessoryView
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        case .external:
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        case .share:
            Image(systemName: "square.and.arrow.up")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.goldText)
        case .none:
            EmptyView()
        }
    }
}

/// A tappable settings row.
struct SettingsListRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var tint: Color = .goldText
    var titleColor: Color = .primary
    var accessory: SettingsRowLabel.Accessory = .chevron
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowLabel(
                icon: icon,
                title: title,
                subtitle: subtitle,
                value: value,
                tint: tint,
                titleColor: titleColor,
                accessory: accessory
            )
        }
        .buttonStyle(SettingsRowButtonStyle())
    }
}

/// Row press feedback: a soft fill behind the row.
struct SettingsRowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.surfaceRaised : Color.clear)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Hairline between rows, inset to line up with the row titles.
struct SettingsRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(height: 1)
            .padding(.leading, DS.Spacing.l + 34 + DS.Spacing.m)
    }
}

#Preview {
    SettingsView()
        .environmentObject(FirebaseAuthService.shared)
}
