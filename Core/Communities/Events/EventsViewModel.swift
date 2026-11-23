// File: Core/Communities/Events/EventsViewModel.swift
// State for a community's "Events" tab: upcoming and past events, which ones the user is
// going to, and the RSVP toggle (with its local reminder). Staff create, edit and delete.

import Foundation
import FirebaseAuth

@MainActor
final class EventsViewModel: ObservableObject {
    @Published private(set) var upcoming: [CommunityEvent] = []
    @Published private(set) var past: [CommunityEvent] = []
    /// Event ids the signed-in user RSVP'd to
    @Published private(set) var going: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    /// Events with an RSVP write in flight
    @Published private(set) var busyEventIds: Set<String> = []
    /// Why the events couldn't be loaded: shown in place of the list before the first load,
    /// as a banner over the loaded list after that.
    @Published var loadError: String?
    /// Why an RSVP or a staff action failed (an alert)
    @Published var actionError: String?
    /// A gentle note after an RSVP (for example, reminders are off)
    @Published var notice: String?

    private(set) var community: Community?
    private let service = EventsService.shared

    private var userId: String? { Auth.auth().currentUser?.uid }

    // MARK: - Loading

    func configure(community: Community) {
        guard community.id != self.community?.id else {
            self.community = community
            return
        }
        self.community = community
        upcoming = []
        past = []
        going = []
        hasLoaded = false
        loadError = nil
        actionError = nil
    }

    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else { return }
        await reload()
    }

    func reload() async {
        guard let community else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await service.fetchEvents(communityId: community.id)
            upcoming = result.upcoming
            past = result.past
            hasLoaded = true
            loadError = nil
        } catch {
            loadError = ClassroomViewModel.friendly(error, doing: "load the events")
            return
        }
        guard let userId else { return }
        // If the RSVPs can't be read, keep what we had and leave the reminders alone.
        guard let ids = try? await service.rsvpedEventIds(communityId: community.id, userId: userId) else { return }
        going = ids
        await EventReminderScheduler.reconcile(
            communityId: community.id,
            communityName: community.name,
            goingTo: upcoming.filter { going.contains($0.id) }
        )
    }

    // MARK: - Lookups

    func event(id: String) -> CommunityEvent? {
        upcoming.first { $0.id == id } ?? past.first { $0.id == id }
    }

    func isGoing(_ event: CommunityEvent) -> Bool { going.contains(event.id) }

    /// Re-reads one event (its RSVP count and the user's RSVP), for the detail screen.
    /// An event that no longer exists is removed, with its reminder.
    func refresh(eventId: String) async {
        guard let community else { return }
        let fresh: CommunityEvent?
        do {
            fresh = try await service.fetchEvent(communityId: community.id, eventId: eventId)
        } catch {
            return  // offline: keep showing what we have
        }
        guard let fresh else {
            removeGone(eventId: eventId)
            return
        }
        replace(fresh)
        if let userId, let ids = try? await service.rsvpedEventIds(communityId: community.id, userId: userId) {
            if ids.contains(eventId) { going.insert(eventId) } else { going.remove(eventId) }
        }
    }

    /// The event was deleted: drop it, its reminder and the user's RSVP mirror.
    private func removeGone(eventId: String) {
        guard let community else { return }
        let wasGoing = going.contains(eventId)
        remove(eventId: eventId)
        going.remove(eventId)
        EventReminderScheduler.cancel(communityId: community.id, eventId: eventId)
        if wasGoing, let userId {
            Task { await service.removeRSVPMirror(eventId: eventId, userId: userId) }
        }
    }

    // MARK: - RSVP

    func toggleRSVP(_ event: CommunityEvent) async {
        guard let community, let userId, !busyEventIds.contains(event.id) else { return }
        let wasGoing = going.contains(event.id)
        let nowGoing = !wasGoing

        busyEventIds.insert(event.id)
        defer { busyEventIds.remove(event.id) }

        // Optimistic: flip first, roll back if the batch fails
        setGoing(nowGoing, for: event)
        do {
            let changed = try await service.setRSVP(nowGoing, communityId: community.id, eventId: event.id, userId: userId)
            // Already in that state (another device): our optimistic count is off, so re-read it
            if !changed {
                if let fresh = try? await service.fetchEvent(communityId: community.id, eventId: event.id) {
                    replace(fresh)
                }
            }
        } catch {
            setGoing(wasGoing, for: event)
            actionError = ClassroomViewModel.friendly(error, doing: nowGoing ? "RSVP" : "cancel your RSVP")
            return
        }

        if nowGoing {
            HapticManager.shared.notification(type: .success)
            switch await EventReminderScheduler.schedule(event, communityName: community.name) {
            case .scheduled:
                notice = "You're going. We'll remind you 15 minutes before it starts."
            case .notAllowed:
                notice = "You're going. Turn on notifications for Arkad in Settings to get a reminder 15 minutes before."
            case .tooSoon:
                notice = nil
            }
        } else {
            EventReminderScheduler.cancel(communityId: community.id, eventId: event.id)
            notice = nil
        }
    }

    private func setGoing(_ isGoing: Bool, for event: CommunityEvent) {
        let alreadyGoing = going.contains(event.id)
        guard alreadyGoing != isGoing else { return }
        if isGoing { going.insert(event.id) } else { going.remove(event.id) }
        guard var updated = self.event(id: event.id) else { return }
        updated.rsvpCount = max(updated.rsvpCount + (isGoing ? 1 : -1), 0)
        replace(updated)
    }

    // MARK: - Staff

    func createEvent(_ draft: EventDraft) async throws {
        guard let community, let userId else { throw ClassroomError.signedOut }
        let event = try await service.createEvent(communityId: community.id, draft: draft, createdBy: userId)
        insert(event)
        // Fan-out runs on its own so the sheet can close right away
        Task { await service.notifyMembers(of: event, community: community) }
    }

    func updateEvent(_ event: CommunityEvent, draft: EventDraft) async throws {
        guard let community else { return }
        try await service.updateEvent(communityId: community.id, eventId: event.id, draft: draft)
        var updated = event
        updated.title = draft.title
        updated.details = draft.details
        updated.startsAt = draft.startsAt
        updated.durationMinutes = draft.durationMinutes
        let link = draft.link.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.link = link.isEmpty ? nil : link
        remove(eventId: event.id)
        insert(updated)
        // The time may have moved: refresh this user's own reminder and tell the people going
        if going.contains(event.id) {
            EventReminderScheduler.cancel(communityId: community.id, eventId: event.id)
            if !updated.isPast() {
                await EventReminderScheduler.schedule(updated, communityName: community.name)
            }
        }
        if updated.startsAt != event.startsAt || updated.durationMinutes != event.durationMinutes {
            let service = self.service
            Task {
                let ids = await service.rsvpUserIds(communityId: community.id, eventId: updated.id)
                await service.notifyRSVPs(ids, about: updated, community: community, cancelled: false)
            }
        }
    }

    func deleteEvent(_ event: CommunityEvent) async throws {
        guard let community else { return }
        // Who to tell: the RSVPs can't be listed once the event is gone
        let goingIds = event.isPast() ? [] : await service.rsvpUserIds(communityId: community.id, eventId: event.id)
        try await service.deleteEvent(communityId: community.id, eventId: event.id, userId: userId)
        remove(eventId: event.id)
        going.remove(event.id)
        EventReminderScheduler.cancel(communityId: community.id, eventId: event.id)
        if !goingIds.isEmpty {
            let service = self.service
            Task { await service.notifyRSVPs(goingIds, about: event, community: community, cancelled: true) }
        }
    }

    // MARK: - List upkeep

    private func insert(_ event: CommunityEvent) {
        if event.isPast() {
            past = (past + [event]).sorted { $0.startsAt > $1.startsAt }
        } else {
            upcoming = (upcoming + [event]).sorted { $0.startsAt < $1.startsAt }
        }
    }

    private func remove(eventId: String) {
        upcoming.removeAll { $0.id == eventId }
        past.removeAll { $0.id == eventId }
    }

    private func replace(_ event: CommunityEvent) {
        if let index = upcoming.firstIndex(where: { $0.id == event.id }) {
            upcoming[index] = event
        } else if let index = past.firstIndex(where: { $0.id == event.id }) {
            past[index] = event
        }
    }
}
