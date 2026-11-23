// File: Core/Notifications/NotificationsInboxViewModel.swift
// Live list of the signed-in user's notifications, with mark-as-read.

import Foundation
import FirebaseFirestore

@MainActor
final class NotificationsInboxViewModel: ObservableObject {
    @Published private(set) var notifications: [UserNotification] = []
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?
    @Published var actionError: String?

    private var listener: ListenerRegistration?
    private var userId: String?

    var hasUnread: Bool {
        notifications.contains { !$0.isRead }
    }

    func start(userId: String) {
        guard listener == nil || self.userId != userId else { return }
        listener?.remove()
        self.userId = userId
        isLoading = notifications.isEmpty
        loadError = nil

        listener = FirebaseServices.shared.listenToNotifications(
            userId: userId,
            onChange: { [weak self] notifications in
                Task { @MainActor in
                    guard let self else { return }
                    self.notifications = notifications
                    self.isLoading = false
                    self.loadError = nil
                }
            },
            onError: { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    self.loadError = "Check your connection and try again."
                }
            }
        )
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func retry() {
        guard let userId else { return }
        stop()
        start(userId: userId)
    }

    func markRead(_ notification: UserNotification) {
        guard !notification.isRead,
              let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].isRead = true

        Task {
            do {
                try await FirebaseServices.shared.markNotificationAsRead(notificationId: notification.id)
            } catch {
                if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                    notifications[index].isRead = false
                }
            }
        }
    }

    func markAllRead() async {
        guard let userId, hasUnread else { return }
        let previous = notifications
        for index in notifications.indices {
            notifications[index].isRead = true
        }

        do {
            try await FirebaseServices.shared.markAllNotificationsAsRead(userId: userId)
        } catch {
            notifications = previous
            actionError = "Couldn't mark your notifications as read. Please try again."
        }
    }
}
