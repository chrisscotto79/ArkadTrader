// File: Core/Communities/Events/EventEditorSheet.swift
// Staff sheet to schedule or edit an event: title, details, start date and time (in the
// staff member's own time zone), duration and an optional https link.

import SwiftUI

struct EventEditorSheet: View {
    /// nil schedules a new event
    let event: CommunityEvent?
    let onSave: (EventDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var startsAt = EventEditorSheet.defaultStart()
    @State private var durationMinutes = EventLimits.defaultDuration
    @State private var link = ""
    @State private var didLoad = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedDetails: String { details.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedLink: String { link.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isLinkValid: Bool { ClassroomValidation.isValidOptionalLink(trimmedLink) }

    /// New events must start in the future; edits may keep a time that has passed.
    private var startRange: PartialRangeFrom<Date> {
        if let event, event.startsAt < Date() { return event.startsAt... }
        return Date()...
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty
            && trimmedTitle.count <= EventLimits.titleLength
            && trimmedDetails.count <= EventLimits.detailsLength
            && isLinkValid
            && (event != nil || startsAt > Date())
    }

    private var durationOptions: [Int] {
        var options = EventLimits.durations
        if !options.contains(durationMinutes) { options.append(durationMinutes) }
        return options.sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Event title", text: $title)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Title")
                } footer: {
                    ClassroomCharacterCount(count: trimmedTitle.count, limit: EventLimits.titleLength)
                }
                .listRowBackground(Color.surface)

                Section {
                    DatePicker("Starts", selection: $startsAt, in: startRange, displayedComponents: [.date, .hourAndMinute])
                    Picker("Duration", selection: $durationMinutes) {
                        ForEach(durationOptions, id: \.self) { minutes in
                            Text(EventFormat.duration(minutes)).tag(minutes)
                        }
                    }
                } header: {
                    Text("When")
                } footer: {
                    Text("Times are in your time zone (\(TimeZone.current.abbreviation(for: startsAt) ?? TimeZone.current.identifier)). Members see them in theirs.")
                }
                .listRowBackground(Color.surface)

                Section {
                    TextField("What you'll cover, what to bring", text: $details, axis: .vertical)
                        .lineLimit(4...10)
                } header: {
                    Text("Details")
                } footer: {
                    ClassroomCharacterCount(count: trimmedDetails.count, limit: EventLimits.detailsLength)
                }
                .listRowBackground(Color.surface)

                Section {
                    TextField("https://zoom.us/j/…", text: $link)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Link (optional)")
                } footer: {
                    if isLinkValid {
                        Text("Where members join: a Zoom, YouTube Live or other https link.")
                    } else {
                        Text("Use a full link that starts with https://")
                            .foregroundStyle(Color.marketRed)
                    }
                }
                .listRowBackground(Color.surface)

                if event == nil {
                    Section {
                        Label("Members get a notification when you schedule this.", systemImage: "bell.badge")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.surface)
                }

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
            .navigationTitle(event == nil ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(event == nil ? "Schedule" : "Save", action: save)
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                guard let event else { return }
                title = event.title
                details = event.details
                startsAt = event.startsAt
                durationMinutes = event.durationMinutes
                link = event.link ?? ""
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        let draft = EventDraft(
            title: trimmedTitle,
            details: trimmedDetails,
            startsAt: startsAt,
            durationMinutes: durationMinutes,
            link: trimmedLink
        )
        Task {
            do {
                try await onSave(draft)
                HapticManager.shared.notification(type: .success)
                dismiss()
            } catch {
                errorMessage = ClassroomViewModel.friendly(error, doing: "save the event")
                isSaving = false
            }
        }
    }

    /// The next whole hour, at least 30 minutes away.
    private static func defaultStart() -> Date {
        let calendar = Calendar.current
        let soon = Date().addingTimeInterval(30 * 60)
        let hour = calendar.dateInterval(of: .hour, for: soon)?.end ?? soon
        return hour
    }
}
