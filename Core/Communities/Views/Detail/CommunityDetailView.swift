// File: Core/Communities/Views/Detail/CommunityDetailView.swift
// A community's home page: hero header with the join / manage action, shortcuts to members
// and the leaderboard, and the channel list.

import SwiftUI

struct CommunityDetailView: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CommunityDetailViewModel()

    // View States
    @State private var showMembersList = false
    @State private var showCommunitySettings = false
    @State private var showCreateChannel = false
    @State private var selectedChannel: Channel?
    @State private var showChannelOptions = false
    @State private var channelToEdit: Channel?
    @State private var channelForInfo: Channel?
    @State private var showLeaderboard = false
    @State private var showLeaveConfirmation = false

    /// Latest copy of the community (refreshed after settings change), falling back to the one passed in.
    private var current: Community { viewModel.community ?? community }

    private var isOwner: Bool { viewModel.userRole == "owner" }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    heroCard
                    shortcuts
                    channelsSection
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .refreshable {
                await viewModel.reloadCommunity()
                await viewModel.reloadChannels()
                await viewModel.refreshUserMembership()
            }
        }
        .screenBackground()
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadCommunityData(community: community)
        }
        .sheet(isPresented: $showMembersList) {
            EnhancedMembersListSheet(community: community)
        }
        .sheet(isPresented: $showCommunitySettings, onDismiss: {
            Task { await viewModel.reloadCommunity() }
        }) {
            EnhancedCommunitySettingsSheet(community: current)
        }
        .sheet(isPresented: $showCreateChannel, onDismiss: {
            Task { await viewModel.reloadChannels() }
        }) {
            CreateChannelSheet(community: current)
        }
        .sheet(item: $channelToEdit, onDismiss: {
            Task { await viewModel.reloadChannels() }
        }) { channel in
            CreateChannelSheet(community: current, editing: channel)
        }
        .sheet(item: $channelForInfo) { channel in
            ChannelInfoSheet(community: current, channel: channel)
                .presentationDetents([.medium])
        }
        .navigationDestination(isPresented: $showLeaderboard) {
            CommunityLeaderboardView(community: current)
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { !viewModel.errorMessage.isEmpty }, set: { if !$0 { viewModel.clearError() } })
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .confirmationDialog(
            "Leave \(current.name)?",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Community", role: .destructive) {
                HapticManager.shared.notification(type: .warning)
                viewModel.leaveCommunity()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You'll stop seeing its channels and callouts. You can join again any time.")
        }
        .confirmationDialog(
            selectedChannel.map { "#\($0.name)" } ?? "Channel",
            isPresented: $showChannelOptions,
            titleVisibility: .visible
        ) {
            if let channel = selectedChannel {
                if viewModel.canManageChannels && !channel.isDefault {
                    Button("Edit Channel") {
                        channelToEdit = channel
                    }

                    Button("Delete Channel", role: .destructive) {
                        Task {
                            do {
                                try await viewModel.deleteChannel(channel)
                            } catch {
                                viewModel.errorMessage = "Couldn't delete #\(channel.name): \(error.localizedDescription)"
                            }
                        }
                    }
                }

                Button("Channel Info") {
                    channelForInfo = channel
                }

                Button("Cancel", role: .cancel) { }
            }
        }
    }
}

// MARK: - Top bar
extension CommunityDetailView {
    private var topBar: some View {
        HStack(spacing: DS.Spacing.m) {
            IconButton(systemName: "chevron.left", accessibilityLabel: "Back") {
                dismiss()
            }

            Spacer()

            Menu {
                Button(action: { showMembersList = true }) {
                    Label("View Members", systemImage: "person.2")
                }
                Button(action: { showLeaderboard = true }) {
                    Label("Leaderboard", systemImage: "trophy")
                }
                if viewModel.isUserMember {
                    Button(action: { showCommunitySettings = true }) {
                        Label(isOwner ? "Community Settings" : "Rules & Info", systemImage: isOwner ? "gearshape" : "doc.text")
                    }
                    if viewModel.canManageChannels {
                        Button(action: { showCreateChannel = true }) {
                            Label("New Channel", systemImage: "plus.bubble")
                        }
                    }
                    if !isOwner {
                        Divider()
                        Button(role: .destructive, action: { showLeaveConfirmation = true }) {
                            Label("Leave Community", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.surfaceRaised))
            }
            .accessibilityLabel("More options")
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.vertical, DS.Spacing.s)
    }
}

// MARK: - Hero
extension CommunityDetailView {
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let urlString = current.bannerURL, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        CommunityPalette.color(for: current.name).opacity(0.18)
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipped()
            }

            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                heroIdentity
                if !current.description.isEmpty {
                    Text(current.description)
                        .font(.subheadline)
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                heroTags
                heroActions
            }
            .padding(DS.Spacing.l)
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous).fill(Color.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
    }

