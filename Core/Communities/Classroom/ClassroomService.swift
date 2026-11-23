// File: Core/Communities/Classroom/ClassroomService.swift
// Firestore reads and writes for a community's Classroom. Every write matches the
// `match /courses/{courseId}` rules in firestore.rules: staff (owner, admin, moderator)
// write courses and lessons; anyone who can read the community reads them. Progress is
// private, in users/{uid}/communityLessonProgress.
//
// `lessonCount` on the course moves in the same batch that adds or removes a lesson.

import Foundation
import FirebaseFirestore

final class ClassroomService {
    static let shared = ClassroomService()

    private var db: Firestore { FirebaseServices.shared.db }

    /// Batches stay under Firestore's 500-write limit.
    private let batchLimit = 450

    private init() {}

    // MARK: - Paths

    private func courses(_ communityId: String) -> CollectionReference {
        db.collection("communities").document(communityId).collection("courses")
    }

    private func lessons(_ communityId: String, _ courseId: String) -> CollectionReference {
        courses(communityId).document(courseId).collection("lessons")
    }

    private func progress(_ userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("communityLessonProgress")
    }

    static func progressDocumentId(communityId: String, courseId: String, lessonId: String) -> String {
        "\(communityId)_\(courseId)_\(lessonId)"
    }

    // MARK: - Reading

    /// Every course in the community, in `order`.
    func fetchCourses(communityId: String) async throws -> [CommunityCourse] {
        let snapshot = try await courses(communityId).order(by: "order").getDocuments()
        return CommunityCourse.sortedByOrder(snapshot.documents.compactMap { CommunityCourse.from($0) })
    }

    /// How many courses the community has (for the landing page).
    func courseCount(communityId: String) async throws -> Int {
        let snapshot = try await courses(communityId).getDocuments()
        return snapshot.documents.count
    }

    /// A course's lessons, in `order`.
    func fetchLessons(communityId: String, courseId: String) async throws -> [CommunityLesson] {
        let snapshot = try await lessons(communityId, courseId).order(by: "order").getDocuments()
        return CommunityLesson.sortedByOrder(snapshot.documents.compactMap { CommunityLesson.from($0, courseId: courseId) })
    }

    /// The signed-in user's completed lessons in this community: course id → lesson ids.
    /// Single-field equality query, so no composite index is needed.
    func fetchCompletedLessons(userId: String, communityId: String) async throws -> [String: Set<String>] {
        let snapshot = try await progress(userId)
            .whereField("communityId", isEqualTo: communityId)
            .getDocuments()
        var completed: [String: Set<String>] = [:]
        for document in snapshot.documents {
            let data = document.data()
            guard let courseId = data["courseId"] as? String,
                  let lessonId = data["lessonId"] as? String else { continue }
            completed[courseId, default: []].insert(lessonId)
        }
        return completed
    }

    // MARK: - Progress

    /// Marks a lesson done (writes the progress doc) or not done (deletes it).
    func setLessonCompleted(
        _ isCompleted: Bool,
        userId: String,
        communityId: String,
        courseId: String,
        lessonId: String
    ) async throws {
        let ref = progress(userId).document(
            Self.progressDocumentId(communityId: communityId, courseId: courseId, lessonId: lessonId)
        )
        if isCompleted {
            try await ref.setData([
                "communityId": communityId,
                "courseId": courseId,
                "lessonId": lessonId,
                "completedAt": FieldValue.serverTimestamp()
            ])
        } else {
            try await ref.delete()
        }
    }

    // MARK: - Courses (staff)

