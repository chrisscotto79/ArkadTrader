// File: Core/Notifications/NotificationsInboxViewModel.swift
// Live list of the signed-in user's notifications, with mark-as-read, delete and
// "Show older" (the listener's limit grows by a page each time).
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
    @Published private(set) var isLoadingOlder = false

    private static let pageSize = 50
    private static let maxLimit = 500
    /// How many of the newest notifications the listener covers
    private var limit = pageSize

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

    /// True when the listener came back full, so there may be older notifications.
    var canLoadOlder: Bool {
        entries.count >= limit && limit < Self.maxLimit
    }

    func start(userId: String) {
        guard listener == nil || self.userId != userId else { return }
        listener?.remove()
        if self.userId != userId { limit = Self.pageSize }
        self.userId = userId
        isLoading = notifications.isEmpty
        loadError = nil

        Task { await BlockStore.shared.loadIfNeeded() }

        listener = FirebaseServices.shared.listenToInbox(
            userId: userId,
            limit: limit,
            onChange: { [weak self] entries in
                Task { @MainActor in
                    guard let self else { return }
                    self.entries = entries.filter { !self.deletedIds.contains($0.notification.id) }
                    self.applyFilter()
                    self.isLoading = false
                    self.isLoadingOlder = false
                    self.loadError = nil
                }
            },
            onError: { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    self.isLoadingOlder = false
                    self.loadError = "Check your connection and try again."
                }
            }
        )
    }

    /// Shows the next page of older notifications.
    func loadOlder() {
        guard let userId, canLoadOlder, !isLoadingOlder else { return }
        isLoadingOlder = true
        limit = min(limit + Self.pageSize, Self.maxLimit)
        stop()
        start(userId: userId)
    }

    /// Ids deleted here, kept out of the list while the listener catches up.
    private var deletedIds: Set<String> = []

    func delete(_ notification: UserNotification) {
        let previousEntries = entries
        deletedIds.insert(notification.id)
        entries.removeAll { $0.notification.id == notification.id }
        applyFilter()

        Task {
            do {
                try await FirebaseServices.shared.deleteNotification(notificationId: notification.id)
            } catch {
                deletedIds.remove(notification.id)
                entries = previousEntries
                applyFilter()
                actionError = "Couldn't delete that notification. Try again."
            }
        }
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
