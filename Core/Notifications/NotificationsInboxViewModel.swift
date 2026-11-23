// File: Core/Notifications/NotificationsInboxViewModel.swift
// Live list of the signed-in user's notifications, with mark-as-read.
// Leaves out notifications from blocked people and, in free mode, the types turned off in
// Settings > Notifications (see InboxFilter).

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class NotificationsInboxViewModel: ObservableObject {
    @Published private(set) var notifications: [UserNotification] = []
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?
    @Published var actionError: String?

    /// Everything the listener returned, before filtering
    private var entries: [InboxEntry] = []
    private var listener: ListenerRegistration?
    private var userId: String?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Re-filter when the block list or the notification preferences change
        BlockStore.shared.$blockedIds
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in self?.applyFilter() }
            }
            .store(in: &cancellables)

        FirebaseAuthService.shared.$currentUser
            .map { $0?.notificationPrefs ?? [:] }
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in self?.applyFilter() }
            }
            .store(in: &cancellables)
    }

    var hasUnread: Bool {
        notifications.contains { !$0.isRead }
    }

    func start(userId: String) {
        guard listener == nil || self.userId != userId else { return }
        listener?.remove()
        self.userId = userId
        isLoading = notifications.isEmpty
        loadError = nil

        Task { await BlockStore.shared.loadIfNeeded() }

        listener = FirebaseServices.shared.listenToInbox(
            userId: userId,
            onChange: { [weak self] entries in
                Task { @MainActor in
                    guard let self else { return }
                    self.entries = entries
                    self.applyFilter()
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

    private func applyFilter() {
        notifications = entries.filter { InboxFilter.isVisible($0) }.map(\.notification)
    }

    func markRead(_ notification: UserNotification) {
        guard !notification.isRead,
              let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].isRead = true
        setEntryRead(notification.id, true)

        Task {
            do {
                try await FirebaseServices.shared.markNotificationAsRead(notificationId: notification.id)
            } catch {
                if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                    notifications[index].isRead = false
                }
                setEntryRead(notification.id, false)
            }
        }
    }

    func markAllRead() async {
        guard let userId, hasUnread else { return }
        let previousNotifications = notifications
        let previousEntries = entries
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        for index in entries.indices {
            entries[index].notification.isRead = true
        }

        do {
            try await FirebaseServices.shared.markAllNotificationsAsRead(userId: userId)
        } catch {
            notifications = previousNotifications
            entries = previousEntries
            actionError = "Couldn't mark your notifications as read. Please try again."
        }
    }

    private func setEntryRead(_ id: String, _ isRead: Bool) {
        if let index = entries.firstIndex(where: { $0.notification.id == id }) {
            entries[index].notification.isRead = isRead
        }
    }
}
