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
    @Published var errorMessage: String?
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
        errorMessage = nil
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
            errorMessage = nil
        } catch {
            errorMessage = ClassroomViewModel.friendly(error, doing: "load the events")
            return
        }
        if let userId {
            going = await service.rsvpedEventIds(
                communityId: community.id, eventIds: upcoming.map(\.id), userId: userId
            )
            await EventReminderScheduler.reconcile(
                communityId: community.id,
                communityName: community.name,
                goingTo: upcoming.filter { going.contains($0.id) }
            )
        }
    }

    // MARK: - Lookups

    func event(id: String) -> CommunityEvent? {
        upcoming.first { $0.id == id } ?? past.first { $0.id == id }
    }

    func isGoing(_ event: CommunityEvent) -> Bool { going.contains(event.id) }

    /// Re-reads one event (its RSVP count and the user's RSVP), for the detail screen.
    func refresh(eventId: String) async {
        guard let community else { return }
        guard let fresh = try? await service.fetchEvent(communityId: community.id, eventId: eventId) else {
            return
        }
        replace(fresh)
        if let userId {
            let ids = await service.rsvpedEventIds(communityId: community.id, eventIds: [eventId], userId: userId)
            if ids.contains(eventId) { going.insert(eventId) } else { going.remove(eventId) }
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
            try await service.setRSVP(nowGoing, communityId: community.id, eventId: event.id, userId: userId)
        } catch {
            setGoing(wasGoing, for: event)
            errorMessage = ClassroomViewModel.friendly(error, doing: nowGoing ? "RSVP" : "cancel your RSVP")
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
        // The time may have moved: refresh this user's own reminder
        if going.contains(event.id) {
            EventReminderScheduler.cancel(communityId: community.id, eventId: event.id)
            if !updated.isPast() {
                await EventReminderScheduler.schedule(updated, communityName: community.name)
            }
        }
    }

    func deleteEvent(_ event: CommunityEvent) async throws {
        guard let community else { return }
        try await service.deleteEvent(communityId: community.id, eventId: event.id, userId: userId)
        remove(eventId: event.id)
        going.remove(event.id)
        EventReminderScheduler.cancel(communityId: community.id, eventId: event.id)
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
