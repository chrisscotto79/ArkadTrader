// File: Core/Settings/Views/SettingsView.swift
// Settings: profile, linked brokerages, payouts, data export, notifications, appearance,
// blocked accounts, help, about, sign out and account deletion.
// Linked brokerages and Payouts only show when AppConfig.brokerageLinkingEnabled and
// AppConfig.paidCommunitiesEnabled are on.
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
    @State private var showPasswordPrompt = false
    @State private var confirmPassword = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    profileCard
                    accountSection
                    preferencesSection
                    privacySection
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
            Text(deleteConfirmationMessage)
        }
        .alert("Confirm It's You", isPresented: $showPasswordPrompt) {
            SecureField("Password", text: $confirmPassword)
                .textContentType(.password)
            Button("Delete Account", role: .destructive) {
                reauthenticateAndDelete()
            }
            Button("Cancel", role: .cancel) {
                confirmPassword = ""
            }
        } message: {
            Text("For your security, enter your password to delete your account.")
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
            if AppConfig.brokerageLinkingEnabled {
                SettingsNavigationRow(icon: "building.columns", title: "Linked brokerages", subtitle: "Import trades from your broker, read-only") {
                    LinkedAccountsView()
                }
                SettingsRowDivider()
            }
            if AppConfig.paidCommunitiesEnabled {
                SettingsNavigationRow(icon: "banknote", title: "Payouts", subtitle: "Get paid for your community") {
                    PayoutsView()
                }
                SettingsRowDivider()
            }
            SettingsListRow(icon: "square.and.arrow.up", title: "Export data", subtitle: "Your trades and posts as CSV files") {
                showDataExport = true
            }
        }
    }

    private var preferencesSection: some View {
        SettingsGroupCard(title: "Preferences") {
            SettingsNavigationRow(icon: "bell.badge", title: "Notifications", subtitle: "Callouts, replies, followers and price alerts") {
                NotificationSettingsView()
            }
            SettingsRowDivider()
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

    private var privacySection: some View {
        SettingsGroupCard(title: "Privacy & safety") {
            SettingsNavigationRow(icon: "hand.raised", title: "Blocked accounts", subtitle: "People you've blocked can't reach you") {
                BlockedUsersView()
            }
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
        SettingsGroupCard(footer: "Permanently deletes your account and everything in it. This can't be undone.") {
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

    private var deleteConfirmationMessage: String {
        if AppConfig.serverFunctionsEnabled {
            return """
            This permanently deletes your Arkad account: your profile, posts, comments, trades and watchlist. Communities you own are deleted, and any paid subscriptions are cancelled.

            This can't be undone.
            """
        }
        return """
        This permanently deletes your Arkad account: your profile and photo, posts (with their comments and likes), trades, watchlist, price alerts, track record and followers. You leave the communities you've joined, and communities you own are deleted. Comments on other people's posts and messages in community chats stay.

        This can't be undone.
        """
    }

    /// With Cloud Functions, deletes the sign-in and the server removes everything else. In
    /// free mode the app removes your data first, then the sign-in (FirebaseAuthService).
    /// Either way, Firebase or the app asks for the password again if the last sign-in
    /// wasn't recent, before anything is deleted.
    private func deleteAccount() {
        isDeletingAccount = true
        Task {
            do {
                try await authService.deleteAccount()
                didDeleteAccount()
            } catch let error where Self.requiresRecentLogin(error) {
                isDeletingAccount = false
                confirmPassword = ""
                showPasswordPrompt = true
            } catch {
                showDeleteFailure(error)
            }
        }
    }

    private func reauthenticateAndDelete() {
        let password = confirmPassword
        confirmPassword = ""
        guard !password.isEmpty else { return }

        isDeletingAccount = true
        Task {
            do {
                try await authService.reauthenticate(password: password)
                try await authService.deleteAccount()
                didDeleteAccount()
            } catch {
                showDeleteFailure(error)
            }
        }
    }

    private func didDeleteAccount() {
        UserDefaults.standard.removeObject(forKey: "saved_email")
        isDeletingAccount = false
        // Signed out now: the app returns to the sign-in screen.
    }

    private func showDeleteFailure(_ error: Error) {
        isDeletingAccount = false
        deleteErrorMessage = Self.message(for: error)
        showDeleteError = true
    }

    private static func requiresRecentLogin(_ error: Error) -> Bool {
        if case AuthError.recentLoginRequired = error { return true }
        return AuthErrorCode(rawValue: (error as NSError).code) == .requiresRecentLogin
    }

    private static func message(for error: Error) -> String {
        switch AuthErrorCode(rawValue: (error as NSError).code) {
        case .wrongPassword, .invalidCredential:
            return "That password isn't right. Please try again."
        case .networkError:
            return "Check your connection and try again."
        default:
            return "Something went wrong: \(error.localizedDescription) Please try again."
        }
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

/// A settings row that pushes another screen onto the Settings navigation stack.
struct SettingsNavigationRow<Destination: View>: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var tint: Color = .goldText
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            SettingsRowLabel(
                icon: icon,
                title: title,
                subtitle: subtitle,
                value: value,
                tint: tint
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
