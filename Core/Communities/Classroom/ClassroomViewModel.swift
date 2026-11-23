// File: Core/Communities/Classroom/ClassroomViewModel.swift
// State for a community's Classroom tab: courses, lessons per course (loaded when a course
// opens) and the signed-in user's progress. Staff actions go through ClassroomService.

import Foundation
import FirebaseAuth

@MainActor
final class ClassroomViewModel: ObservableObject {
    @Published private(set) var courses: [CommunityCourse] = []
    @Published private(set) var lessonsByCourse: [String: [CommunityLesson]] = [:]
    /// course id → completed lesson ids, for the signed-in user
    @Published private(set) var completed: [String: Set<String>] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var loadingLessonsFor: Set<String> = []
    /// course id → why its lessons couldn't be loaded
    @Published private(set) var lessonLoadErrors: [String: String] = [:]
    /// Why the course list couldn't be loaded
    @Published var errorMessage: String?

    private(set) var communityId = ""
    private let service = ClassroomService.shared

    private var userId: String? { Auth.auth().currentUser?.uid }

    // MARK: - Loading

    /// Points the model at a community, clearing anything from a previous one.
    func configure(communityId: String) {
        guard communityId != self.communityId else { return }
        self.communityId = communityId
        courses = []
        lessonsByCourse = [:]
        lessonLoadErrors = [:]
        completed = [:]
        hasLoaded = false
        errorMessage = nil
    }

