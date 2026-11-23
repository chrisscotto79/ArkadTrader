// File: Core/Notifications/AppDelegate.swift
// UIKit hooks that SwiftUI doesn't offer: APNs registration, the FCM token, and showing and
// handling notifications. Attached in ArkadTraderApp with @UIApplicationDelegateAdaptor.
// In free mode (no Cloud Functions) only the local-notification parts are used.
//
// Firebase method swizzling is left on (the default), so Messaging also receives the APNs
// token automatically; setting it below as well keeps things working if swizzling is turned off.

import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // Registering doesn't prompt the user; it only gets an APNs token. Permission is asked
        // later, at the end of onboarding or from Settings > Notifications.
        // Free mode has no remote push, so there's no token to get. The notification center
        // delegate above still shows local notifications (price alerts) and routes their taps.
        if AppConfig.serverFunctionsEnabled {
            application.registerForRemoteNotifications()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected on the simulator without push support. Nothing else to do.
    }
}

// MARK: - Firebase Messaging

extension AppDelegate: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            PushNotificationManager.shared.didReceiveRegistrationToken(fcmToken)
        }
    }
}

// MARK: - Notification center

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Shows notifications as a banner while the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }

    /// The user tapped a notification: open the screen its `data.route` points to.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        Messaging.messaging().appDidReceiveMessage(userInfo)
        let link = DeepLink(payload: userInfo)
        let notificationId = userInfo["notificationId"] as? String
        await MainActor.run {
            PushNotificationManager.shared.didTapNotification(id: notificationId, link: link)
        }
    }
}
