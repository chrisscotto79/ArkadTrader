// File: Core/Communities/Events/EventReminderScheduler.swift
// Local reminders for events the user RSVP'd to: one notification 15 minutes before the
// start, with the id `event_{cid}_{eventId}`. Un-RSVP cancels it. Permission is asked the
// same way price alerts ask (PushNotificationManager.requestAuthorizationIfNeeded).
// Tapping the reminder opens the community (data.route = "community").

import Foundation
import UserNotifications

@MainActor
enum EventReminderScheduler {
    static let leadTime: TimeInterval = 15 * 60

    enum Outcome {
        case scheduled
        /// Starts in less than 15 minutes (or already started): nothing to schedule
        case tooSoon
        /// The user hasn't allowed notifications
        case notAllowed
    }

    static func identifier(communityId: String, eventId: String) -> String {
        "event_\(communityId)_\(eventId)"
    }

    /// Asks for permission if it was never asked, then schedules the reminder.
    @discardableResult
    static func schedule(_ event: CommunityEvent, communityName: String) async -> Outcome {
        let fireDate = event.startsAt.addingTimeInterval(-leadTime)
        guard fireDate > Date() else { return .tooSoon }

        let manager = PushNotificationManager.shared
        await manager.requestAuthorizationIfNeeded()
        guard manager.canShowNotifications else { return .notAllowed }

        await add(event, communityName: communityName, fireDate: fireDate)
        return .scheduled
    }

    static func cancel(communityId: String, eventId: String) {
        let id = identifier(communityId: communityId, eventId: eventId)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Brings this community's pending reminders in line with what the user is going to:
    /// re-adds them (picking up edited times) and drops ones for events they left or that
    /// were deleted. Never prompts for permission.
    static func reconcile(communityId: String, communityName: String, goingTo events: [CommunityEvent]) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let prefix = "event_\(communityId)_"
        let wanted = Dictionary(uniqueKeysWithValues: events.map { (identifier(communityId: communityId, eventId: $0.id), $0) })

        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        let stale = pending.filter { wanted[$0] == nil }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: break
        default: return
        }
        for event in events {
            let fireDate = event.startsAt.addingTimeInterval(-leadTime)
            if fireDate > Date() {
                await add(event, communityName: communityName, fireDate: fireDate)
            } else {
                cancel(communityId: communityId, eventId: event.id)
            }
        }
    }

    /// Adding a request with an existing id replaces it.
    private static func add(_ event: CommunityEvent, communityName: String, fireDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "\(event.title) starts in 15 minutes"
        content.body = "\(communityName) · \(EventFormat.timeRange(event))"
        content.sound = .default
        content.userInfo = [
            "route": "community",
            "communityId": event.communityId,
            "eventId": event.id
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(communityId: event.communityId, eventId: event.id),
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
