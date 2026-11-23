// File: Core/Learn/LearnProgressStore.swift
// Learn progress: completed lessons and quiz scores.
//
// Stored in users/{uid}/learnProgress/{lessonId} as { completedAt, quizScore?, quizTotal? }.
// A track's quiz uses the id "<trackId>-quiz". Progress is cached in UserDefaults per user so
// the UI is instant, then merged with Firestore. Writes that fail are kept and retried on the
// next sync.

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct LearnProgressRecord: Codable, Hashable, Sendable {
    var completedAt: Date
    var quizScore: Int?
    var quizTotal: Int?
}

@MainActor
final class LearnProgressStore: ObservableObject {
    static let shared = LearnProgressStore()

    /// Progress keyed by lesson id (or "<trackId>-quiz").
    @Published private(set) var records: [String: LearnProgressRecord] = [:]
    /// The lesson the user opened most recently. Kept on this device only.
    @Published private(set) var lastOpenedLessonId: String?

    private var loadedUserId: String?
    private var pendingIds: Set<String> = []
    private var isSyncing = false
    private var lastSyncAt: Date?

    private init() {
        loadedUserId = Auth.auth().currentUser?.uid
        restoreCache()
    }

    // MARK: - Queries

    func isCompleted(_ lessonId: String) -> Bool {
        records[lessonId] != nil
    }

    func quizResult(for track: LearnTrack) -> (score: Int, total: Int)? {
        guard let record = records[track.quizId],
              let score = record.quizScore,
              let total = record.quizTotal, total > 0 else { return nil }
        return (score, total)
    }

    func completedLessonCount(in track: LearnTrack) -> Int {
        track.lessons.filter { isCompleted($0.id) }.count
    }

    /// Lessons plus the quiz, 0...1.
    func progress(for track: LearnTrack) -> Double {
        let steps = track.lessons.count + 1
        let done = completedLessonCount(in: track) + (quizResult(for: track) == nil ? 0 : 1)
        return Double(done) / Double(steps)
    }

    func isTrackComplete(_ track: LearnTrack) -> Bool {
        progress(for: track) >= 1
    }

    var totalCompletedLessons: Int {
        LearnContent.allLessons.filter { isCompleted($0.id) }.count
    }

    var hasStarted: Bool {
        totalCompletedLessons > 0 || lastOpenedLessonId != nil
    }

    /// The lesson to resume: the last one opened if it isn't finished, otherwise the next
    /// unfinished lesson in the track the user worked in most recently, otherwise the first
    /// unfinished lesson anywhere. Nil when every lesson is done.
    var continueLesson: LearnLesson? {
        if let id = lastOpenedLessonId, !isCompleted(id), let lesson = LearnContent.lesson(withId: id) {
            return lesson
        }

        let latestLessonId = LearnContent.allLessons
            .compactMap { lesson in records[lesson.id].map { (lesson.id, $0.completedAt) } }
            .max { $0.1 < $1.1 }?
            .0
        let anchorId = lastOpenedLessonId ?? latestLessonId
        if let anchorId, let track = LearnContent.track(containing: anchorId),
           let next = track.lessons.first(where: { !isCompleted($0.id) }) {
            return next
        }

        return LearnContent.allLessons.first { !isCompleted($0.id) }
    }

    // MARK: - Loading

    /// Loads the cache for the signed-in user, then merges Firestore. Safe to call often:
    /// Firestore is read at most once a minute unless `force` is set (pull to refresh).
    func load(force: Bool = false) async {
        switchUserIfNeeded()
        if !force, let lastSyncAt, Date().timeIntervalSince(lastSyncAt) < 60, pendingIds.isEmpty {
            return
        }
        await sync()
    }

    /// Swaps in the right cache if someone else has signed in since the last load.
    private func switchUserIfNeeded() {
        let userId = Auth.auth().currentUser?.uid
        guard userId != loadedUserId else { return }
        loadedUserId = userId
        lastSyncAt = nil
        restoreCache()
    }

