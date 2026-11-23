// File: Core/Communities/Classroom/LessonReaderView.swift
// Reads one Classroom lesson: title, an optional "Watch video" button (opens the link in the
// browser), the Markdown body and "Mark complete" / "Completed". "Next lesson" swaps the
// content in place, like the Learn lessons, so the stack stays shallow.

import SwiftUI

struct LessonReaderView: View {
    let course: CommunityCourse
    @State private var lesson: CommunityLesson
    @ObservedObject var viewModel: ClassroomViewModel
    let isStaff: Bool

    @Environment(\.openURL) private var openURL
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showEdit = false

    private let topAnchor = "lesson-top"

    init(course: CommunityCourse, lesson: CommunityLesson, viewModel: ClassroomViewModel, isStaff: Bool) {
        self.course = course
        _lesson = State(initialValue: lesson)
        self.viewModel = viewModel
        self.isStaff = isStaff
    }

    private var lessons: [CommunityLesson] { viewModel.lessons(for: course.id) }
    private var index: Int { lessons.firstIndex { $0.id == lesson.id } ?? 0 }
    private var nextLesson: LessonNext? {
        let next = index + 1
        return next < lessons.count ? LessonNext(lesson: lessons[next]) : nil
    }
    private var isCompleted: Bool { viewModel.isCompleted(lessonId: lesson.id, courseId: course.id) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    header
                        .id(topAnchor)

                    if let url = lesson.videoLink {
                        videoButton(url)
                    }

                    if lesson.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(lesson.videoLink == nil ? "This lesson has no content yet." : "Watch the video above for this lesson.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        MarkdownText(lesson.body)
                    }

                    footer(proxy: proxy)
                        .padding(.top, DS.Spacing.s)

                    LearnDisclaimer()
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
            }
        }
        .screenBackground()
        .navigationTitle(lessons.isEmpty ? course.title : "Lesson \(index + 1) of \(lessons.count)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if isStaff {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEdit = true } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Edit lesson")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            LessonEditorSheet(lesson: lesson, courseTitle: course.title) { draft in
                try await viewModel.updateLesson(lesson, draft: draft)
                if let updated = viewModel.lessons(for: course.id).first(where: { $0.id == lesson.id }) {
                    lesson = updated
                }
            }
        }
        .alert(
            "Couldn't save your progress",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.s) {
                Tag(text: course.title, systemImage: "book.closed.fill")
                    .lineLimit(1)
                Tag(text: "\(lesson.readingMinutes) min read", systemImage: "clock", tint: .secondary)
                if isCompleted {
                    Tag(text: "Done", systemImage: "checkmark", tint: .marketGreen)
                }
            }
            Text(lesson.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if !lessons.isEmpty {
                LearnProgressBar(
                    progress: Double(viewModel.completedCount(for: course)) / Double(max(lessons.count, 1)),
                    height: 4
                )
                .padding(.top, DS.Spacing.xs)
            }
        }
    }

    private func videoButton(_ url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: DS.Spacing.m) {
                IconWell(systemName: "play.fill", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Watch video")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text(url.host ?? url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .cardStyle(padding: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Opens in your browser")
    }

    // MARK: - Footer

    @ViewBuilder
    private func footer(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: DS.Spacing.m) {
            if !isCompleted {
                Button {
                    setCompleted(true)
                } label: {
                    HStack(spacing: DS.Spacing.s) {
                        if isSaving { ProgressView().tint(Color.onGold) }
                        Label("Mark complete", systemImage: "checkmark")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving)
            } else {
                Label("Completed", systemImage: "checkmark.circle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.marketGreen)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(Color.marketGreen.opacity(0.14)))
                    .accessibilityAddTraits(.isStaticText)

                if let next = nextLesson {
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            lesson = next.lesson
                            proxy.scrollTo(topAnchor, anchor: .top)
                        }
                    } label: {
                        Label("Next: \(next.lesson.title)", systemImage: "arrow.right")
                            .lineLimit(1)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Text("That's the last lesson in \(course.title).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                Button("Mark as not done") {
                    setCompleted(false)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .disabled(isSaving)
            }
        }
    }

    private func setCompleted(_ done: Bool) {
        isSaving = true
        Task {
            do {
                try await viewModel.setCompleted(done, lesson: lesson)
                if done { HapticManager.shared.notification(type: .success) }
            } catch {
                errorMessage = ClassroomViewModel.friendly(error, doing: "save your progress")
            }
            isSaving = false
        }
    }
}

/// Wraps the next lesson so the footer's optional reads clearly.
private struct LessonNext {
    let lesson: CommunityLesson
}