    func createCourse(
        communityId: String,
        title: String,
        summary: String,
        order: Int,
        createdBy: String
    ) async throws -> CommunityCourse {
        let ref = courses(communityId).document()
        try await ref.setData([
            "communityId": communityId,
            "title": title,
            "summary": summary,
            "order": order,
            "lessonCount": 0,
            "createdBy": createdBy,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        return CommunityCourse(
            id: ref.documentID, communityId: communityId, title: title, summary: summary,
            order: order, lessonCount: 0, createdBy: createdBy, createdAt: Date(), updatedAt: Date()
        )
    }

    func updateCourse(communityId: String, courseId: String, title: String, summary: String) async throws {
        try await courses(communityId).document(courseId).updateData([
            "title": title,
            "summary": summary,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Deletes a course and its lessons. Members' private progress docs can't be reached
    /// and are left behind; they no longer match any lesson.
    func deleteCourse(communityId: String, courseId: String) async throws {
        let lessonDocs = try await lessons(communityId, courseId).getDocuments().documents
        for chunk in lessonDocs.chunked(into: batchLimit) {
            let batch = db.batch()
            for document in chunk {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }
        try await courses(communityId).document(courseId).delete()
    }

    /// Writes `order` = position for every course whose position changed.
    func reorderCourses(communityId: String, from old: [CommunityCourse], to orderedIds: [String]) async throws {
        let current = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0.order) })
        let changes = orderedIds.enumerated().filter { current[$0.element] != $0.offset }
        for chunk in changes.chunked(into: batchLimit) {
            let batch = db.batch()
            for (index, id) in chunk {
                batch.updateData(["order": index, "updatedAt": FieldValue.serverTimestamp()],
                                 forDocument: courses(communityId).document(id))
            }
            try await batch.commit()
        }
    }

    /// Staff self-repair: sets `lessonCount` to the real number of lessons.
    func repairLessonCount(communityId: String, courseId: String, count: Int) async throws {
        try await courses(communityId).document(courseId).updateData(["lessonCount": count])
    }

    // MARK: - Lessons (staff)

    /// Adds a lesson and bumps the course's `lessonCount` in the same batch.
    func createLesson(
        communityId: String,
        courseId: String,
        draft: LessonDraft,
        order: Int
    ) async throws -> CommunityLesson {
        let ref = lessons(communityId, courseId).document()
        var data: [String: Any] = [
            "title": draft.title,
            "body": draft.body,
            "order": order,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        let video = draft.videoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        // Omit the field when there's no video: the rules reject null.
        if !video.isEmpty { data["videoURL"] = video }

        let batch = db.batch()
        batch.setData(data, forDocument: ref)
        batch.updateData([
            "lessonCount": FieldValue.increment(Int64(1)),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: courses(communityId).document(courseId))
        try await batch.commit()

        return CommunityLesson(
            id: ref.documentID, courseId: courseId, title: draft.title, body: draft.body,
            videoURL: video.isEmpty ? nil : video, order: order, createdAt: Date(), updatedAt: Date()
        )
    }

    func updateLesson(communityId: String, courseId: String, lessonId: String, draft: LessonDraft) async throws {
        let video = draft.videoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        var fields: [String: Any] = [
            "title": draft.title,
            "body": draft.body,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        // Remove the field (never write null or "") when the video is cleared.
        if video.isEmpty {
            fields["videoURL"] = FieldValue.delete()
        } else {
            fields["videoURL"] = video
        }
        let batch = db.batch()
        batch.updateData(fields, forDocument: lessons(communityId, courseId).document(lessonId))
        batch.updateData(["updatedAt": FieldValue.serverTimestamp()],
                         forDocument: courses(communityId).document(courseId))
        try await batch.commit()
    }

    /// Deletes a lesson and lowers the course's `lessonCount` in the same batch.
    func deleteLesson(communityId: String, courseId: String, lessonId: String) async throws {
        let batch = db.batch()
        batch.deleteDocument(lessons(communityId, courseId).document(lessonId))
        batch.updateData([
            "lessonCount": FieldValue.increment(Int64(-1)),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: courses(communityId).document(courseId))
        try await batch.commit()
    }

    /// Writes `order` = position for every lesson whose position changed.
    func reorderLessons(
        communityId: String,
        courseId: String,
        from old: [CommunityLesson],
        to orderedIds: [String]
    ) async throws {
        let current = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0.order) })
        let changes = orderedIds.enumerated().filter { current[$0.element] != $0.offset }
        for chunk in changes.chunked(into: batchLimit) {
            let batch = db.batch()
            for (index, id) in chunk {
                batch.updateData(["order": index, "updatedAt": FieldValue.serverTimestamp()],
                                 forDocument: lessons(communityId, courseId).document(id))
            }
            try await batch.commit()
        }
    }
}
