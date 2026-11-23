// File: Core/Communities/Events/EventReminderScheduler.swift
// Local reminders for events the user RSVP'd to: one notification 15 minutes before the
// start, with the id `event_{cid}_{eventId}`. Un-RSVP cancels it. Permission is asked the
// same way price alerts ask (PushNotificationManager.requestAuthorizationIfNeeded).
// Tapping the reminder opens the community (data.route = "community").
// `reconcileAll()` runs when the app comes to the foreground: it drops reminders for events
// that were cancelled or that the user left on another device, and moves ones whose time changed.

import Foundation
import FirebaseAuth
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

    private static let lastReconcileKey = "eventReminders.lastReconcileAt"
    private static let reconcileInterval: TimeInterval = 60 * 60
    private static var isReconcilingAll = false

    /// Checks every pending event reminder against the event and the user's RSVPs (one query
    /// plus one read per reminder), at most once an hour. Never prompts for permission.
    static func reconcileAll() async {
        guard !isReconcilingAll, let userId = Auth.auth().currentUser?.uid else { return }
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: lastReconcileKey) as? Date,
           Date().timeIntervalSince(last) < reconcileInterval { return }
        isReconcilingAll = true
        defer { isReconcilingAll = false }

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("event_") }
        guard !pending.isEmpty else {
            defaults.set(Date(), forKey: lastReconcileKey)
            return
        }
        // If the RSVPs can't be read, change nothing.
        guard let going = try? await EventsService.shared.allRSVPs(userId: userId) else { return }
        defaults.set(Date(), forKey: lastReconcileKey)

        for request in pending {
            let info = request.content.userInfo
            guard let communityId = info["communityId"] as? String,
                  let eventId = info["eventId"] as? String else { continue }
            guard going[eventId] == communityId else {
                cancel(communityId: communityId, eventId: eventId)
                continue
            }
            let event: CommunityEvent?
            do {
                event = try await EventsService.shared.fetchEvent(communityId: communityId, eventId: eventId)
            } catch {
                continue  // offline or no access: leave it
            }
            guard let event else {
                cancel(communityId: communityId, eventId: eventId)
                await EventsService.shared.removeRSVPMirror(eventId: eventId, userId: userId)
                continue
            }
            let fireDate = event.startsAt.addingTimeInterval(-leadTime)
            guard fireDate > Date() else {
                cancel(communityId: communityId, eventId: eventId)
                continue
            }
            let communityName = info["communityName"] as? String ?? ""
            await add(event, communityName: communityName, fireDate: fireDate)
        }
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
        content.body = communityName.isEmpty
            ? EventFormat.timeRange(event)
            : "\(communityName) · \(EventFormat.timeRange(event))"
        content.sound = .default
        content.userInfo = [
            "route": "community",
            "communityId": event.communityId,
            "eventId": event.id,
            "communityName": communityName
        ]

        // A time interval fires at the same instant whatever time zone the phone moves to
        // (calendar components without a time zone would float with it).
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 1 else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(communityId: event.communityId, eventId: event.id),
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