    /// Loads once; later calls do nothing until `reload()`.
    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else { return }
        await reload()
    }

    func reload() async {
        guard !communityId.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            courses = try await service.fetchCourses(communityId: communityId)
            hasLoaded = true
            errorMessage = nil
        } catch {
            // Shown in place of the list before the first load, as a banner over loaded courses
            errorMessage = Self.friendly(error, doing: "load the courses")
            return
        }
        await loadProgress()
        // Lessons for courses that are open or that the user has started, so their progress
        // counts only lessons that still exist.
        let started = completed.filter { !$0.value.isEmpty }.map(\.key)
        let toLoad = Set(lessonsByCourse.keys).union(started).filter { id in courses.contains { $0.id == id } }
        await withTaskGroup(of: Void.self) { group in
            for courseId in toLoad {
                group.addTask { await self.loadLessons(courseId: courseId) }
            }
        }
    }

    private func loadProgress() async {
        guard let userId else { return }
        if let progress = try? await service.fetchCompletedLessons(userId: userId, communityId: communityId) {
            completed = progress
        }
    }

    func loadLessons(courseId: String) async {
        guard !communityId.isEmpty else { return }
        loadingLessonsFor.insert(courseId)
        defer { loadingLessonsFor.remove(courseId) }
        do {
            let lessons = try await service.fetchLessons(communityId: communityId, courseId: courseId)
            lessonsByCourse[courseId] = lessons
            lessonLoadErrors[courseId] = nil
        } catch {
            lessonLoadErrors[courseId] = Self.friendly(error, doing: "load the lessons")
        }
    }

    /// Staff only: if `lessonCount` drifted from the real number of lessons, fix it.
    func repairLessonCountIfNeeded(courseId: String) async {
        guard let lessons = lessonsByCourse[courseId],
              let index = courses.firstIndex(where: { $0.id == courseId }),
              courses[index].lessonCount != lessons.count else { return }
        do {
            try await service.repairLessonCount(communityId: communityId, courseId: courseId, count: lessons.count)
            courses[index].lessonCount = lessons.count
        } catch {
            // Not worth bothering the user about; the next lesson change fixes it too.
        }
    }

    // MARK: - Lookups

    func course(id: String) -> CommunityCourse? {
        courses.first { $0.id == id }
    }

    func lessons(for courseId: String) -> [CommunityLesson] {
        lessonsByCourse[courseId] ?? []
    }

    func isCompleted(lessonId: String, courseId: String) -> Bool {
        completed[courseId]?.contains(lessonId) ?? false
    }

    /// Whether this course's lessons are loaded, so its progress can be trusted.
    func hasLessons(for courseId: String) -> Bool {
        lessonsByCourse[courseId] != nil
    }

    /// Completed lessons in a course that still exist. 0 until the lessons are loaded, since
    /// progress records can outlive deleted lessons.
    func completedCount(for course: CommunityCourse) -> Int {
        guard let lessons = lessonsByCourse[course.id] else { return 0 }
        let done = completed[course.id] ?? []
        return lessons.filter { done.contains($0.id) }.count
    }

    /// Completed lessons divided by the lesson count, 0–1. 0 until the lessons are loaded.
    func progress(for course: CommunityCourse) -> Double {
        guard let total = lessonsByCourse[course.id]?.count, total > 0 else { return 0 }
        return min(Double(completedCount(for: course)) / Double(total), 1)
    }

    /// The first lesson not done yet, in order.
    func nextLesson(in courseId: String) -> CommunityLesson? {
        lessons(for: courseId).first { !isCompleted(lessonId: $0.id, courseId: courseId) }
    }

    // MARK: - Progress

    /// Throws (after rolling back) when the progress doc can't be written.
    func setCompleted(_ isCompleted: Bool, lesson: CommunityLesson) async throws {
        guard let userId else { throw ClassroomError.signedOut }
        let courseId = lesson.courseId
        let before = completed[courseId] ?? []
        // Optimistic: update first, roll back if the write fails
        var after = before
        if isCompleted { after.insert(lesson.id) } else { after.remove(lesson.id) }
        completed[courseId] = after
        do {
            try await service.setLessonCompleted(
                isCompleted, userId: userId, communityId: communityId, courseId: courseId, lessonId: lesson.id
            )
        } catch {
            completed[courseId] = before
            throw error
        }
    }

    // MARK: - Courses (staff)

    func createCourse(title: String, summary: String) async throws {
        guard let userId else { throw ClassroomError.signedOut }
        let order = (courses.map(\.order).max() ?? -1) + 1
        let course = try await service.createCourse(
            communityId: communityId, title: title, summary: summary, order: order, createdBy: userId
        )
        courses = CommunityCourse.sortedByOrder(courses + [course])
    }

    func updateCourse(_ course: CommunityCourse, title: String, summary: String) async throws {
        try await service.updateCourse(communityId: communityId, courseId: course.id, title: title, summary: summary)
        if let index = courses.firstIndex(where: { $0.id == course.id }) {
            courses[index].title = title
            courses[index].summary = summary
            courses[index].updatedAt = Date()
        }
    }

    func deleteCourse(_ course: CommunityCourse) async throws {
        try await service.deleteCourse(communityId: communityId, courseId: course.id)
        courses.removeAll { $0.id == course.id }
        lessonsByCourse[course.id] = nil
    }

    func reorderCourses(_ orderedIds: [String]) async throws {
        try await service.reorderCourses(communityId: communityId, from: courses, to: orderedIds)
        let byId = Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0) })
        courses = orderedIds.enumerated().compactMap { index, id in
            guard var course = byId[id] else { return nil }
            course.order = index
            return course
        }
    }

    // MARK: - Lessons (staff)

    func createLesson(in course: CommunityCourse, draft: LessonDraft) async throws {
        let existing = lessons(for: course.id)
        let order = (existing.map(\.order).max() ?? -1) + 1
        let lesson = try await service.createLesson(
            communityId: communityId, courseId: course.id, draft: draft, order: order
        )
        lessonsByCourse[course.id] = CommunityLesson.sortedByOrder(existing + [lesson])
        if let index = courses.firstIndex(where: { $0.id == course.id }) {
            courses[index].lessonCount += 1
        }
    }

    func updateLesson(_ lesson: CommunityLesson, draft: LessonDraft) async throws {
        try await service.updateLesson(
            communityId: communityId, courseId: lesson.courseId, lessonId: lesson.id, draft: draft
        )
        guard var list = lessonsByCourse[lesson.courseId],
              let index = list.firstIndex(where: { $0.id == lesson.id }) else { return }
        let video = draft.videoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        list[index].title = draft.title
        list[index].body = draft.body
        list[index].videoURL = video.isEmpty ? nil : video
        list[index].updatedAt = Date()
        lessonsByCourse[lesson.courseId] = list
    }

    func deleteLesson(_ lesson: CommunityLesson) async throws {
        try await service.deleteLesson(communityId: communityId, courseId: lesson.courseId, lessonId: lesson.id)
        lessonsByCourse[lesson.courseId]?.removeAll { $0.id == lesson.id }
        if let index = courses.firstIndex(where: { $0.id == lesson.courseId }) {
            courses[index].lessonCount = max(courses[index].lessonCount - 1, 0)
        }
    }

    func reorderLessons(in courseId: String, orderedIds: [String]) async throws {
        let current = lessons(for: courseId)
        try await service.reorderLessons(communityId: communityId, courseId: courseId, from: current, to: orderedIds)
        let byId = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        lessonsByCourse[courseId] = orderedIds.enumerated().compactMap { index, id in
            guard var lesson = byId[id] else { return nil }
            lesson.order = index
            return lesson
        }
    }

    // MARK: - Errors

    nonisolated static func friendly(_ error: Error, doing action: String) -> String {
        if let draftError = error as? EventDraftError { return draftError.message }
        if let classroomError = error as? ClassroomError {
            return classroomError.errorDescription ?? "Couldn't \(action)."
        }
        let nsError = error as NSError
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 7:
                if action.hasPrefix("load") {
                    return "You don't have access to this classroom."
                }
                return "You don't have permission to \(action)."
            case 9: return "Still setting up. Try again in a minute."
            case 14: return "Couldn't \(action). Check your connection and try again."
            default: break
            }
        }
        return "Couldn't \(action). Please try again."
    }
}

enum ClassroomError: LocalizedError {
    case signedOut

    var errorDescription: String? {
        switch self {
        case .signedOut: return "Sign in again to make changes."
        }
    }
}
