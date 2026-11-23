// File: Core/Communities/Classroom/ClassroomModels.swift
// Skool-style courses inside a community (docs/backend-contracts.md, section 11, "Classroom").
//   communities/{cid}/courses/{courseId}:
//     { communityId, title, summary, order, lessonCount, createdBy, createdAt, updatedAt }
//   communities/{cid}/courses/{courseId}/lessons/{lessonId}:
//     { title, body (Markdown, ≤ 20,000), videoURL? (https), order, createdAt, updatedAt }
//   users/{uid}/communityLessonProgress/{cid}_{courseId}_{lessonId}:
//     { communityId, courseId, lessonId, completedAt }

import Foundation
import FirebaseFirestore

// MARK: - Limits (match firestore.rules)

enum ClassroomLimits {
    static let titleLength = 120
    static let summaryLength = 2000
    static let lessonBodyLength = 20_000
}

// MARK: - Course

struct CommunityCourse: Identifiable, Hashable {
    let id: String
    var communityId: String
    var title: String
    var summary: String
    var order: Int
    var lessonCount: Int
    var createdBy: String
    var createdAt: Date?
    var updatedAt: Date?

    static func from(_ document: DocumentSnapshot) -> CommunityCourse? {
        guard let data = document.data(),
              let title = data["title"] as? String else { return nil }
        return CommunityCourse(
            id: document.documentID,
            communityId: data["communityId"] as? String ?? "",
            title: title,
            summary: data["summary"] as? String ?? "",
            order: CommunityContentDecode.int(data["order"]) ?? 0,
            lessonCount: max(CommunityContentDecode.int(data["lessonCount"]) ?? 0, 0),
            createdBy: data["createdBy"] as? String ?? "",
            createdAt: CommunityContentDecode.date(data["createdAt"]),
            updatedAt: CommunityContentDecode.date(data["updatedAt"])
        )
    }

    /// Sorts by `order`, then by creation time so equal orders stay stable.
    static func sortedByOrder(_ courses: [CommunityCourse]) -> [CommunityCourse] {
        courses.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture)
        }
    }
}

// MARK: - Lesson

struct CommunityLesson: Identifiable, Hashable {
    let id: String
    var courseId: String
    var title: String
    var body: String
    var videoURL: String?
    var order: Int
    var createdAt: Date?
    var updatedAt: Date?

    /// The video link, when it's a usable https URL.
    var videoLink: URL? { ClassroomValidation.httpsURL(videoURL ?? "") }

    /// Rough reading time for the lesson text, at about 200 words a minute.
    var readingMinutes: Int {
        let words = body.split { $0.isWhitespace || $0.isNewline }.count
        return max(1, Int((Double(words) / 200).rounded(.up)))
    }

    static func from(_ document: DocumentSnapshot, courseId: String) -> CommunityLesson? {
        guard let data = document.data(),
              let title = data["title"] as? String else { return nil }
        let video = (data["videoURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CommunityLesson(
            id: document.documentID,
            courseId: courseId,
            title: title,
            body: data["body"] as? String ?? "",
            videoURL: (video?.isEmpty ?? true) ? nil : video,
            order: CommunityContentDecode.int(data["order"]) ?? 0,
            createdAt: CommunityContentDecode.date(data["createdAt"]),
            updatedAt: CommunityContentDecode.date(data["updatedAt"])
        )
    }

    static func sortedByOrder(_ lessons: [CommunityLesson]) -> [CommunityLesson] {
        lessons.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture)
        }
    }
}

/// What a staff member typed into the lesson editor.
struct LessonDraft {
    var title: String
    var body: String
    /// Empty when the lesson has no video
    var videoURL: String
}

// MARK: - Validation

enum ClassroomValidation {
    /// A trimmed https URL with a host, or nil. The rules accept `https://.+`; this is stricter.
    static func httpsURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("https://"),
              let url = URL(string: trimmed),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    /// True when the text is empty or a usable https link.
    static func isValidOptionalLink(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || httpsURL(trimmed) != nil
    }
}

// MARK: - Decoding helpers

/// Tolerant readers for Firestore values, shared by Classroom, Events and About.
enum CommunityContentDecode {
    static func int(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber: return number.intValue
        case let int as Int: return int
        case let double as Double: return Int(double)
        default: return nil
        }
    }

    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: return number.doubleValue
        case let double as Double: return double
        case let int as Int: return Double(int)
        default: return nil
        }
    }

    static func date(_ value: Any?) -> Date? {
        switch value {
        case let timestamp as Timestamp: return timestamp.dateValue()
        case let date as Date: return date
        default: return nil
        }
    }
}
