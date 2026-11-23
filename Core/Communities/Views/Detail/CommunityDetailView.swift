// File: Core/Communities/Views/Detail/CommunityDetailView.swift
// A community's home page: hero header with the join / subscribe / manage action, then a section
// switcher: Chat (shortcuts to members and the leaderboard, and the channel list), Classroom
// (courses), Events (live sessions) and About (the landing page: leader's track record, what's
// inside, recent results). Non-members of a paid community see a preview instead: price, trial,
// the owner's track record and the rules.

import SwiftUI

struct CommunityDetailView: View {
    let community: Community
    /// A channel to open once loaded (from a notification), and the message to show in it
    var initialChannelId: String? = nil
    var initialMessageId: String? = nil
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
    @State private var showDashboard = false
    @State private var showReport = false
    @State private var showWelcome = false
    @State private var showJoinWithCode = false
    @State private var didLoad = false
    @State private var didDeleteCommunity = false
    /// The open channel, and the message to scroll to in it
    @State private var openChannel: Channel?
    @State private var openMessageId: String?
    @StateObject private var subscription = CommunitySubscriptionController()

    // Sections
    @State private var section: CommunitySection = .chat
    /// Set once the viewer picks a section, so loading never overrides their choice
    @State private var didPickSection = false
    @State private var aboutReloadToken = 0
    @StateObject private var classroom = ClassroomViewModel()
    @StateObject private var events = EventsViewModel()

    /// Latest copy of the community (refreshed after settings change), falling back to the one passed in.
    private var current: Community { viewModel.community ?? community }

    private var isOwner: Bool { viewModel.userRole == "owner" }

    /// A paid community the viewer hasn't subscribed to: preview only
    private var showsPaidPreview: Bool {
        current.requiresSubscription && !viewModel.isUserMember && !viewModel.isLoading
    }

