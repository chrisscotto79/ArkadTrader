// File: Core/Communities/Classroom/ClassroomSectionView.swift
// The community's "Classroom" tab: courses with the signed-in user's progress. Staff
// (owner, admin, moderator) create courses and change their order. Sits inside the
// community page's scroll view, so it has no scroll view of its own.

import SwiftUI

struct ClassroomSectionView: View {
    let community: Community
    @ObservedObject var viewModel: ClassroomViewModel
    let isStaff: Bool

    @State private var showNewCourse = false
    @State private var showReorder = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            if viewModel.hasLoaded && !viewModel.courses.isEmpty {
                SectionHeader(
                    title: "Courses",
                    count: viewModel.courses.count,
                    actionTitle: isStaff ? "New course" : nil,
                    action: { showNewCourse = true }
                )
            }

            if viewModel.hasLoaded, let message = viewModel.errorMessage {
                CommunityRefreshBanner(message: message) {
                    Task { await viewModel.reload() }
                }
            }

            if !viewModel.hasLoaded && viewModel.isLoading {
                placeholders
            } else if !viewModel.hasLoaded, let message = viewModel.errorMessage {
                loadFailed(message)
            } else if viewModel.courses.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.courses) { course in
                    NavigationLink {
                        CourseDetailView(community: community, courseId: course.id, viewModel: viewModel, isStaff: isStaff)
                    } label: {
                        ClassroomCourseCard(
                            course: course,
                            progress: viewModel.progress(for: course),
                            completed: viewModel.completedCount(for: course)
                        )
                    }
                    .buttonStyle(PressableStyle())
                }

                if isStaff && viewModel.courses.count > 1 {
                    Button {
                        showReorder = true
                    } label: {
                        Label("Reorder courses", systemImage: "arrow.up.arrow.down")
                    }
                    .buttonStyle(PillButtonStyle(kind: .neutral))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, DS.Spacing.xs)
                }
            }
        }
        .task(id: community.id) {
            viewModel.configure(communityId: community.id)
            await viewModel.loadIfNeeded()
        }
        .sheet(isPresented: $showNewCourse) {
            CourseEditorSheet(course: nil) { title, summary in
                try await viewModel.createCourse(title: title, summary: summary)
            }
        }
        .sheet(isPresented: $showReorder) {
            ClassroomReorderSheet(
                title: "Reorder Courses",
                items: viewModel.courses.map { ClassroomReorderItem(id: $0.id, title: $0.title) }
            ) { ids in
                try await viewModel.reorderCourses(ids)
            }
        }
    }

    // MARK: - States

    private var placeholders: some View {
        VStack(spacing: DS.Spacing.m) {
            ForEach(0..<2, id: \.self) { _ in
                ClassroomCourseCard(
                    course: CommunityCourse(
                        id: UUID().uuidString, communityId: "", title: "Course title here",
                        summary: "A short summary of what this course covers.", order: 0,
                        lessonCount: 4, createdBy: "", createdAt: nil, updatedAt: nil
                    ),
                    progress: 0,
                    completed: 0
                )
            }
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }

    private func loadFailed(_ message: String) -> some View {
        EmptyStateView(
            systemImage: "wifi.exclamationmark",
            title: "Couldn't load the classroom",
            message: message,
            actionTitle: "Try again",
            action: { Task { await viewModel.reload() } }
        )
        .cardStyle(padding: 0)
    }

    @ViewBuilder
    private var emptyState: some View {
        if isStaff {
            EmptyStateView(
                systemImage: "graduationcap.fill",
                title: "Create your first course",
                message: "Teach your strategy step by step. Members see their progress through each lesson.",
                actionTitle: "Create a course",
                action: { showNewCourse = true }
            )
            .cardStyle(padding: 0)
        } else {
            EmptyStateView(
                systemImage: "graduationcap.fill",
                title: "No courses yet",
                message: "When the leaders add courses, you'll find them here."
            )
            .cardStyle(padding: 0)
        }
    }
}

// MARK: - Course card

/// A course in the list: title, summary and the user's progress through its lessons.
struct ClassroomCourseCard: View {
    let course: CommunityCourse
    let progress: Double
    let completed: Int

    private var isComplete: Bool { course.lessonCount > 0 && progress >= 1 }

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            IconWell(systemName: "book.closed.fill", size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !course.summary.isEmpty {
                    Text(course.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: DS.Spacing.s) {
                    LearnProgressBar(progress: progress, height: 5)
                        .frame(maxWidth: 120)
                    Text(caption)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.goldText)
                    .accessibilityLabel("Complete")
            } else {
                LearnPercentRing(progress: progress, size: 40)
            }
        }
        .cardStyle(padding: 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var caption: String {
        if course.lessonCount == 0 { return "No lessons yet" }
        if completed == 0 {
            return course.lessonCount == 1 ? "1 lesson" : "\(course.lessonCount) lessons"
        }
        return "\(completed) of \(course.lessonCount) lessons"
    }
}

// MARK: - Refresh banner

/// Shown above content that's still on screen when refreshing it failed.
struct CommunityRefreshBanner: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.marketRed)
                .accessibilityHidden(true)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DS.Spacing.s)
            Button("Retry", action: onRetry)
                .buttonStyle(PillButtonStyle(kind: .neutral))
        }
        .padding(DS.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 0)
        .accessibilityElement(children: .combine)
    }
}
