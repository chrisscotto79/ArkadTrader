// File: Core/Communities/Classroom/ClassroomEditors.swift
// Staff sheets for the Classroom: create / edit a course, create / edit a lesson
// (Markdown with a live preview), and reorder courses or lessons.

import SwiftUI

// MARK: - Course editor

struct CourseEditorSheet: View {
    /// nil creates a new course
    let course: CommunityCourse?
    let onSave: (_ title: String, _ summary: String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var summary = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedSummary: String { summary.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSave: Bool {
        !trimmedTitle.isEmpty
            && trimmedTitle.count <= ClassroomLimits.titleLength
            && trimmedSummary.count <= ClassroomLimits.summaryLength
    }

    private var hasChanges: Bool {
        trimmedTitle != (course?.title ?? "") || trimmedSummary != (course?.summary ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Course title", text: $title)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Title")
                } footer: {
                    ClassroomCharacterCount(count: trimmedTitle.count, limit: ClassroomLimits.titleLength)
                }
                .listRowBackground(Color.surface)

                Section {
                    TextField("What members will learn", text: $summary, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Summary")
                } footer: {
                    ClassroomCharacterCount(count: trimmedSummary.count, limit: ClassroomLimits.summaryLength)
                }
                .listRowBackground(Color.surface)

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.footnote).foregroundStyle(Color.marketRed)
                    }
                    .listRowBackground(Color.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .tint(Color.goldText)
            .navigationTitle(course == nil ? "New Course" : "Edit Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EditorCancelButton(hasChanges: hasChanges && !isSaving) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(course == nil ? "Create" : "Save", action: save)
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving || hasChanges)
            .onAppear {
                guard let course, title.isEmpty else { return }
                title = course.title
                summary = course.summary
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await onSave(trimmedTitle, trimmedSummary)
                HapticManager.shared.notification(type: .success)
                dismiss()
            } catch {
                errorMessage = ClassroomViewModel.friendly(error, doing: "save the course")
                isSaving = false
            }
        }
    }
}

// MARK: - Lesson editor

struct LessonEditorSheet: View {
    /// nil creates a new lesson
    let lesson: CommunityLesson?
    let courseTitle: String
    let onSave: (LessonDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var videoURL = ""
    @State private var bodyText = ""
    @State private var showsPreview = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedVideo: String { videoURL.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isVideoValid: Bool { ClassroomValidation.isValidOptionalLink(trimmedVideo) }

    private var canSave: Bool {
        !trimmedTitle.isEmpty
            && trimmedTitle.count <= ClassroomLimits.titleLength
            && bodyText.count <= ClassroomLimits.lessonBodyLength
            && isVideoValid
    }

    private var hasChanges: Bool {
        trimmedTitle != (lesson?.title ?? "")
            || trimmedVideo != (lesson?.videoURL ?? "")
            || bodyText != (lesson?.body ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Lesson title", text: $title)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Title")
                } footer: {
                    ClassroomCharacterCount(count: trimmedTitle.count, limit: ClassroomLimits.titleLength)
                }
                .listRowBackground(Color.surface)

                Section {
                    TextField("https://youtube.com/…", text: $videoURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Video (optional)")
                } footer: {
                    if isVideoValid {
                        Text("A YouTube, Vimeo or other https link. Members open it in the browser.")
                    } else {
                        Text("Use a full link that starts with https://")
                            .foregroundStyle(Color.marketRed)
                    }
                }
                .listRowBackground(Color.surface)

                Section {
                    Picker("Mode", selection: $showsPreview) {
                        Text("Write").tag(false)
                        Text("Preview").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)

                    if showsPreview {
                        if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Nothing to preview yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            MarkdownText(bodyText)
                                .padding(.vertical, DS.Spacing.s)
                        }
                    } else {
                        TextEditor(text: $bodyText)
                            .frame(minHeight: 280)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                    }
                } header: {
                    Text("Lesson")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Markdown works: # Heading, **bold**, *italic*, - lists, > tips and [links](https://…).")
                        ClassroomCharacterCount(count: bodyText.count, limit: ClassroomLimits.lessonBodyLength)
                    }
                }
                .listRowBackground(Color.surface)

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.footnote).foregroundStyle(Color.marketRed)
                    }
                    .listRowBackground(Color.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .tint(Color.goldText)
            .navigationTitle(lesson == nil ? "New Lesson" : "Edit Lesson")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EditorCancelButton(hasChanges: hasChanges && !isSaving) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(lesson == nil ? "Add" : "Save", action: save)
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving || hasChanges)
            .onAppear {
                guard let lesson, title.isEmpty else { return }
                title = lesson.title
                videoURL = lesson.videoURL ?? ""
                bodyText = lesson.body
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        let draft = LessonDraft(title: trimmedTitle, body: bodyText, videoURL: trimmedVideo)
        Task {
            do {
                try await onSave(draft)
                HapticManager.shared.notification(type: .success)
                dismiss()
            } catch {
                errorMessage = ClassroomViewModel.friendly(error, doing: "save the lesson")
                isSaving = false
            }
        }
    }
}

// MARK: - Reorder

/// One row in the reorder sheet.
struct ClassroomReorderItem: Identifiable, Equatable {
    let id: String
    let title: String
}

/// Drag to reorder courses or lessons. Saves `order` for the rows that moved.
struct ClassroomReorderSheet: View {
    let title: String
    let onSave: ([String]) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var items: [ClassroomReorderItem]
    private let original: [ClassroomReorderItem]
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(title: String, items: [ClassroomReorderItem], onSave: @escaping ([String]) async throws -> Void) {
        self.title = title
        self.onSave = onSave
        self.original = items
        _items = State(initialValue: items)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: DS.Spacing.m) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .leading)
                            Text(item.title)
                                .font(.body)
                                .lineLimit(2)
                        }
                    }
                    .onMove { source, destination in
                        items.move(fromOffsets: source, toOffset: destination)
                    }
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(Color.marketRed)
                    } else {
                        Text("Drag the handles to change the order members see.")
                    }
                }
                .listRowBackground(Color.surface)
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .screenBackground()
            .tint(Color.goldText)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EditorCancelButton(hasChanges: items != original && !isSaving) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save", action: save)
                            .fontWeight(.semibold)
                            .disabled(items == original)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving || items != original)
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await onSave(items.map(\.id))
                dismiss()
            } catch {
                errorMessage = ClassroomViewModel.friendly(error, doing: "save the order")
                isSaving = false
            }
        }
    }
}

// MARK: - Character count

struct ClassroomCharacterCount: View {
    let count: Int
    let limit: Int

    var body: some View {
        Text("\(count.formatted()) / \(limit.formatted())")
            .font(.caption.monospacedDigit())
            .foregroundStyle(count > limit ? Color.marketRed : .secondary)
    }
}

// MARK: - Cancel with unsaved changes

/// Cancel for an editor sheet: asks before throwing away changes. Pair it with
/// `.interactiveDismissDisabled(hasChanges)` so a swipe can't discard them either.
struct EditorCancelButton: View {
    let hasChanges: Bool
    let onDiscard: () -> Void

    @State private var isConfirming = false

    var body: some View {
        Button("Cancel") {
            if hasChanges { isConfirming = true } else { onDiscard() }
        }
        .confirmationDialog("Discard your changes?", isPresented: $isConfirming, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive, action: onDiscard)
            Button("Keep editing", role: .cancel) {}
        }
    }
}