    /// Members with a Stripe subscription manage it (and cancel) in the billing portal instead of leaving
    private var hasSubscription: Bool {
        viewModel.isUserMember && !isOwner && viewModel.subscription != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    heroCard
                    if viewModel.isLockedPrivate {
                        privateLockedCard
                    } else if showsPaidPreview {
                        paidPreview
                    } else {
                        CommunitySectionBar(selection: sectionBinding)
                        sectionContent
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .refreshable {
                await viewModel.refreshAfterSubscriptionChange()
                await refreshCurrentSection()
            }
            .alert(
                "Couldn't subscribe",
                isPresented: Binding(get: { subscription.errorMessage != nil }, set: { if !$0 { subscription.errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(subscription.errorMessage ?? "")
            }
            .alert(
                "Almost there",
                isPresented: Binding(get: { subscription.pendingMessage != nil }, set: { if !$0 { subscription.pendingMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(subscription.pendingMessage ?? "")
            }
            .alert("Welcome to \(current.name)", isPresented: $showWelcome) {
                Button("Let's go") { subscription.acknowledgeJoined() }
            } message: {
                Text("You're in. Channels and callouts are open to you now.")
            }
        }
        .screenBackground()
        .navigationBarHidden(true)
        .task {
            guard !didLoad else { return }
            didLoad = true
            await viewModel.loadCommunityData(community: community)
            await openInitialChannel()
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            // People who haven't joined land on About, the community's pitch
            if !isLoading && !viewModel.isUserMember && !didPickSection {
                section = .about
            }
        }
        .sheet(isPresented: $showMembersList) {
            EnhancedMembersListSheet(community: current, viewerRole: CommunityRole(rawValue: viewModel.userRole))
        }
        .sheet(isPresented: $showCommunitySettings, onDismiss: {
            if didDeleteCommunity {
                dismiss()
            } else {
                Task { await viewModel.reloadCommunity() }
            }
        }) {
            EnhancedCommunitySettingsSheet(community: current, onDeleted: { didDeleteCommunity = true })
        }
        .sheet(isPresented: $showCreateChannel, onDismiss: {
            Task { await viewModel.reloadChannels() }
        }) {
            CreateChannelSheet(community: current, existingChannels: viewModel.channels)
        }
        .sheet(item: $channelToEdit, onDismiss: {
            Task { await viewModel.reloadChannels() }
        }) { channel in
            CreateChannelSheet(community: current, editing: channel, existingChannels: viewModel.channels)
        }
        .sheet(isPresented: $showJoinWithCode) {
            JoinWithInviteCodeSheet(join: { code in
                try await viewModel.joinWithInviteCode(code)
                return current
            })
        }
        .navigationDestination(isPresented: Binding(
            get: { openChannel != nil },
            set: { if !$0 { openChannel = nil; openMessageId = nil } }
        )) {
            if let channel = openChannel {
                ChannelChatView(
                    community: current,
                    channel: channel,
                    isMember: viewModel.isUserMember,
                    initialMessageId: openMessageId
                )
            }
        }
        .sheet(item: $channelForInfo) { channel in
            ChannelInfoSheet(community: current, channel: channel)
                .presentationDetents([.medium])
        }
        .navigationDestination(isPresented: $showLeaderboard) {
            CommunityLeaderboardView(community: current)
        }
        .navigationDestination(isPresented: $showDashboard) {
            CommunityDashboardView(community: current)
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(target: .community(id: current.id, ownerId: current.createdBy))
        }
        .onChange(of: subscription.phase) { _, phase in
            if phase == .joined {
                HapticManager.shared.notification(type: .success)
                showWelcome = true
                Task { await viewModel.refreshAfterSubscriptionChange() }
            }
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
                if !showsPaidPreview && !viewModel.isLockedPrivate {
                    Button(action: { showMembersList = true }) {
                        Label("View Members", systemImage: "person.2")
                    }
                    Button(action: { showLeaderboard = true }) {
                        Label("Leaderboard", systemImage: "trophy")
                    }
                }
                if isOwner {
                    Button(action: { showDashboard = true }) {
                        Label("Dashboard", systemImage: "chart.bar.xaxis")
                    }
                }
                if hasSubscription {
                    Button(action: manageSubscription) {
                        Label("Manage subscription", systemImage: "creditcard")
                    }
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
                    if !isOwner && !hasSubscription {
                        Divider()
                        Button(role: .destructive, action: { showLeaveConfirmation = true }) {
                            Label("Leave Community", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                if current.createdBy != viewModel.currentUserId {
                    Divider()
                    Button(role: .destructive, action: { showReport = true }) {
                        Label("Report community", systemImage: "flag")
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
            if let urlString = current.bannerURL, !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ArkadAsyncImage(urlString: urlString) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    CommunityPalette.color(for: current.name).opacity(0.18)
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
            CommunityPriceTag(community: current)
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
            if viewModel.isBanned {
                Text(CommunityJoinError.banned.errorDescription ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(Color.surfaceRaised))
            } else if current.requiresSubscription {
                CommunitySubscribeButton(community: current, controller: subscription)
                    .disabled(viewModel.isLoading)
            } else if current.isPrivate {
                Button {
                    showJoinWithCode = true
                } label: {
                    Label("Join with invite code", systemImage: "ticket")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {
                    viewModel.joinCommunity()
                } label: {
                    if viewModel.isJoining {
                        ProgressView()
                    } else {
                        Label("Join free", systemImage: "person.badge.plus")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isJoining || viewModel.isLoading)
            }
        } else if isOwner {
            HStack(spacing: DS.Spacing.s) {
                Button {
                    showDashboard = true
                } label: {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    showCommunitySettings = true
                } label: {
                    Label("Manage", systemImage: "gearshape")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        } else {
            HStack(spacing: DS.Spacing.s) {
                Button {
                    showCommunitySettings = true
                } label: {
                    Label("Rules & info", systemImage: "doc.text")
                }
                .buttonStyle(SecondaryButtonStyle())

                if hasSubscription {
                    Button(action: manageSubscription) {
                        if subscription.isOpeningPortal {
                            ProgressView()
                        } else {
                            Text("Manage subscription")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                    .disabled(subscription.isOpeningPortal)
                } else {
                    Button {
                        showLeaveConfirmation = true
                    } label: {
                        Text("Leave")
                    }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                }
            }
        }

        if viewModel.isUserMember, let plan = viewModel.subscription, !isOwner {
            Text(plan.summary)
                .font(.caption)
                .foregroundStyle(plan.status == .pastDue ? Color.marketRed : .secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        } else if viewModel.isUserMember, let joined = viewModel.memberSince {
            Text("Member since \(joined.formatted(.dateTime.month(.wide).year()))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func manageSubscription() {
        Task {
            await subscription.manageSubscription()
            await viewModel.refreshAfterSubscriptionChange()
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

// MARK: - Private (non-members)
extension CommunityDetailView {
    private var privateLockedCard: some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: "lock.fill", tint: .secondary, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("This community is private")
                    .font(.subheadline.weight(.semibold))
                Text("Only members can see its channels. If someone sent you an invite code, you can join with it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    /// Opens the channel a notification pointed at, at its message
    private func openInitialChannel() async {
        guard let channelId = initialChannelId, viewModel.canViewChannels,
              let channel = await viewModel.channel(withId: channelId) else { return }
        section = .chat
        didPickSection = true
        openMessageId = initialMessageId
        openChannel = channel
    }
}

// MARK: - Paid preview (non-members)
extension CommunityDetailView {
    private var paidPreview: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            CommunityPriceSummary(community: current)

            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                SectionHeader(title: "The owner")
                TrackRecordCard(userId: current.createdBy)
            }

            if !viewModel.rules.isEmpty {
                CommunityRulesList(rules: viewModel.rules)
            }

            HStack(spacing: DS.Spacing.m) {
                IconWell(systemName: "lock.fill", tint: .secondary, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Channels are for subscribers")
                        .font(.subheadline.weight(.semibold))
                    Text("Subscribe to read and post in this community's channels and callouts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .cardStyle()
        }
    }
}

// MARK: - Sections
extension CommunityDetailView {
    private var sectionBinding: Binding<CommunitySection> {
        Binding(
            get: { section },
            set: { newValue in
                didPickSection = true
                section = newValue
            }
        )
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .chat:
            shortcuts
            channelsSection
        case .classroom:
            ClassroomSectionView(community: current, viewModel: classroom, isStaff: viewModel.isStaff)
        case .events:
            EventsSectionView(
                community: current,
                viewModel: events,
                isStaff: viewModel.isStaff,
                canRSVP: viewModel.isUserMember
            )
        case .about:
            CommunityAboutView(community: current, reloadToken: aboutReloadToken)
        }
    }

    /// Pull to refresh reloads the section on screen.
    private func refreshCurrentSection() async {
        switch section {
        case .chat:
            break // the channels reload with the community
        case .classroom:
            await classroom.reload()
        case .events:
            await events.reload()
        case .about:
            aboutReloadToken += 1
        }
    }
}

/// The parts of a community, picked with the bar under the header.
enum CommunitySection: String, CaseIterable, Identifiable {
    case chat, classroom, events, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .classroom: return "Classroom"
        case .events: return "Events"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .classroom: return "graduationcap.fill"
        case .events: return "calendar"
        case .about: return "info.circle.fill"
        }
    }
}

/// Capsule section switcher in the style of the app's SegmentedPicker, with text that
/// shrinks a little rather than truncating "Classroom" on small phones.
private struct CommunitySectionBar: View {
    @Binding var selection: CommunitySection
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CommunitySection.allCases) { option in
                let isSelected = option == selection
                Button {
                    guard option != selection else { return }
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.snappy(duration: 0.25)) { selection = option }
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.inverseText : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.inverseFill)
                                    .matchedGeometryEffect(id: "community-section", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.surfaceRaised))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Community sections")
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

            CommunityCardList(items: channels, dividerInset: 64) { channel in
                Button {
                    openMessageId = nil
                    openChannel = channel
                } label: {
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
