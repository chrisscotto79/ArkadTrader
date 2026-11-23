// File: Core/Learn/LearnModels.swift
// Data types for Learn: tracks, lessons, the blocks a lesson is made of, quizzes and glossary terms.
// All content is static Swift data (see LearnContent*.swift). Only progress is stored, in
// users/{uid}/learnProgress/{lessonId}.

import SwiftUI

// MARK: - Track

struct LearnTrack: Identifiable, Hashable, Sendable {
    /// Stable id, e.g. "basics". Lesson ids start with it.
    let id: String
    let title: String
    /// One line shown on track cards.
    let subtitle: String
    let systemImage: String
    let tint: LearnTint
    let lessons: [LearnLesson]
    /// 3–5 multiple-choice questions shown after the lessons.
    let quiz: [LearnQuizQuestion]

    /// Progress doc id for this track's quiz: users/{uid}/learnProgress/{quizId}
    var quizId: String { "\(id)-quiz" }

    var totalMinutes: Int { lessons.reduce(0) { $0 + $1.minutes } }
}

/// Track accent colours. Each one reads well on `Color.surface` in light and dark mode.
enum LearnTint: String, Hashable, Sendable {
    case gold, blue, green, purple, orange, teal, pink, indigo

    var color: Color {
        switch self {
        case .gold: return .goldText
        case .blue: return .blue
        case .green: return .marketGreen
        case .purple: return .purple
        case .orange: return .orange
        case .teal: return .teal
        case .pink: return .pink
        case .indigo: return .indigo
        }
    }
}

// MARK: - Lesson

struct LearnLesson: Identifiable, Hashable, Sendable {
    /// Stable id, e.g. "basics-order-types". Used as the Firestore progress doc id.
    let id: String
    let title: String
    /// One line shown in lesson lists.
    let summary: String
    /// Estimated reading time.
    let minutes: Int
    let blocks: [LearnBlock]
    /// Shown in the "Key takeaways" box at the end of the lesson.
    let takeaways: [String]
}

/// One piece of a lesson, rendered top to bottom.
enum LearnBlock: Hashable, Sendable {
    case heading(String)
    case paragraph(String)
    case bullets([String])
    /// A worked example: a title and short lines, one step per line.
    case example(title: String, lines: [String])
    /// A highlighted tip or warning.
    case tip(String)
    /// An interactive tool embedded in the lesson.
    case tool(LearnTool)
}

enum LearnTool: String, Hashable, Sendable {
    case positionSize
}

// MARK: - Quiz

struct LearnQuizQuestion: Identifiable, Hashable, Sendable {
    let id: String
    let prompt: String
    let options: [String]
    /// Index into `options` of the correct answer.
    let answerIndex: Int
    /// Shown after the user answers.
    let explanation: String
}

// MARK: - Glossary

struct LearnGlossaryTerm: Identifiable, Hashable, Sendable {
    let term: String
    let definition: String

    var id: String { term }

    /// Section letter for the A–Z list ("#" for terms that start with a digit).
    var letter: String {
        guard let first = term.uppercased().first else { return "#" }
        return first.isLetter ? String(first) : "#"
    }
}
