// File: Core/Learn/LearnLessonView.swift
// One lesson: headings, paragraphs, bullets, worked examples and tips, then the
// "Key takeaways" box. "Next lesson" swaps the content in place so the stack stays shallow;
// the last lesson leads to the track's quiz.

import SwiftUI

struct LearnLessonView: View {
    let track: LearnTrack
    @State private var lesson: LearnLesson
    @ObservedObject private var store = LearnProgressStore.shared

    init(lesson: LearnLesson, track: LearnTrack) {
        self.track = track
        _lesson = State(initialValue: lesson)
    }

    private let topAnchor = "lesson-top"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    header
                        .id(topAnchor)

                    ForEach(Array(lesson.blocks.enumerated()), id: \.offset) { _, block in
                        blockView(block)
                    }

                    if !lesson.takeaways.isEmpty {
                        takeawaysBox
                            .padding(.top, DS.Spacing.s)
                    }

                    footerAction(proxy: proxy)
                        .padding(.top, DS.Spacing.s)

                    LearnDisclaimer()
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
            }
        }
        .screenBackground()
        .navigationTitle(positionText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear { store.markOpened(lesson) }
        .onChange(of: lesson.id) { _, _ in store.markOpened(lesson) }
    }

    // MARK: - Header

    private var lessonIndex: Int {
        track.lessons.firstIndex { $0.id == lesson.id } ?? 0
    }

    private var positionText: String {
        "Lesson \(lessonIndex + 1) of \(track.lessons.count)"
    }

    private var nextLesson: LearnLesson? {
        let next = lessonIndex + 1
        return next < track.lessons.count ? track.lessons[next] : nil
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.s) {
                Tag(text: track.title, systemImage: track.systemImage, tint: track.tint.color)
                Tag(text: "\(lesson.minutes) min read", systemImage: "clock", tint: .secondary)
                if store.isCompleted(lesson.id) {
                    Tag(text: "Done", systemImage: "checkmark", tint: .marketGreen)
                }
            }
            Text(lesson.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(lesson.summary)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LearnProgressBar(
                progress: Double(lessonIndex + (store.isCompleted(lesson.id) ? 1 : 0)) / Double(max(track.lessons.count, 1)),
                tint: track.tint.color,
                height: 4
            )
            .padding(.top, DS.Spacing.xs)
        }
    }

    // MARK: - Blocks

    @ViewBuilder
    private func blockView(_ block: LearnBlock) -> some View {
        switch block {
        case .heading(let text):
            Text(text)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DS.Spacing.s)
                .accessibilityAddTraits(.isHeader)

        case .paragraph(let text):
            Text(text)
                .font(.body)
                .foregroundStyle(Color.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                        Circle()
                            .fill(track.tint.color)
                            .frame(width: 6, height: 6)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                            .accessibilityHidden(true)
                        Text(item)
                            .font(.body)
                            .foregroundStyle(Color.primary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .example(let title, let lines):
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Label(title, systemImage: "function")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(track.tint.color)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.l)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(Color.surfaceRaised)
            )
            .accessibilityElement(children: .combine)

        case .tip(let text):
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                Image(systemName: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.goldText)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.l)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(Color.goldTint)
            )
            .accessibilityElement(children: .combine)

        case .tool(let tool):
            toolLink(tool)
        }
    }

    @ViewBuilder
    private func toolLink(_ tool: LearnTool) -> some View {
        switch tool {
        case .positionSize:
            NavigationLink {
                PositionSizeCalculatorView()
            } label: {
                HStack(spacing: DS.Spacing.m) {
                    IconWell(systemName: "plusminus.circle.fill", tint: track.tint.color, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Try it yourself")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Text("Open the position size calculator")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
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

    // MARK: - Takeaways

    private var takeawaysBox: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Label("Key takeaways", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(Color.goldText)

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                ForEach(Array(lesson.takeaways.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.goldText)
                            .accessibilityHidden(true)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .strokeBorder(Color.goldText.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Footer action

    @ViewBuilder
    private func footerAction(proxy: ScrollViewProxy) -> some View {
        if !store.isCompleted(lesson.id) {
            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.snappy(duration: 0.25)) {
                    store.markCompleted(lesson)
                }
            } label: {
                Label("Mark as complete", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryButtonStyle())
        } else if let next = nextLesson {
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    lesson = next
                    proxy.scrollTo(topAnchor, anchor: .top)
                }
            } label: {
                Label("Next: \(next.title)", systemImage: "arrow.right")
                    .lineLimit(1)
            }
            .buttonStyle(PrimaryButtonStyle())
        } else {
            VStack(spacing: DS.Spacing.m) {
                Text("That's the last lesson in \(track.title).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                NavigationLink {
                    LearnQuizView(track: track)
                } label: {
                    Label(store.quizResult(for: track) == nil ? "Take the quiz" : "Retake the quiz", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

#Preview {
    NavigationStack {
        LearnLessonView(lesson: LearnContent.tracks[1].lessons[1], track: LearnContent.tracks[1])
    }
}
