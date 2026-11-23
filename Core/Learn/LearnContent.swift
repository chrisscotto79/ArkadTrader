// File: Core/Learn/LearnContent.swift
// The Learn catalogue. Each track's lessons and quiz live in LearnContent+<Area>.swift;
// the glossary lives in LearnGlossary.swift.

import Foundation

enum LearnContent {
    /// Tracks in the order they appear in the Learn hub.
    static let tracks: [LearnTrack] = [
        basicsTrack,
        riskTrack,
        chartsTrack,
        optionsTrack,
        cryptoTrack,
        forexTrack,
        psychologyTrack,
        communitiesTrack
    ]

    static var allLessons: [LearnLesson] { tracks.flatMap(\.lessons) }

    static var totalLessonCount: Int { tracks.reduce(0) { $0 + $1.lessons.count } }

    static func track(withId id: String) -> LearnTrack? {
        tracks.first { $0.id == id }
    }

    /// The track that contains a lesson.
    static func track(containing lessonId: String) -> LearnTrack? {
        tracks.first { track in track.lessons.contains { $0.id == lessonId } }
    }

    static func lesson(withId id: String) -> LearnLesson? {
        allLessons.first { $0.id == id }
    }
}