    private var heroIdentity: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            CommunityAvatar(community: current, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(current.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(CommunityFormat.summary(current))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var heroTags: some View {
        HStack(spacing: DS.Spacing.s) {
            if viewModel.isUserMember {
                Tag(text: viewModel.userRole.capitalized, systemImage: roleIcon, tint: roleTint)
            }
            if current.isPrivate {
                Tag(text: "Private", systemImage: "lock.fill", tint: .secondary)
            }
            if current.isRecentlyActive {
                Tag(text: current.lastActivityText, systemImage: "circle.fill", tint: .marketGreen)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var heroActions: some View {
        if !viewModel.isUserMember {
            Button {
                HapticManager.shared.notification(type: .success)
                viewModel.joinCommunity()
            } label: {
                Label("Join community", systemImage: "person.badge.plus")
            }
            .buttonStyle(PrimaryButtonStyle())
        } else if isOwner {
            Button {
                showCommunitySettings = true
            } label: {
                Label("Manage community", systemImage: "gearshape")
            }
            .buttonStyle(SecondaryButtonStyle())
        } else {
            HStack(spacing: DS.Spacing.s) {
                Button {
                    showCommunitySettings = true
                } label: {
                    Label("Rules & info", systemImage: "doc.text")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    showLeaveConfirmation = true
                } label: {
                    Text("Leave")
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: false))
            }
        }

        if viewModel.isUserMember, let joined = viewModel.memberSince {
            Text("Member since \(joined.formatted(.dateTime.month(.wide).year()))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var roleIcon: String {
        switch viewModel.userRole {
        case "owner": return "crown.fill"
        case "admin": return "star.fill"
        case "moderator": return "shield.fill"
        default: return "person.fill"
        }
    }

    private var roleTint: Color {
        switch viewModel.userRole {
        case "owner": return .goldText
        case "admin": return .orange
        case "moderator": return .blue
        default: return .secondary
        }
    }
}

// MARK: - Shortcuts (members, leaderboard)
extension CommunityDetailView {
    private var shortcuts: some View {
        HStack(spacing: DS.Spacing.m) {
            shortcutTile(
                icon: "person.2.fill",
                value: current.memberCount.formatted(),
                label: current.memberCount == 1 ? "Member" : "Members",
                accessibility: "View members"
            ) {
                showMembersList = true
            }

            shortcutTile(
                icon: "trophy.fill",
                value: "Leaderboard",
                label: "See rankings",
                accessibility: "Open the community leaderboard"
            ) {
                showLeaderboard = true
            }
        }
    }

    private func shortcutTile(
        icon: String,
        value: String,
        label: String,
        accessibility: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                HStack {
                    IconWell(systemName: icon, size: 36)
                    Spacer()
                    CommunityChevron()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .arkadNumber(17)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 14, radius: DS.Radius.l)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(accessibility)
    }
}

// MARK: - Channels
extension CommunityDetailView {
    private var channelsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(
                title: "Channels",
                count: viewModel.isLoading ? nil : viewModel.channels.count,
                actionTitle: viewModel.canManageChannels ? "New channel" : nil,
                action: { showCreateChannel = true }
            )

            if viewModel.isLoading && viewModel.channels.isEmpty {
                channelPlaceholders
            } else if viewModel.channels.isEmpty {
                emptyChannelsView
            } else {
                ForEach(channelGroups) { group in
                    channelGroupView(type: group.type, channels: group.channels)
                }
            }
        }
    }

    /// Text channels first, then callouts. Legacy voice channels have no voice feature, so they're listed as text.
    private var channelGroups: [ChannelGroup] {
        let grouped = Dictionary(grouping: viewModel.channels) { (channel: Channel) -> ChannelType in
            channel.type == .voice ? .text : channel.type
        }
        var groups: [ChannelGroup] = []
        for type in [ChannelType.text, .callouts] {
            if let channels = grouped[type], !channels.isEmpty {
                groups.append(ChannelGroup(type: type, channels: channels))
            }
        }
        return groups
    }

    /// Runs the default-channel setup; nil when the viewer can't manage channels
    private var setupDefaultChannelsAction: (() -> Void)? {
        guard viewModel.canManageChannels else { return nil }
        return {
            Task { await viewModel.setupDefaultChannels() }
        }
    }

    private var channelPlaceholders: some View {
        let placeholders = [Channel(name: "general", type: .text, communityId: ""),
                            Channel(name: "callouts", type: .callouts, communityId: "")]
        return CommunityCardList(items: placeholders, dividerInset: 64) { channel in
            EnhancedChannelRow(channel: channel, canManage: false, onOptionsPress: {})
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }

    private var emptyChannelsView: some View {
        VStack(spacing: 0) {
            EmptyStateView(
                systemImage: "bubble.left.and.bubble.right.fill",
                title: "No channels yet",
                message: viewModel.canManageChannels
                    ? "Set up #general for chat and #callouts for trade ideas, or make your own."
                    : "The owner hasn't set up any channels yet.",
                actionTitle: viewModel.canManageChannels ? "Create default channels" : nil,
                action: setupDefaultChannelsAction
            )

            if viewModel.canManageChannels {
                Button("Create a custom channel") {
                    showCreateChannel = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.goldText)
                .padding(.top, -DS.Spacing.l)
                .padding(.bottom, DS.Spacing.xl)
            }
        }
        .cardStyle(padding: 0)
    }

    private func channelGroupView(type: ChannelType, channels: [Channel]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(type == .callouts ? "Callouts" : "Text channels")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, DS.Spacing.xs)

            CommunityCardList(items: channels.sorted { $0.name < $1.name }, dividerInset: 64) { channel in
                NavigationLink(destination: ChannelChatView(community: current, channel: channel)) {
                    EnhancedChannelRow(channel: channel, canManage: viewModel.canManageChannels) {
                        selectedChannel = channel
                        showChannelOptions = true
                    }
                }
                .buttonStyle(PressableStyle())
                .contextMenu {
                    Button {
                        channelForInfo = channel
                    } label: {
                        Label("Channel Info", systemImage: "info.circle")
                    }
                    if viewModel.canManageChannels && !channel.isDefault {
                        Button {
                            channelToEdit = channel
                        } label: {
                            Label("Edit Channel", systemImage: "pencil")
                        }
                    }
                }
            }
        }
    }
}

/// Channels of one type, shown together in the channel list
private struct ChannelGroup: Identifiable {
    let type: ChannelType
    let channels: [Channel]
    var id: String { type.rawValue }
}
