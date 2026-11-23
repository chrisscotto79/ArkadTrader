// File: Core/Communities/Events/EventDetailView.swift
// One event: date and time in the viewer's time zone, duration, details, the join link,
// who's going and the RSVP / Going toggle. Staff edit or delete it.

import SwiftUI

struct EventDetailView: View {
    let community: Community
    let eventId: String
    @ObservedObject var viewModel: EventsViewModel
    let isStaff: Bool
    let canRSVP: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showEdit = false
    @State private var showDelete = false
    @State private var actionError: String?

    private var event: CommunityEvent? { viewModel.event(id: eventId) }

    var body: some View {
        ScrollView {
            if let event {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    header(event)
                    whenCard(event)
                    if !event.details.isEmpty {
                        detailsCard(event)
                    }
                    if let url = event.linkURL {
                        linkButton(url, event: event)
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
            } else {
                EmptyStateView(
                    systemImage: "calendar.badge.exclamationmark",
                    title: "Event not found",
                    message: "It may have been cancelled."
                )
            }
        }
        .refreshable { await viewModel.refresh(eventId: eventId) }
        .safeAreaInset(edge: .bottom) {
            if let event, !event.isPast() {
                rsvpBar(event)
            }
        }
        .screenBackground()
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if isStaff && event != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showEdit = true } label: {
                            Label("Edit event", systemImage: "pencil")
                        }
                        Button(role: .destructive) { showDelete = true } label: {
                            Label("Delete event", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Event options")
                }
            }
        }
        .task(id: eventId) {
            viewModel.notice = nil
            await viewModel.refresh(eventId: eventId)
        }
        .sheet(isPresented: $showEdit) {
            if let event {
                EventEditorSheet(event: event) { draft in
                    try await viewModel.updateEvent(event, draft: draft)
                }
            }
        }
        .confirmationDialog("Delete this event?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete event", role: .destructive) {
                guard let event else { return }
                Task {
                    do {
                        try await viewModel.deleteEvent(event)
                        dismiss()
                    } catch {
                        actionError = ClassroomViewModel.friendly(error, doing: "delete the event")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Members who RSVP'd won't see it any more. This can't be undone.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { actionError != nil || viewModel.errorMessage != nil },
                set: { if !$0 { actionError = nil; viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private func header(_ event: CommunityEvent) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.s) {
                if event.isLive() {
                    Tag(text: "Live now", systemImage: "dot.radiowaves.left.and.right", tint: .marketRed)
                } else if event.isPast() {
                    Tag(text: "Ended", systemImage: "clock.arrow.circlepath", tint: .secondary)
                } else {
                    Tag(text: "Upcoming", systemImage: "calendar")
                }
                if viewModel.isGoing(event) {
                    Tag(text: "Going", systemImage: "checkmark", tint: .marketGreen)
                }
            }
            Text(event.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: DS.Spacing.s) {
                CommunityAvatar(community: community, size: 22)
                Text(community.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func whenCard(_ event: CommunityEvent) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            infoRow(icon: "calendar", title: EventFormat.fullDay(event.startsAt), subtitle: EventFormat.timeRange(event))
            infoRow(icon: "hourglass", title: EventFormat.duration(event.durationMinutes), subtitle: "Duration")
            infoRow(
                icon: "person.2.fill",
                title: EventFormat.rsvpCount(event.rsvpCount),
                subtitle: event.isPast() ? "RSVP'd" : (viewModel.isGoing(event) ? "Including you" : "Members who RSVP'd")
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func infoRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: icon, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func detailsCard(_ event: CommunityEvent) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Details")
                .font(.headline)
            Text(event.details)
                .font(.body)
                .foregroundStyle(Color.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func linkButton(_ url: URL, event: CommunityEvent) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: DS.Spacing.m) {
                IconWell(systemName: event.isLive() ? "play.fill" : "link", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.isLive() ? "Join now" : "Event link")
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

    // MARK: - RSVP

    private func rsvpBar(_ event: CommunityEvent) -> some View {
        let isGoing = viewModel.isGoing(event)
        let isBusy = viewModel.busyEventIds.contains(event.id)

        return VStack(spacing: DS.Spacing.s) {
            if let notice = viewModel.notice, isGoing {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !canRSVP {
                Text("Join the community to RSVP.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(Color.surfaceRaised))
            } else if isGoing {
                Button {
                    Task { await viewModel.toggleRSVP(event) }
                } label: {
                    HStack(spacing: DS.Spacing.s) {
                        if isBusy { ProgressView() } else { Image(systemName: "checkmark.circle.fill") }
                        Text("Going")
                    }
                    .foregroundStyle(Color.marketGreen)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isBusy)
                .accessibilityHint("Double tap to cancel your RSVP")
            } else {
                Button {
                    Task { await viewModel.toggleRSVP(event) }
                } label: {
                    HStack(spacing: DS.Spacing.s) {
                        if isBusy { ProgressView().tint(Color.onGold) } else { Image(systemName: "calendar.badge.plus") }
                        Text("RSVP")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isBusy)
            }
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.top, DS.Spacing.m)
        .padding(.bottom, DS.Spacing.s)
        .background(Color.appBackground.ignoresSafeArea())
        .overlay(alignment: .top) {
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
    }
}
