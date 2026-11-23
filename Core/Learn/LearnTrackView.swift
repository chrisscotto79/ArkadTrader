// File: Core/Learn/LearnTrackView.swift
// One track: its progress, the lessons in order and the quiz at the end.

import SwiftUI

struct LearnTrackView: View {
    let track: LearnTrack
    @ObservedObject private var store = LearnProgressStore.shared
    /// The header's next step, captured when the track is on screen so its link doesn't
    /// change (and pop the lesson) while the user is reading.
    @State private var headerStep: HeaderStep?

    private enum HeaderStep {
        case lesson(LearnLesson, isFirst: Bool)
        case quiz
    }

    init(track: LearnTrack) {
        self.track = track
        _headerStep = State(initialValue: Self.headerStep(for: track, store: .shared))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                header
                lessonsSection
                quizSection
                LearnDisclaimer()
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .screenBackground()
        .navigationTitle(track.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear { headerStep = Self.headerStep(for: track, store: store) }
    }

    private static func headerStep(for track: LearnTrack, store: LearnProgressStore) -> HeaderStep? {
        if let next = track.lessons.first(where: { !store.isCompleted($0.id) }) {
            return .lesson(next, isFirst: store.completedLessonCount(in: track) == 0)
        }
        return store.quizPassed(for: track) ? nil : .quiz
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(alignment: .top, spacing: DS.Spacing.l) {
                IconWell(systemName: track.systemImage, tint: track.tint.color, size: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.primary)
                    Text(track.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                LearnPercentRing(progress: store.progress(for: track), tint: track.tint.color, size: 52)
            }

            HStack(spacing: DS.Spacing.s) {
                Tag(text: "\(track.lessons.count) lessons", systemImage: "book.closed.fill", tint: track.tint.color)
                Tag(text: "\(track.totalMinutes) min", systemImage: "clock.fill", tint: .secondary)
                Tag(text: "\(track.quiz.count)-question quiz", systemImage: "checkmark.circle.fill", tint: .secondary)
            }

            switch headerStep {
            case .lesson(let next, let isFirst):
                NavigationLink {
                    LearnLessonView(lesson: next, track: track)
                } label: {
                    Label(isFirst ? "Start track" : "Continue: \(next.title)", systemImage: "play.fill")
                        .lineLimit(1)
                }
                .buttonStyle(PrimaryButtonStyle())
            case .quiz:
                NavigationLink {
                    LearnQuizView(track: track)
                } label: {
                    Label("Take the quiz", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            case nil:
                EmptyView()
            }
        }
        .cardStyle()
    }

    /// The next unfinished lesson, or nil once every lesson is done.
    private var nextStepLesson: LearnLesson? {
        track.lessons.first { !store.isCompleted($0.id) }
    }

    // MARK: - Lessons

    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Lessons")

            VStack(spacing: 0) {
                ForEach(Array(track.lessons.enumerated()), id: \.element.id) { index, lesson in
                    if index > 0 {
                        Divider()
                            .overlay(Color.hairline)
                            .padding(.leading, DS.Spacing.l + 32 + DS.Spacing.m)
                    }
                    NavigationLink {
                        LearnLessonView(lesson: lesson, track: track)
                    } label: {
                        lessonRow(lesson, number: index + 1)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .cardStyle(padding: 0)
        }
    }

    private func lessonRow(_ lesson: LearnLesson, number: Int) -> some View {
        let isDone = store.isCompleted(lesson.id)

        return HStack(spacing: DS.Spacing.m) {
            ZStack {
                Circle()
                    .fill(isDone ? track.tint.color : Color.surfaceRaised)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                Text(lesson.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: DS.Spacing.s)

            Text("\(lesson.minutes) min")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? "Completed" : "Not started")
    }

    // MARK: - Quiz

    private var quizSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Quiz")

            NavigationLink {
                LearnQuizView(track: track)
            } label: {
                HStack(spacing: DS.Spacing.m) {
                    IconWell(systemName: "checkmark.seal.fill", tint: track.tint.color, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Check what you learned")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Text(quizCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if let result = store.quizResult(for: track) {
                        Text("\(result.score)/\(result.total)")
                            .arkadNumber(17)
                            .foregroundStyle(track.tint.color)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .cardStyle(padding: 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var quizCaption: String {
        if let result = store.quizResult(for: track) {
            if !store.quizPassed(for: track) {
                let needed = Int((Double(result.total) * LearnProgressStore.quizPassMark).rounded(.up))
                return "Best score \(result.score) of \(result.total). Get \(needed) right to finish the track."
            }
            return "Best score \(result.score) of \(result.total). Retake any time."
        }
        if nextStepLesson != nil {
            return "\(track.quiz.count) questions. Best after the lessons."
        }
        return "\(track.quiz.count) questions"
    }
}

#Preview {
    NavigationStack {
        LearnTrackView(track: LearnContent.tracks[0])
    }
}
