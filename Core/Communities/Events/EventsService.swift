// File: Core/Communities/Events/EventsService.swift
// Firestore reads and writes for community events. Every write matches the
// `match /events/{eventId}` rules in firestore.rules:
// - staff create (rsvpCount 0, createdBy = me, https link or none), edit (never createdBy or
//   rsvpCount) and delete;
// - an RSVP creates or deletes rsvps/{me} and moves rsvpCount by exactly 1 in the same batch.
// Creating an event notifies the members (`community_event`), fanned out like callouts.

import Foundation
import FirebaseFirestore

final class EventsService {
    static let shared = EventsService()

    private var db: Firestore { FirebaseServices.shared.db }

    /// How far back an event can have started and still be "upcoming" (still running).
    private let liveWindow: TimeInterval = 24 * 60 * 60

    private init() {}

    private func events(_ communityId: String) -> CollectionReference {
        db.collection("communities").document(communityId).collection("events")
    }

    // MARK: - Reading

    /// Upcoming (and running) events, soonest first, plus the most recent past ones.
    /// Each query filters and orders on `startsAt` only, so no composite index is needed.
    func fetchEvents(communityId: String, pastLimit: Int = 20) async throws -> (upcoming: [CommunityEvent], past: [CommunityEvent]) {
        let now = Date()
        let cutoff = Timestamp(date: now.addingTimeInterval(-liveWindow))

        async let recentSnapshot = events(communityId)
            .whereField("startsAt", isGreaterThanOrEqualTo: cutoff)
            .order(by: "startsAt")
            .limit(to: 50)
            .getDocuments()
        async let pastSnapshot = events(communityId)
            .whereField("startsAt", isLessThan: cutoff)
            .order(by: "startsAt", descending: true)
            .limit(to: pastLimit)
            .getDocuments()

        let recent = try await recentSnapshot.documents.compactMap { CommunityEvent.from($0) }
        let older = try await pastSnapshot.documents.compactMap { CommunityEvent.from($0) }

        let upcoming = recent.filter { !$0.isPast(at: now) }.sorted { $0.startsAt < $1.startsAt }
        let past = (recent.filter { $0.isPast(at: now) } + older).sorted { $0.startsAt > $1.startsAt }
        return (upcoming, Array(past.prefix(pastLimit)))
    }

    /// The next event that hasn't ended, for the landing page.
    func nextEvent(communityId: String) async throws -> CommunityEvent? {
        let now = Date()
        let snapshot = try await events(communityId)
            .whereField("startsAt", isGreaterThanOrEqualTo: Timestamp(date: now.addingTimeInterval(-liveWindow)))
            .order(by: "startsAt")
            .limit(to: 10)
            .getDocuments()
        return snapshot.documents.compactMap { CommunityEvent.from($0) }.first { !$0.isPast(at: now) }
    }

    func fetchEvent(communityId: String, eventId: String) async throws -> CommunityEvent? {
        let snapshot = try await events(communityId).document(eventId).getDocument()
        return snapshot.exists ? CommunityEvent.from(snapshot) : nil
    }

    /// Which of these events the user has RSVP'd to (one small read per event).
    func rsvpedEventIds(communityId: String, eventIds: [String], userId: String) async -> Set<String> {
        await withTaskGroup(of: String?.self) { group in
            for eventId in eventIds {
                group.addTask { [db] in
                    let ref = db.collection("communities").document(communityId)
                        .collection("events").document(eventId)
                        .collection("rsvps").document(userId)
                    let snapshot = try? await ref.getDocument()
                    return (snapshot?.exists ?? false) ? eventId : nil
                }
            }
            var ids = Set<String>()
            for await id in group {
                if let id { ids.insert(id) }
            }
            return ids
        }
    }

    // MARK: - RSVP

