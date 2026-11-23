// File: Core/Communities/Events/EventsSectionView.swift
// The community's "Events" tab: upcoming events (soonest first) and past ones. Staff
// schedule new events. Sits inside the community page's scroll view.

import SwiftUI

struct EventsSectionView: View {
    let community: Community
    @ObservedObject var viewModel: EventsViewModel
    let isStaff: Bool
    /// Members (and the owner) can RSVP; others are asked to join first
    let canRSVP: Bool

    @State private var showNewEvent = false
    @State private var showAllPast = false

    private let pastPreviewCount = 5

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            if !viewModel.hasLoaded && viewModel.isLoading {
                placeholders
            } else if !viewModel.hasLoaded, let message = viewModel.errorMessage {
                EmptyStateView(
                    systemImage: "wifi.exclamationmark",
                    title: "Couldn't load events",
                    message: message,
                    actionTitle: "Try again",
                    action: { Task { await viewModel.reload() } }
                )
                .cardStyle(padding: 0)
            } else {
                upcomingSection
                if !viewModel.past.isEmpty {
                    pastSection
                }
            }
        }
        .task(id: community.id) {
            viewModel.configure(community: community)
            await viewModel.loadIfNeeded()
        }
        .sheet(isPresented: $showNewEvent) {
            EventEditorSheet(event: nil) { draft in
                try await viewModel.createEvent(draft)
            }
        }
    }

    // MARK: - Upcoming

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(
                title: "Upcoming",
                count: viewModel.upcoming.isEmpty ? nil : viewModel.upcoming.count,
                actionTitle: isStaff ? "New event" : nil,
                action: { showNewEvent = true }
            )

            if viewModel.upcoming.isEmpty {
                if isStaff {
                    EmptyStateView(
                        systemImage: "calendar.badge.plus",
                        title: "Schedule your first event",
                        message: "Host a live session, market open or Q&A. Members can RSVP and get a reminder.",
                        actionTitle: "Schedule an event",
                        action: { showNewEvent = true }
                    )
                    .cardStyle(padding: 0)
                } else {
                    EmptyStateView(
                        systemImage: "calendar",
                        title: "No upcoming events",
                        message: "When the leaders schedule a live session, it'll show up here."
                    )
                    .cardStyle(padding: 0)
                }
            } else {
                ForEach(viewModel.upcoming) { event in
                    eventLink(event)
                }
            }
        }
    }

    // MARK: - Past

    private var pastSection: some View {
        let shown = showAllPast ? viewModel.past : Array(viewModel.past.prefix(pastPreviewCount))
        return VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(
                title: "Past",
                actionTitle: viewModel.past.count > pastPreviewCount ? (showAllPast ? "Show less" : "Show all") : nil,
                action: { withAnimation(.snappy(duration: 0.25)) { showAllPast.toggle() } }
            )
            CommunityCardList(items: shown, dividerInset: 76) { event in
                NavigationLink {
                    EventDetailView(community: community, eventId: event.id, viewModel: viewModel, isStaff: isStaff, canRSVP: canRSVP)
                } label: {
                    EventRow(event: event, isGoing: false, isPast: true)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func eventLink(_ event: CommunityEvent) -> some View {
        NavigationLink {
            EventDetailView(community: community, eventId: event.id, viewModel: viewModel, isStaff: isStaff, canRSVP: canRSVP)
        } label: {
            EventRow(event: event, isGoing: viewModel.isGoing(event), isPast: false)
                .cardStyle(padding: 0)
        }
        .buttonStyle(PressableStyle())
    }

    private var placeholders: some View {
        VStack(spacing: DS.Spacing.m) {
            ForEach(0..<2, id: \.self) { _ in
                EventRow(
                    event: CommunityEvent(
                        id: UUID().uuidString, communityId: "", title: "Market open live session",
                        details: "", startsAt: Date().addingTimeInterval(86_400), durationMinutes: 60,
                        link: nil, createdBy: "", rsvpCount: 12, createdAt: nil
                    ),
                    isGoing: false,
                    isPast: false
                )
                .cardStyle(padding: 0)
            }
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }
}

// MARK: - Event row

/// One event: a date badge, the title, the time in the viewer's zone and who's going.
struct EventRow: View {
    let event: CommunityEvent
    let isGoing: Bool
    let isPast: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            EventDateBadge(date: event.startsAt, isPast: isPast)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isPast ? Color.secondary : Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(EventFormat.day(event.startsAt)) · \(EventFormat.timeRange(event))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                HStack(spacing: DS.Spacing.s) {
                    if event.isLive() {
                        Tag(text: "Live now", systemImage: "dot.radiowaves.left.and.right", tint: .marketRed)
                    }
                    if isGoing {
                        Tag(text: "Going", systemImage: "checkmark", tint: .marketGreen)
                    }
                    Label(EventFormat.rsvpCount(event.rsvpCount), systemImage: "person.2.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 1)
            }

            Spacer(minLength: DS.Spacing.s)
            CommunityChevron()
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// "NOV / 25" calendar badge
struct EventDateBadge: View {
    let date: Date
    var isPast = false

    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(isPast ? Color.secondary : Color.goldText)
            Text(date.formatted(.dateTime.day()))
                .arkadNumber(20)
                .foregroundStyle(isPast ? Color.secondary : Color.primary)
        }
        .frame(width: 48, height: 48)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                .fill(isPast ? Color.surfaceRaised : Color.goldTint)
        )
        .accessibilityHidden(true)
    }
}
