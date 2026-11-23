// File: Core/Notifications/NotificationSettingsView.swift
// Settings > Notifications: the system permission, and a toggle for each
// `notificationPrefs` key. Pushed inside the Settings NavigationStack.
// In free mode there's no remote push: the toggles choose what the inbox shows, and the system
// permission is only used for price alert banners while Arkad is open.

import SwiftUI
import UIKit

struct NotificationSettingsView: View {
    @ObservedObject private var authService = FirebaseAuthService.shared
    @ObservedObject private var pushManager = PushNotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                permissionSection

                ForEach(NotificationPreference.groups) { group in
                    SettingsGroupCard(title: group.title) {
                        ForEach(Array(group.items.enumerated()), id: \.element) { index, preference in
                            if index > 0 {
                                SettingsRowDivider()
                            }
                            preferenceRow(preference)
                        }
                    }
                }

                Text(footerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DS.Spacing.l)
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .screenBackground()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await pushManager.refreshAuthorizationStatus() }
        .onChange(of: scenePhase) { _, phase in
            // Pick up changes made in the Settings app
            if phase == .active {
                Task { await pushManager.refreshAuthorizationStatus() }
            }
        }
        .alert(
            "Couldn't save",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Permission

    @ViewBuilder
    private var permissionSection: some View {
        switch pushManager.authorizationStatus {
        case .denied:
            SettingsGroupCard(footer: deniedFooter) {
                SettingsListRow(
                    icon: "bell.slash.fill",
                    title: "Turn on in Settings",
                    subtitle: "Opens Arkad's notification settings",
                    tint: .marketRed,
                    accessory: .external
                ) {
                    openSystemSettings()
                }
            }
        case .notDetermined:
            SettingsGroupCard(footer: "You'll be asked to allow notifications from Arkad.") {
                SettingsListRow(
                    icon: "bell.badge.fill",
                    title: usesRemotePush ? "Turn on notifications" : "Get price alerts",
                    subtitle: usesRemotePush
                        ? "Callouts, replies and price alerts as they happen"
                        : "A banner when an alert you set triggers, while Arkad is open",
                    accessory: .none
                ) {
                    Task { await pushManager.requestAuthorization() }
                }
            }
        default:
            EmptyView()
        }
    }

    private var usesRemotePush: Bool { AppConfig.serverFunctionsEnabled }

    private var deniedFooter: String {
        usesRemotePush
            ? "Notifications are turned off for Arkad on this device. Your choices below are saved, but nothing is delivered until you turn them on."
            : "Notifications are turned off for Arkad on this device, so price alerts can't show a banner. Everything still appears in your inbox."
    }

    private var footerText: String {
        usesRemotePush
            ? "Arkad only sends notifications about communities you're in, people you follow and alerts you set."
            : "These choices control what appears in your inbox, the bell on Home. Price alerts also show a banner while Arkad is open."
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
        }
    }

    // MARK: - Preferences

    private func preferenceRow(_ preference: NotificationPreference) -> some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: preference.systemImage, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(preference.title)
                    .font(.body.weight(.medium))
                Text(preference.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: DS.Spacing.s)

            Toggle(preference.title, isOn: binding(for: preference))
                .labelsHidden()
                .tint(Color.arkadGold)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .frame(minHeight: 58)
    }

    private func binding(for preference: NotificationPreference) -> Binding<Bool> {
        Binding(
            get: { authService.currentUser?.isNotificationEnabled(preference.rawValue) ?? true },
            set: { enabled in
                Task {
                    do {
                        try await authService.setNotificationPreference(preference, enabled: enabled)
                    } catch {
                        errorMessage = "Your change to \(preference.title.lowercased()) wasn't saved. Check your connection and try again."
                    }
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
