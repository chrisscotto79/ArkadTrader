// File: Core/Communities/Events/EventsService.swift
// Firestore reads and writes for community events. Every write matches the
// `match /events/{eventId}` rules in firestore.rules:
// - staff create (rsvpCount 0, createdBy = me, https link or none), edit (never createdBy or
//   rsvpCount) and delete;
// - an RSVP creates or deletes rsvps/{me} and moves rsvpCount by exactly 1 in the same batch,
//   and writes or deletes the owner-only mirror users/{me}/eventRsvps/{eventId} =
//   { communityId, eventId, createdAt } in that batch, so "which events am I going to" is one query.
// Creating an event notifies the members (`community_event`, capped like callouts); moving or
// cancelling one notifies the people who RSVP'd.

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

    private func rsvpMirrors(_ userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("eventRsvps")
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

    /// Ids of the events in this community the user has RSVP'd to, from their own
    /// `eventRsvps` mirror (one query). Throws when it can't be read, so callers never mistake
    /// a failed read for "going to nothing".
    func rsvpedEventIds(communityId: String, userId: String) async throws -> Set<String> {
        let snapshot = try await rsvpMirrors(userId)
            .whereField("communityId", isEqualTo: communityId)
            .limit(to: 200)
            .getDocuments()
        return Set(snapshot.documents.map(\.documentID))
    }

    /// Every event the user has RSVP'd to: event id -> community id.
    func allRSVPs(userId: String) async throws -> [String: String] {
        let snapshot = try await rsvpMirrors(userId).limit(to: 200).getDocuments()
        var result: [String: String] = [:]
        for document in snapshot.documents {
            if let communityId = document.data()["communityId"] as? String, !communityId.isEmpty {
                result[document.documentID] = communityId
            }
        }
        return result
    }

    // MARK: - RSVP

    /// Creates or deletes rsvps/{me}, moves rsvpCount by 1 and keeps the user's mirror in step,
    /// in one batch. Returns false when nothing needed to change (already in that state).
    @discardableResult
    func setRSVP(_ going: Bool, communityId: String, eventId: String, userId: String) async throws -> Bool {
        let eventRef = events(communityId).document(eventId)
        let rsvpRef = eventRef.collection("rsvps").document(userId)
        let mirrorRef = rsvpMirrors(userId).document(eventId)

        // The rules need the doc's current state to match the change (create when missing,
        // delete when present), so check first and skip a no-op.
        let existing = try await rsvpRef.getDocument()
        if existing.exists == going {
            // Repair the mirror if it drifted (e.g. an RSVP made before mirrors existed)
            if going {
                try? await mirrorRef.setData(Self.mirrorData(communityId: communityId, eventId: eventId))
            } else {
                try? await mirrorRef.delete()
            }
            return false
        }

        let batch = db.batch()
        if going {
            batch.setData(["userId": userId, "createdAt": FieldValue.serverTimestamp()], forDocument: rsvpRef)
            batch.updateData(["rsvpCount": FieldValue.increment(Int64(1))], forDocument: eventRef)
            batch.setData(Self.mirrorData(communityId: communityId, eventId: eventId), forDocument: mirrorRef)
        } else {
            batch.deleteDocument(rsvpRef)
            batch.updateData(["rsvpCount": FieldValue.increment(Int64(-1))], forDocument: eventRef)
            batch.deleteDocument(mirrorRef)
        }
        try await batch.commit()
        return true
    }

    private static func mirrorData(communityId: String, eventId: String) -> [String: Any] {
        ["communityId": communityId, "eventId": eventId, "createdAt": FieldValue.serverTimestamp()]
    }

    /// Drops the user's mirror for an event that no longer exists.
    func removeRSVPMirror(eventId: String, userId: String) async {
        try? await rsvpMirrors(userId).document(eventId).delete()
    }

    // MARK: - Staff

    func createEvent(communityId: String, draft: EventDraft, createdBy: String) async throws -> CommunityEvent {
        try draft.validate()
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
        try draft.validate()
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

    /// Deletes the event and the caller's own RSVP. Other members' rsvps/{uid} and eventRsvps
    /// mirrors can only be deleted by their owners, so they're left behind; their apps drop them
    /// (and the reminder) when the event can't be found.
    func deleteEvent(communityId: String, eventId: String, userId: String?) async throws {
        let eventRef = events(communityId).document(eventId)
        if let userId {
            let batch = db.batch()
            batch.deleteDocument(eventRef.collection("rsvps").document(userId))
            batch.deleteDocument(rsvpMirrors(userId).document(eventId))
            try? await batch.commit()
        }
        try await eventRef.delete()
    }

    // MARK: - Notifications

    /// Most people one event notification goes to (free-plan write budget).
    private let maxFanOut = TrackRecordWriter.maxFanOut

    /// Free mode: tells the community's members about a new event (`community_event`).
    /// `createNotifications` skips the actor and blocked users.
    func notifyMembers(of event: CommunityEvent, community: Community) async {
        guard !AppConfig.serverFunctionsEnabled else { return }
        let memberIds = await self.memberIds(communityId: community.id)
        guard !memberIds.isEmpty else { return }
        await FirebaseServices.shared.createNotifications(
            to: memberIds,
            type: "community_event",
            title: "New event in \(community.name)",
            body: "\(event.title) · \(EventFormat.shortWhen(event.startsAt))",
            data: ["route": "community", "communityId": community.id, "eventId": event.id],
            communityId: community.id
        )
    }

    /// Free mode: tells the people going that an event moved (`moved: true`) or was cancelled.
    /// Read the RSVP ids before deleting the event: they can't be listed afterwards.
    func notifyRSVPs(_ userIds: [String], about event: CommunityEvent, community: Community, cancelled: Bool) async {
        guard !AppConfig.serverFunctionsEnabled, !userIds.isEmpty else { return }
        let title = cancelled ? "Event cancelled in \(community.name)" : "Event time changed in \(community.name)"
        let body = cancelled ? event.title : "\(event.title) · now \(EventFormat.shortWhen(event.startsAt))"
        var data = ["route": "community", "communityId": community.id]
        if !cancelled { data["eventId"] = event.id }
        await FirebaseServices.shared.createNotifications(
            to: userIds, type: "community_event", title: title, body: body, data: data,
            communityId: community.id
        )
    }

    /// Who RSVP'd to an event (at most `maxFanOut`). Empty when it can't be read.
    func rsvpUserIds(communityId: String, eventId: String) async -> [String] {
        do {
            let snapshot = try await events(communityId).document(eventId).collection("rsvps")
                .limit(to: maxFanOut).getDocuments()
            return snapshot.documents.map(\.documentID)
        } catch {
            TrackRecordWriter.log("couldn't read RSVPs for \(eventId): \(error.localizedDescription)")
            return []
        }
    }

    /// Up to `maxFanOut` member ids, read the same way the callout fan-out reads them.
    private func memberIds(communityId: String) async -> [String] {
        await TrackRecordWriter.shared.memberIds(communityId: communityId)
    }
}
