// File: Core/Communities/Classroom/CourseDetailView.swift
// One course: its progress, a "Start" / "Continue" button and the lessons in order, with
// checkmarks on the ones the user finished. Staff add, edit, delete and reorder lessons,
// and edit or delete the course.

import SwiftUI

struct CourseDetailView: View {
    let community: Community
    let courseId: String
    @ObservedObject var viewModel: ClassroomViewModel
    let isStaff: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var showNewLesson = false
    @State private var showEditCourse = false
    @State private var showReorder = false
    @State private var showDeleteCourse = false
    @State private var lessonToEdit: CommunityLesson?
    @State private var lessonToDelete: CommunityLesson?
    @State private var actionError: String?
    /// The header's next lesson, captured while this screen is on top so its link doesn't
    /// change (and pop the reader) when progress changes.
    @State private var continueLesson: CommunityLesson?

    private var course: CommunityCourse? { viewModel.course(id: courseId) }
    private var lessons: [CommunityLesson] { viewModel.lessons(for: courseId) }
    private var hasLoadedLessons: Bool { viewModel.lessonsByCourse[courseId] != nil }

    var body: some View {
        ScrollView {
            if let course {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    header(course)
                    lessonsSection(course)
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
            } else {
                EmptyStateView(
                    systemImage: "book.closed",
                    title: "Course not found",
                    message: "It may have been deleted."
                )
            }
        }
        .refreshable {
            await viewModel.loadLessons(courseId: courseId)
        }
        .screenBackground()
        .navigationTitle(course?.title ?? "Course")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if isStaff && course != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    staffMenu
                }
            }
        }
        .task(id: courseId) {
            await viewModel.loadLessons(courseId: courseId)
            if isStaff { await viewModel.repairLessonCountIfNeeded(courseId: courseId) }
            continueLesson = viewModel.nextLesson(in: courseId)
        }
        .onAppear {
            if hasLoadedLessons { continueLesson = viewModel.nextLesson(in: courseId) }
        }
        .sheet(isPresented: $showNewLesson) {
            if let course {
                LessonEditorSheet(lesson: nil, courseTitle: course.title) { draft in
                    try await viewModel.createLesson(in: course, draft: draft)
                    continueLesson = viewModel.nextLesson(in: courseId)
                }
            }
        }
        .sheet(isPresented: $showEditCourse) {
            if let course {
                CourseEditorSheet(course: course) { title, summary in
                    try await viewModel.updateCourse(course, title: title, summary: summary)
                }
            }
        }
        .sheet(item: $lessonToEdit) { lesson in
            LessonEditorSheet(lesson: lesson, courseTitle: course?.title ?? "") { draft in
                try await viewModel.updateLesson(lesson, draft: draft)
            }
        }
        .sheet(isPresented: $showReorder) {
            ClassroomReorderSheet(
                title: "Reorder Lessons",
                items: lessons.map { ClassroomReorderItem(id: $0.id, title: $0.title) }
            ) { ids in
                try await viewModel.reorderLessons(in: courseId, orderedIds: ids)
                continueLesson = viewModel.nextLesson(in: courseId)
            }
        }
        .confirmationDialog(
            "Delete this course?",
            isPresented: $showDeleteCourse,
            titleVisibility: .visible
        ) {
            Button("Delete course and lessons", role: .destructive) {
                guard let course else { return }
                Task {
                    do {
                        try await viewModel.deleteCourse(course)
                        dismiss()
                    } catch {
                        actionError = ClassroomViewModel.friendly(error, doing: "delete the course")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its \(course?.lessonCount ?? 0) lessons are deleted too. This can't be undone.")
        }
        .confirmationDialog(
            lessonToDelete.map { "Delete \"\($0.title)\"?" } ?? "Delete lesson?",
            isPresented: Binding(get: { lessonToDelete != nil }, set: { if !$0 { lessonToDelete = nil } }),
            titleVisibility: .visible,
            presenting: lessonToDelete
        ) { lesson in
            Button("Delete lesson", role: .destructive) {
                Task {
                    do {
                        try await viewModel.deleteLesson(lesson)
                        continueLesson = viewModel.nextLesson(in: courseId)
                    } catch {
                        actionError = ClassroomViewModel.friendly(error, doing: "delete the lesson")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This can't be undone.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: - Staff menu

    private var staffMenu: some View {
        Menu {
            Button { showNewLesson = true } label: {
                Label("New lesson", systemImage: "plus")
            }
            Button { showEditCourse = true } label: {
                Label("Edit course", systemImage: "pencil")
            }
            if lessons.count > 1 {
                Button { showReorder = true } label: {
                    Label("Reorder lessons", systemImage: "arrow.up.arrow.down")
                }
            }
            Divider()
            Button(role: .destructive) { showDeleteCourse = true } label: {
                Label("Delete course", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Course options")
    }

    // MARK: - Header

    private func header(_ course: CommunityCourse) -> some View {
        let progress = viewModel.progress(for: course)
        let total = hasLoadedLessons ? lessons.count : course.lessonCount

        return VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(alignment: .top, spacing: DS.Spacing.l) {
                IconWell(systemName: "book.closed.fill", size: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !course.summary.isEmpty {
                        Text(course.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                LearnPercentRing(progress: progress, size: 52)
            }

            HStack(spacing: DS.Spacing.s) {
                Tag(text: total == 1 ? "1 lesson" : "\(total) lessons", systemImage: "book.closed.fill")
                Tag(text: "\(viewModel.completedCount(for: course)) done", systemImage: "checkmark.circle.fill", tint: .secondary)
                Tag(text: community.name, systemImage: "person.3.fill", tint: .secondary)
            }

            if let next = continueLesson {
                NavigationLink {
                    LessonReaderView(course: course, lesson: next, viewModel: viewModel, isStaff: isStaff)
                } label: {
                    Label(
                        viewModel.completedCount(for: course) == 0 ? "Start course" : "Continue: \(next.title)",
                        systemImage: "play.fill"
                    )
                    .lineLimit(1)
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if total > 0 && progress >= 1 {
                Label("You finished this course", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.goldText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Capsule().fill(Color.goldTint))
            }
        }
        .cardStyle()
    }

    // MARK: - Lessons

    @ViewBuilder
    private func lessonsSection(_ course: CommunityCourse) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(
                title: "Lessons",
                actionTitle: isStaff ? "Add lesson" : nil,
                action: { showNewLesson = true }
            )

            if !hasLoadedLessons, let message = viewModel.lessonLoadErrors[courseId] {
                EmptyStateView(
                    systemImage: "wifi.exclamationmark",
                    title: "Couldn't load the lessons",
                    message: message,
                    actionTitle: "Try again",
                    action: { Task { await viewModel.loadLessons(courseId: courseId) } }
                )
                .cardStyle(padding: 0)
            } else if !hasLoadedLessons {
                HStack(spacing: DS.Spacing.m) {
                    ProgressView()
                    Text("Loading lessons…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            } else if lessons.isEmpty {
                if isStaff {
                    EmptyStateView(
                        systemImage: "text.book.closed.fill",
                        title: "Add the first lesson",
                        message: "Write it in Markdown and add a video link if you have one.",
                        actionTitle: "Add a lesson",
                        action: { showNewLesson = true }
                    )
                    .cardStyle(padding: 0)
                } else {
                    EmptyStateView(
                        systemImage: "text.book.closed.fill",
                        title: "No lessons yet",
                        message: "Lessons for this course will show up here."
                    )
                    .cardStyle(padding: 0)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                        if index > 0 {
                            Divider()
                                .overlay(Color.hairline)
                                .padding(.leading, DS.Spacing.l + 32 + DS.Spacing.m)
                        }
                        NavigationLink {
                            LessonReaderView(course: course, lesson: lesson, viewModel: viewModel, isStaff: isStaff)
                        } label: {
                            lessonRow(lesson, number: index + 1)
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu {
                            if isStaff {
                                Button { lessonToEdit = lesson } label: {
                                    Label("Edit lesson", systemImage: "pencil")
                                }
                                Button(role: .destructive) { lessonToDelete = lesson } label: {
                                    Label("Delete lesson", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .cardStyle(padding: 0)
            }
        }
    }

    private func lessonRow(_ lesson: CommunityLesson, number: Int) -> some View {
        let isDone = viewModel.isCompleted(lessonId: lesson.id, courseId: courseId)

        return HStack(spacing: DS.Spacing.m) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.arkadGold : Color.surfaceRaised)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.onGold)
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
                HStack(spacing: 6) {
                    if lesson.videoLink != nil {
                        Label("Video", systemImage: "play.rectangle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    Text("\(lesson.readingMinutes) min read")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: DS.Spacing.s)

            CommunityChevron()
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? "Completed" : "Not completed")
    }
}
