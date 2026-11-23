// File: Core/Notifications/PushNotificationManager.swift
// Push permission, this device's FCM token, the unread count for the Home bell, and
// routing notification taps. FirebaseAuthService tells it when the user signs in or out.

import Foundation
import UIKit
import UserNotifications
import FirebaseFirestore
import FirebaseMessaging

@MainActor
final class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()

    /// The system permission for this app's notifications
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    /// Unread notifications for the signed-in user, capped at `unreadLimit`
    @Published private(set) var unreadCount = 0

    static let unreadLimit = 99

    private var fcmToken: String?
    private var signedInUserId: String?
    private var unreadListener: ListenerRegistration?

    private init() {}

    // MARK: - Permission

    var isDenied: Bool { authorizationStatus == .denied }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Shows the system prompt (only the first time; later calls return the saved answer).
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        await refreshAuthorizationStatus()
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    /// Asks for permission only if the user hasn't answered yet. Use at moments where
    /// notifications clearly help, for example right after joining a first community.
    func requestAuthorizationIfNeeded() async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .notDetermined else { return }
        await requestAuthorization()
    }

    // MARK: - Tokens

    /// Called by the Messaging delegate whenever Firebase issues or refreshes the token.
    func didReceiveRegistrationToken(_ token: String?) {
        guard let token, !token.isEmpty, token != fcmToken else { return }
        let previous = fcmToken
        fcmToken = token

        guard let userId = signedInUserId else { return }
        Task {
            if let previous {
                try? await FirebaseServices.shared.deleteFCMToken(previous, userId: userId)
            }
            try? await FirebaseServices.shared.saveFCMToken(token, userId: userId)
        }
    }

    // MARK: - Session

    /// Saves this device's token for the user and starts the unread listener.
    func userDidSignIn(userId: String) {
        guard signedInUserId != userId else { return }
        stopSession()
        signedInUserId = userId
        startUnreadListener(userId: userId)

        Task {
            await refreshAuthorizationStatus()
            // Fails until APNs has registered; the delegate delivers the token later.
            if fcmToken == nil, let fetched = try? await Messaging.messaging().token(), fcmToken == nil {
                fcmToken = fetched
            }
            guard let token = fcmToken, signedInUserId == userId else { return }
            try? await FirebaseServices.shared.saveFCMToken(token, userId: userId)
        }
    }

    /// Removes this device's token while the user can still write their own documents.
    /// Call before signing out. Gives up after a few seconds so sign-out never hangs offline.
    func unregisterDevice() async {
        let userId = signedInUserId
        let token = fcmToken
        stopSession()
        guard let userId, let token else { return }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await FirebaseServices.shared.deleteFCMToken(token, userId: userId)
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(3))
            }
            _ = await group.next()
            group.cancelAll()
        }
    }

    /// Called once the user is signed out (or their account is deleted).
    func userDidSignOut() {
        stopSession()
    }

    private func stopSession() {
        unreadListener?.remove()
        unreadListener = nil
        signedInUserId = nil
        setUnreadCount(0)
    }

    // MARK: - Unread count

    private func startUnreadListener(userId: String) {
        unreadListener = FirebaseServices.shared.listenToUnreadNotificationCount(
            userId: userId,
            limit: Self.unreadLimit
        ) { [weak self] count in
            Task { @MainActor in
                guard let self, self.signedInUserId == userId else { return }
                self.setUnreadCount(count)
            }
        }
    }

    private func setUnreadCount(_ count: Int) {
        guard count != unreadCount else { return }
        unreadCount = count
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }

    // MARK: - Routing

    /// A push was tapped: mark its inbox entry read (the server sends `notificationId`)
    /// and open the screen it points to.
    func didTapNotification(id notificationId: String?, link: DeepLink?) {
        if let notificationId, !notificationId.isEmpty {
            Task {
                try? await FirebaseServices.shared.markNotificationAsRead(notificationId: notificationId)
            }
        }
        open(link)
    }

    /// Opens the screen a notification points to.
    func open(_ link: DeepLink?) {
        guard let link else { return }
        TabRouter.shared.open(link)
    }
}
