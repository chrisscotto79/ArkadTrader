// File: Core/Communities/Events/CommunityEvent.swift
// A scheduled live session in a community (docs/backend-contracts.md, section 11, "Events").
//   communities/{cid}/events/{eventId}:
//     { communityId, title, details, startsAt (Timestamp), durationMinutes, link? (https),
//       createdBy, rsvpCount, createdAt }
//   communities/{cid}/events/{eventId}/rsvps/{uid}: { userId, createdAt }

import Foundation
import FirebaseFirestore

enum EventLimits {
    static let titleLength = 120
    static let detailsLength = 4000
    /// Durations offered in the editor, in minutes
    static let durations = [15, 30, 45, 60, 90, 120, 180, 240]
    static let defaultDuration = 60
    /// What the rules accept for `durationMinutes`: one minute to a day.
    static let durationRange = 1...1440
}

struct CommunityEvent: Identifiable, Hashable {
    let id: String
    var communityId: String
    var title: String
    var details: String
    var startsAt: Date
    var durationMinutes: Int
    var link: String?
    var createdBy: String
    var rsvpCount: Int
    var createdAt: Date?

    var endsAt: Date { startsAt.addingTimeInterval(TimeInterval(max(durationMinutes, 0) * 60)) }

    /// Over: the end time has passed.
    func isPast(at now: Date = Date()) -> Bool { endsAt <= now }

    /// Started and not over yet.
    func isLive(at now: Date = Date()) -> Bool { startsAt <= now && now < endsAt }

    var linkURL: URL? { ClassroomValidation.httpsURL(link ?? "") }

    static func from(_ document: DocumentSnapshot) -> CommunityEvent? {
        guard let data = document.data(),
              let title = data["title"] as? String,
              let startsAt = CommunityContentDecode.date(data["startsAt"]) else { return nil }
        let link = (data["link"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CommunityEvent(
            id: document.documentID,
            communityId: data["communityId"] as? String ?? "",
            title: title,
            details: data["details"] as? String ?? "",
            startsAt: startsAt,
            durationMinutes: CommunityContentDecode.int(data["durationMinutes"]) ?? EventLimits.defaultDuration,
            link: (link?.isEmpty ?? true) ? nil : link,
            createdBy: data["createdBy"] as? String ?? "",
            rsvpCount: max(CommunityContentDecode.int(data["rsvpCount"]) ?? 0, 0),
            createdAt: CommunityContentDecode.date(data["createdAt"])
        )
    }
}

/// What a staff member typed into the event editor.
struct EventDraft {
    var title: String
    var details: String
    var startsAt: Date
    var durationMinutes: Int
    /// Empty when there's no link
    var link: String

    /// Throws when the draft can't be saved (the editor blocks these first).
    func validate() throws {
        guard EventLimits.durationRange.contains(durationMinutes) else {
            throw EventDraftError("Pick a duration between 1 minute and 24 hours.")
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= EventLimits.titleLength else {
            throw EventDraftError("Give the event a title of up to \(EventLimits.titleLength) characters.")
        }
        guard details.count <= EventLimits.detailsLength else {
            throw EventDraftError("Keep the details under \(EventLimits.detailsLength) characters.")
        }
    }
}

struct EventDraftError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

// MARK: - Formatting

enum EventFormat {
    /// "1 hr 30 min", "45 min", "2 hr"
    static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) min"
        case (_, 0): return "\(hours) hr"
        default: return "\(hours) hr \(rest) min"
        }
    }

    /// "7:00 – 8:30 PM EST" in the viewer's time zone
    static func timeRange(_ event: CommunityEvent) -> String {
        let start = event.startsAt.formatted(date: .omitted, time: .shortened)
        let end = event.endsAt.formatted(date: .omitted, time: .shortened)
        let zone = TimeZone.current.abbreviation(for: event.startsAt) ?? ""
        return "\(start) – \(end) \(zone)".trimmingCharacters(in: .whitespaces)
    }

    /// "Tue, Nov 25" (or "Today" / "Tomorrow")
    static func day(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// "Tuesday, November 25, 2026"
    static func fullDay(_ date: Date) -> String {
        date.formatted(date: .complete, time: .omitted)
    }

    /// "Tue, Nov 25 · 7:00 PM EST", for notifications and summaries
    static func shortWhen(_ date: Date) -> String {
        let zone = TimeZone.current.abbreviation(for: date) ?? ""
        let text = date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
        return "\(text) \(zone)".trimmingCharacters(in: .whitespaces)
    }

    static func rsvpCount(_ count: Int) -> String {
        count == 1 ? "1 going" : "\(count.formatted()) going"
    }
}
