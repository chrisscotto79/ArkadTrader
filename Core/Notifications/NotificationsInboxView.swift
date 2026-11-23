// File: Core/Notifications/NotificationsInboxView.swift
// The notifications inbox, opened from the bell on Home. Presented as a sheet; it has its
// own NavigationStack. Tapping a notification marks it read, closes the inbox and opens
// the screen it points to.

import SwiftUI

struct NotificationsInboxView: View {
    @ObservedObject private var authService = FirebaseAuthService.shared
    @StateObject private var viewModel = NotificationsInboxViewModel()
    @Environment(\.dismiss) private var dismiss

    /// Opened once the sheet has gone, so the destination can present its own screens
    @State private var linkToOpen: DeepLink?

    var body: some View {
        NavigationStack {
            content
                .screenBackground()
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Mark all read") {
                            Task { await viewModel.markAllRead() }
                        }
                        .foregroundStyle(viewModel.hasUnread ? Color.goldText : Color.secondary)
                        .disabled(!viewModel.hasUnread)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.goldText)
                    }
                }
        }
        .onAppear {
            if let userId = authService.currentUser?.id {
                viewModel.start(userId: userId)
            }
        }
        .onDisappear {
            viewModel.stop()
            if let linkToOpen {
                PushNotificationManager.shared.open(linkToOpen)
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.actionError != nil },
                set: { if !$0 { viewModel.actionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.actionError ?? "")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if authService.currentUser == nil {
            EmptyStateView(
                systemImage: "bell.slash",
                title: "Sign in to see notifications",
                message: "Your notifications appear here once you're signed in."
            )
            .frame(maxHeight: .infinity)
        } else if viewModel.isLoading {
            ProgressView()
                .tint(Color.goldText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let loadError = viewModel.loadError, viewModel.notifications.isEmpty {
            EmptyStateView(
                systemImage: "wifi.exclamationmark",
                title: "Couldn't load notifications",
                message: loadError,
                actionTitle: "Try again"
            ) {
                viewModel.retry()
            }
            .frame(maxHeight: .infinity)
        } else if viewModel.notifications.isEmpty {
            EmptyStateView(
                systemImage: "bell",
                title: "No notifications yet",
                message: "Callouts, replies, new followers and price alerts will show up here."
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.s) {
                    ForEach(viewModel.notifications) { notification in
                        NotificationRow(notification: notification) {
                            open(notification)
                        }
                        .contextMenu {
                            if !notification.isRead {
                                Button {
                                    viewModel.markRead(notification)
                                } label: {
                                    Label("Mark as read", systemImage: "checkmark.circle")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.vertical, DS.Spacing.m)
            }
        }
    }

    private func open(_ notification: UserNotification) {
        viewModel.markRead(notification)
        guard let link = notification.deepLink else { return }
        linkToOpen = link
        dismiss()
    }
}

// MARK: - Row

private struct NotificationRow: View {
    let notification: UserNotification
    let action: () -> Void

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                IconWell(
                    systemName: NotificationKind.systemImage(for: notification.type),
                    tint: NotificationKind.tint(for: notification.type),
                    size: 40
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                        Text(notification.title)
                            .font(.subheadline.weight(notification.isRead ? .medium : .semibold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                        Spacer(minLength: DS.Spacing.xs)
                        Text(notification.createdAt.timeAgoDisplay)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    if !notification.body.isEmpty {
                        Text(notification.body)
                            .font(.subheadline)
                            .foregroundStyle(notification.isRead ? HierarchicalShapeStyle.tertiary : HierarchicalShapeStyle.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .multilineTextAlignment(.leading)

                Circle()
                    .fill(Color.arkadGold)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                    .opacity(notification.isRead ? 0 : 1)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background {
                // Unread rows get a soft gold wash over the card surface
                ZStack {
                    cardShape.fill(Color.surface)
                    cardShape.fill(Color.goldTint)
                        .opacity(notification.isRead ? 0 : 1)
                }
            }
            .overlay(cardShape.strokeBorder(Color.hairline, lineWidth: 1))
            .contentShape(cardShape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(notification.isRead ? "" : "Unread")
        .animation(.easeOut(duration: 0.2), value: notification.isRead)
    }
}

#Preview {
    NotificationsInboxView()
}
