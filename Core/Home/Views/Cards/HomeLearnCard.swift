// File: Core/Home/Views/Cards/HomeLearnCard.swift
// Compact "Keep learning" card at the top of the Home feed. It resumes the next unfinished lesson
// (LearnProgressStore.continueLesson), or opens the Learn hub with "Start learning" before the
// user has begun. It pushes inside Home's NavigationStack. The close button hides it until
// tomorrow (@AppStorage), and it hides itself once every lesson is done.

import SwiftUI

struct HomeLearnCard: View {
    @ObservedObject private var store = LearnProgressStore.shared
    /// The day ("yyyy-MM-dd") the card was dismissed; hidden for the rest of that day
    @AppStorage("homeLearnCardDismissedDay") private var dismissedDay = ""

    var body: some View {
        Group {
            if isVisible {
                card
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .task { await store.load() }
    }

    private static func dayKey(_ date: Date = Date()) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private var isVisible: Bool {
        dismissedDay != Self.dayKey() && !allDone
    }

    private var total: Int { LearnContent.totalLessonCount }
    private var done: Int { store.totalCompletedLessons }
    private var allDone: Bool { total > 0 && done >= total }

    /// The lesson and its track to resume, once the user has started
    private var resume: (lesson: LearnLesson, track: LearnTrack)? {
        guard store.hasStarted, let lesson = store.continueLesson,
              let track = LearnContent.track(containing: lesson.id) else { return nil }
        return (lesson, track)
    }

    private var card: some View {
        HStack(spacing: DS.Spacing.m) {
            link
            Button {
                withAnimation(.snappy(duration: 0.25)) { dismissedDay = Self.dayKey() }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Hide for today")
        }
        .padding(.leading, DS.Spacing.l)
        .padding(.trailing, DS.Spacing.s)
        .padding(.vertical, DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .fill(Color.goldTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .strokeBorder(Color.goldText.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var link: some View {
        if let resume {
            NavigationLink {
                LearnLessonView(lesson: resume.lesson, track: resume.track)
            } label: {
                content(
                    title: "Keep learning",
                    subtitle: "Next: \(resume.lesson.title) · \(resume.lesson.minutes) min",
                    action: "Resume"
                )
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Opens your next lesson")
        } else {
            NavigationLink {
                LearnHubView()
            } label: {
                content(
                    title: "Start learning",
                    subtitle: "Short lessons on stocks, options, crypto, forex and risk",
                    action: "Start"
                )
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Opens Learn")
        }
    }

    private func content(title: String, subtitle: String, action: String) -> some View {
        HStack(spacing: DS.Spacing.m) {
            if done > 0 {
                LearnPercentRing(progress: total == 0 ? 0 : Double(done) / Double(total), size: 40)
            } else {
                IconWell(systemName: "book.fill", size: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Spacing.s)

            Text(action)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.goldText)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        HomeLearnCard()
            .padding()
            .screenBackground()
    }
}