    /// Creates or deletes rsvps/{me} and moves rsvpCount by 1, in one batch.
    func setRSVP(_ going: Bool, communityId: String, eventId: String, userId: String) async throws {
        let eventRef = events(communityId).document(eventId)
        let rsvpRef = eventRef.collection("rsvps").document(userId)

        // The rules need the doc's current state to match the change (create when missing,
        // delete when present), so check first and skip a no-op.
        let existing = try await rsvpRef.getDocument()
        if existing.exists == going { return }

        let batch = db.batch()
        if going {
            batch.setData(["userId": userId, "createdAt": FieldValue.serverTimestamp()], forDocument: rsvpRef)
            batch.updateData(["rsvpCount": FieldValue.increment(Int64(1))], forDocument: eventRef)
        } else {
            batch.deleteDocument(rsvpRef)
            batch.updateData(["rsvpCount": FieldValue.increment(Int64(-1))], forDocument: eventRef)
        }
        try await batch.commit()
    }

    // MARK: - Staff

    func createEvent(communityId: String, draft: EventDraft, createdBy: String) async throws -> CommunityEvent {
        let ref = events(communityId).document()
        var data: [String: Any] = [
            "communityId": communityId,
            "title": draft.title,
            "details": draft.details,
            "startsAt": Timestamp(date: draft.startsAt),
            "durationMinutes": draft.durationMinutes,
            "createdBy": createdBy,
            "rsvpCount": 0,
            "createdAt": FieldValue.serverTimestamp()
        ]
        let link = draft.link.trimmingCharacters(in: .whitespacesAndNewlines)
        // Omit the field when there's no link: the rules reject null.
        if !link.isEmpty { data["link"] = link }
        try await ref.setData(data)

        return CommunityEvent(
            id: ref.documentID, communityId: communityId, title: draft.title, details: draft.details,
            startsAt: draft.startsAt, durationMinutes: draft.durationMinutes,
            link: link.isEmpty ? nil : link, createdBy: createdBy, rsvpCount: 0, createdAt: Date()
        )
    }

    /// Edits the event's own fields. Never touches createdBy or rsvpCount (the rules require both unchanged).
    func updateEvent(communityId: String, eventId: String, draft: EventDraft) async throws {
        let link = draft.link.trimmingCharacters(in: .whitespacesAndNewlines)
        var fields: [String: Any] = [
            "title": draft.title,
            "details": draft.details,
            "startsAt": Timestamp(date: draft.startsAt),
            "durationMinutes": draft.durationMinutes
        ]
        // Remove the field (never write null or "") when the link is cleared.
        if link.isEmpty {
            fields["link"] = FieldValue.delete()
        } else {
            fields["link"] = link
        }
        try await events(communityId).document(eventId).updateData(fields)
    }

    /// Deletes the event and the caller's own RSVP. Other members' rsvps/{uid} docs can only
    /// be deleted by their owners, so they're left behind (nothing reads them without the event).
    func deleteEvent(communityId: String, eventId: String, userId: String?) async throws {
        let eventRef = events(communityId).document(eventId)
        if let userId {
            try? await eventRef.collection("rsvps").document(userId).delete()
        }
        try await eventRef.delete()
    }

    // MARK: - Notifications

    /// Free mode: tells the community's members about a new event (`community_event`).
    /// `createNotifications` skips the actor and blocked users and batches by 450.
    func notifyMembers(of event: CommunityEvent, community: Community) async {
        guard !AppConfig.serverFunctionsEnabled else { return }
        let memberIds = await self.memberIds(communityId: community.id, ownerId: community.createdBy)
        guard !memberIds.isEmpty else { return }
        await FirebaseServices.shared.createNotifications(
            to: memberIds,
            type: "community_event",
            title: "New event in \(community.name)",
            body: "\(event.title) · \(EventFormat.shortWhen(event.startsAt))",
            data: ["route": "community", "communityId": community.id, "eventId": event.id]
        )
    }

    /// Member ids, read the same way the callout fan-out reads them (the members collection).
    private func memberIds(communityId: String, ownerId: String) async -> [String] {
        guard let snapshot = try? await db.collection("communities").document(communityId)
            .collection("members").getDocuments() else { return [] }
        var ids = snapshot.documents.map(\.documentID)
        if !ownerId.isEmpty, !ids.contains(ownerId) { ids.append(ownerId) }
        return ids
    }
}
