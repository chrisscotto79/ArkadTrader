// File: Core/Settings/Views/SettingsView.swift
// Settings: profile, data export, help, about, sign out and account deletion.

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
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
        NavigationView {
            VStack(spacing: 0) {
                // Profile header section
                profileHeaderSection

                // Settings list
                settingsListSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                    .fontWeight(.semibold)
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
            This permanently deletes your ArkadTrader sign-in and your profile (name, username and bio). It can't be undone.

            Trades, posts, comments, images and community messages you created are not removed by this step. To have them removed too, email \(AppInfo.supportEmail).
            """)
        }
        .alert("Couldn't Delete Account", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
    }

    // MARK: - Profile Header Section
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // User avatar and info
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.arkadGold, Color.arkadGoldLight]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .overlay(
                        Text(initials)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.arkadGold.opacity(0.4), radius: 8, x: 0, y: 4)

                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text(authService.currentUser?.fullName ?? "Unknown User")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)

                    Text("@\(authService.currentUser?.username ?? "username")")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color.backgroundSecondary)
    }

    // MARK: - Settings List Section
    private var settingsListSection: some View {
        List {
            Section("Account") {
                SettingsRowView(
                    icon: "person.circle",
                    title: "Edit Profile",
                    color: .blue
                ) {
                    showEditProfile = true
                }

                SettingsRowView(
                    icon: "square.and.arrow.up",
                    title: "Export Data",
                    color: .marketGreen
                ) {
                    showDataExport = true
                }
            }

            Section("Support") {
                SettingsRowView(
                    icon: "questionmark.circle",
                    title: "Help Center",
                    color: .gray
                ) {
                    showHelpCenter = true
                }

                SettingsRowView(
                    icon: "envelope",
                    title: "Contact Support",
                    color: .gray
                ) {
                    showContactSupport = true
                }

                SettingsRowView(
                    icon: "info.circle",
                    title: "About ArkadTrader",
                    color: .gray
                ) {
                    showAbout = true
                }
            }

            Section {
                SettingsRowView(
                    icon: "arrow.right.square",
                    title: "Logout",
                    color: .red
                ) {
                    Task {
                        await authService.logout()
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 24, height: 24)
                        Text("Delete Account")
                            .font(.body)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .foregroundColor(.marketRed)
                    .padding(.vertical, 4)
                }
                .disabled(isDeletingAccount)
            } footer: {
                Text("Permanently deletes your sign-in and profile. This can't be undone.")
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    private var deletingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                Text("Deleting account...")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
        }
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
    private var initials: String {
        guard let user = authService.currentUser else { return "U" }
        let names = user.fullName.split(separator: " ")
        let first = names.first?.first.map(String.init) ?? "U"
        let last = names.count > 1 ? (names.last?.first.map(String.init) ?? "") : ""
        return (first + last).uppercased()
    }
}

// MARK: - Settings Row View
struct SettingsRowView: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.textTertiary)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