    private func sync() async {
        guard let userId = loadedUserId, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        // Retry writes that didn't make it last time.
        for id in pendingIds {
            if let record = records[id] {
                await upload(id: id, record: record, userId: userId)
            }
        }

        do {
            let snapshot = try await progressCollection(userId).getDocuments()
            guard userId == loadedUserId else { return }

            var merged = records
            for document in snapshot.documents where !pendingIds.contains(document.documentID) {
                let data = document.data()
                guard let completedAt = (data["completedAt"] as? Timestamp)?.dateValue() else { continue }
                let remote = LearnProgressRecord(
                    completedAt: completedAt,
                    quizScore: data["quizScore"] as? Int,
                    quizTotal: data["quizTotal"] as? Int
                )
                merged[document.documentID] = best(of: merged[document.documentID], remote)
            }
            records = merged
            lastSyncAt = Date()
            saveCache()
        } catch {
            // Offline or not allowed: the cached progress is still shown.
        }
    }

    // MARK: - Recording

    func markOpened(_ lesson: LearnLesson) {
        lastOpenedLessonId = lesson.id
        saveCache()
    }

    func markCompleted(_ lesson: LearnLesson) {
        switchUserIfNeeded()
        guard !isCompleted(lesson.id) else { return }
        save(id: lesson.id, record: LearnProgressRecord(completedAt: Date()))
    }

    /// Keeps the best score if the quiz is retaken.
    func recordQuiz(for track: LearnTrack, score: Int, total: Int) {
        switchUserIfNeeded()
        let attempt = LearnProgressRecord(completedAt: Date(), quizScore: score, quizTotal: total)
        save(id: track.quizId, record: best(of: records[track.quizId], attempt))
    }

    private func save(id: String, record: LearnProgressRecord) {
        switchUserIfNeeded()
        records[id] = record
        guard let userId = loadedUserId else {
            saveCache()
            return
        }
        pendingIds.insert(id)
        saveCache()
        Task { await upload(id: id, record: record, userId: userId) }
    }

    private func upload(id: String, record: LearnProgressRecord, userId: String) async {
        var data: [String: Any] = ["completedAt": Timestamp(date: record.completedAt)]
        if let score = record.quizScore, let total = record.quizTotal {
            data["quizScore"] = score
            data["quizTotal"] = total
        }
        do {
            try await progressCollection(userId).document(id).setData(data, merge: true)
            if userId == loadedUserId {
                pendingIds.remove(id)
                saveCache()
            }
        } catch {
            // Stays pending; retried on the next sync.
        }
    }

    private func best(of existing: LearnProgressRecord?, _ candidate: LearnProgressRecord) -> LearnProgressRecord {
        guard let existing else { return candidate }
        let existingScore = existing.quizScore ?? -1
        let candidateScore = candidate.quizScore ?? -1
        if candidateScore > existingScore { return candidate }
        if candidateScore < existingScore { return existing }
        return existing.completedAt <= candidate.completedAt ? existing : candidate
    }

    private func progressCollection(_ userId: String) -> CollectionReference {
        FirebaseServices.shared.db.collection("users").document(userId).collection("learnProgress")
    }

    // MARK: - Local cache

    private struct Cache: Codable {
        var records: [String: LearnProgressRecord]
        var pendingIds: [String]
        var lastOpenedLessonId: String?
    }

    private var cacheKey: String { "arkad_learn_progress_\(loadedUserId ?? "signed_out")" }

    private func restoreCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            records = cache.records
            pendingIds = Set(cache.pendingIds)
            lastOpenedLessonId = cache.lastOpenedLessonId
        } else {
            records = [:]
            pendingIds = []
            lastOpenedLessonId = nil
        }
    }

    private func saveCache() {
        let cache = Cache(records: records, pendingIds: Array(pendingIds), lastOpenedLessonId: lastOpenedLessonId)
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
