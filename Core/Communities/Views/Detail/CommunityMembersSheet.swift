// File: Core/Communities/Views/Detail/CommunityMembersSheet.swift
// Community member list sheet, its rows and view model.

import SwiftUI

// MARK: - Role tag

/// Small tag showing a member's role; plain members get no tag.
struct CommunityRoleTag: View {
    let role: CommunityRole

    var body: some View {
        if role != .member {
            Tag(text: role.displayName, systemImage: role.icon, tint: role.color)
        }
    }
}

// MARK: - Enhanced Members List Sheet
struct EnhancedMembersListSheet: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MembersListViewModel()
    @State private var searchText = ""
    @State private var reportTarget: ReportTarget?
    @State private var pendingAction: PendingAction?

    /// Remove and ban ask for confirmation first
    private struct PendingAction: Identifiable {
        enum Kind { case remove, ban }
        let kind: Kind
        let member: CommunityMemberWithRole
        var id: String { "\(kind)_\(member.id)" }
    }

    private var currentUserId: String? { FirebaseAuthService.shared.currentUser?.id }

    /// The viewer's own role here
    private var viewerRole: CommunityRole {
        guard let currentUserId else { return .member }
        if community.createdBy == currentUserId { return .owner }
        return viewModel.members.first { $0.userId == currentUserId }?.role ?? .member
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(.horizontal, DS.pageMargin)
                    .padding(.vertical, DS.Spacing.m)
            }
            .scrollDismissesKeyboard(.immediately)
            .screenBackground()
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search members"
            )
            .refreshable { await viewModel.loadMembers(for: community) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color.goldText)
                }
            }
            .sheet(item: $reportTarget) { target in
                ReportSheet(target: target)
            }
            .confirmationDialog(
                pendingTitle,
                isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }),
                titleVisibility: .visible,
                presenting: pendingAction
            ) { action in
                switch action.kind {
                case .remove:
                    Button("Remove", role: .destructive) {
                        Task { await viewModel.remove(action.member, from: community) }
                    }
                case .ban:
                    Button("Ban", role: .destructive) {
                        Task { await viewModel.ban(action.member, from: community) }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: { action in
                switch action.kind {
                case .remove:
                    Text("\(action.member.displayName) leaves \(community.name) and can join again.")
                case .ban:
                    Text("\(action.member.displayName) is removed from \(community.name) and can't rejoin.")
                }
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(get: { viewModel.actionError != nil }, set: { if !$0 { viewModel.actionError = nil } })
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.actionError ?? "")
            }
        }
        .onAppear {
            if viewModel.members.isEmpty {
                Task {
                    await viewModel.loadMembers(for: community)
                }
            }
        }
    }

    private var pendingTitle: String {
        guard let pendingAction else { return "" }
        switch pendingAction.kind {
        case .remove: return "Remove \(pendingAction.member.displayName)?"
        case .ban: return "Ban \(pendingAction.member.displayName)?"
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.members.isEmpty {
            HStack(spacing: DS.Spacing.m) {
                ProgressView()
                Text("Loading members…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else if !viewModel.errorMessage.isEmpty && viewModel.members.isEmpty {
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't load members",
                message: viewModel.errorMessage,
                actionTitle: "Try again",
                action: { Task { await viewModel.loadMembers(for: community) } }
            )
            .cardStyle(padding: 0)
        } else if filteredMembers.isEmpty {
            EmptyStateView(
                systemImage: "person.2",
                title: searchText.isEmpty ? "No members yet" : "No members found",
                message: searchText.isEmpty
                    ? "Members of \(community.name) will show up here."
                    : "No one matches \"\(searchText)\"."
            )
            .cardStyle(padding: 0)
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                Text(CommunityFormat.members(viewModel.members.count))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, DS.Spacing.xs)

                CommunityCardList(items: filteredMembers, dividerInset: 72) { member in
                    MembersListRow(
                        member: member,
                        community: community,
                        mutedUntil: viewModel.activeMute(for: member.userId),
                        isWorking: viewModel.workingIds.contains(member.userId)
                    ) {
                        memberMenu(for: member)
                    }
                }
            }
        }
    }

    /// Report for anyone else; mute, remove and ban for members the viewer outranks
    @ViewBuilder
    private func memberMenu(for member: CommunityMemberWithRole) -> some View {
        if member.userId != currentUserId {
            Button {
                reportTarget = .user(id: member.userId)
            } label: {
                Label("Report", systemImage: "flag")
            }

            if canModerate(member) {
                Divider()

                if viewModel.activeMute(for: member.userId) != nil {
                    Button {
                        Task { await viewModel.setMute(for: member, in: community, duration: nil) }
                    } label: {
                        Label("Unmute", systemImage: "speaker.wave.2")
                    }
                } else {
                    Menu {
                        ForEach(MuteDuration.allCases) { duration in
                            Button(duration.title) {
                                Task { await viewModel.setMute(for: member, in: community, duration: duration) }
                            }
                        }
                    } label: {
                        Label("Mute", systemImage: "speaker.slash")
                    }
                }

                Button(role: .destructive) {
                    pendingAction = PendingAction(kind: .remove, member: member)
                } label: {
                    Label("Remove from community", systemImage: "person.badge.minus")
                }

                Button(role: .destructive) {
                    pendingAction = PendingAction(kind: .ban, member: member)
                } label: {
                    Label("Ban", systemImage: "nosign")
                }
            }
        }
    }

    private func canModerate(_ member: CommunityMemberWithRole) -> Bool {
        guard member.userId != currentUserId, member.userId != community.createdBy else { return false }
        let role = viewerRole
        guard role == .owner || role == .admin || role == .moderator else { return false }
        return role.canManage(member.role)
    }

    private var filteredMembers: [CommunityMemberWithRole] {
        let base = searchText.isEmpty ? viewModel.members : viewModel.members.filter { member in
            member.fullName.localizedCaseInsensitiveContains(searchText) ||
            member.username.localizedCaseInsensitiveContains(searchText)
        }
        return base.sorted { member1, member2 in
            // Role first (owner, admin, moderator, member), then name
            if member1.role != member2.role {
                return member1.role.hierarchyLevel > member2.role.hierarchyLevel
            }
            return member1.fullName < member2.fullName
        }
    }
}

// MARK: - Mute durations
enum MuteDuration: CaseIterable, Identifiable {
    case oneHour, oneDay, oneWeek

    var id: Self { self }

    var title: String {
        switch self {
        case .oneHour: return "For 1 hour"
        case .oneDay: return "For 24 hours"
        case .oneWeek: return "For 7 days"
        }
    }

    var interval: TimeInterval {
        switch self {
        case .oneHour: return 3600
        case .oneDay: return 24 * 3600
        case .oneWeek: return 7 * 24 * 3600
        }
    }
}

// MARK: - Members List Row Component
struct MembersListRow<MenuItems: View>: View {
    let member: CommunityMemberWithRole
    let community: Community
    var mutedUntil: Date? = nil
    var isWorking = false
    @ViewBuilder var menuItems: () -> MenuItems

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            UserAvatar(username: member.username.isEmpty ? member.displayName : member.username,
                       imageURL: member.profileImageUrl,
                       size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(member.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    if member.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color.goldText)
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let mutedUntil {
                    Label("Muted until \(mutedUntil.formatted(date: .abbreviated, time: .shortened))", systemImage: "speaker.slash.fill")
                        .font(.caption)
                        .foregroundStyle(Color.marketRed)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: DS.Spacing.s)

            CommunityRoleTag(role: member.role)

            if isWorking {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 32, height: 32)
            } else {
                Menu {
                    menuItems()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Options for \(member.displayName)")
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .accessibilityElement(children: .contain)
    }

    private var subtitle: String {
        let joined = "Joined \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))"
        return member.username.isEmpty ? joined : "@\(member.username) · \(joined)"
    }
}

extension MembersListRow where MenuItems == EmptyView {
    /// A row with no options menu
    init(member: CommunityMemberWithRole, community: Community) {
        self.init(member: member, community: community, menuItems: { EmptyView() })
    }
}

// MARK: - Members List ViewModel
@MainActor
final class MembersListViewModel: ObservableObject {
    @Published var members: [CommunityMemberWithRole] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    /// Mute end times, keyed by user id
    @Published var mutedUntil: [String: Date] = [:]
    /// Members with a moderation action in flight
    @Published var workingIds: Set<String> = []
    @Published var actionError: String?

    func loadMembers(for community: Community) async {
        isLoading = true
        errorMessage = ""

        do {
            members = try await CommunityFirebaseService.shared.getCommunityMembersWithRoles(communityId: community.id)
            // Mutes are extra; the list still shows if they can't be read
            mutedUntil = (try? await FirebaseServices.shared.getMutedMembers(communityId: community.id)) ?? [:]
        } catch {
            errorMessage = "Failed to load members: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func activeMute(for userId: String) -> Date? {
        guard let until = mutedUntil[userId], until > Date() else { return nil }
        return until
    }

    /// Mutes for `duration`, or unmutes when it's nil
    func setMute(for member: CommunityMemberWithRole, in community: Community, duration: MuteDuration?) async {
        let until = duration.map { Date().addingTimeInterval($0.interval) }
        await perform(on: member, failure: "Couldn't update the mute. Try again.") {
            try await FirebaseServices.shared.setMemberMute(communityId: community.id, userId: member.userId, until: until)
            self.mutedUntil[member.userId] = until
        }
    }

    func remove(_ member: CommunityMemberWithRole, from community: Community) async {
        await perform(on: member, failure: "Couldn't remove \(member.displayName). Try again.") {
            try await FirebaseServices.shared.removeMember(communityId: community.id, userId: member.userId)
            self.members.removeAll { $0.userId == member.userId }
        }
    }

    func ban(_ member: CommunityMemberWithRole, from community: Community) async {
        guard let currentUserId = FirebaseAuthService.shared.currentUser?.id else { return }
        await perform(on: member, failure: "Couldn't ban \(member.displayName). Try again.") {
            try await FirebaseServices.shared.banMember(
                communityId: community.id, userId: member.userId, bannedBy: currentUserId
            )
            self.members.removeAll { $0.userId == member.userId }
        }
    }

    private func perform(on member: CommunityMemberWithRole, failure: String, _ work: @MainActor () async throws -> Void) async {
        workingIds.insert(member.userId)
        do {
            try await work()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            actionError = failure
        }
        workingIds.remove(member.userId)
    }
}

// MARK: - Member Row Component (settings sheet)
struct MemberRow: View {
    let member: CommunityMemberWithRole
    let isOwner: Bool
    let onRoleChange: (CommunityRole) -> Void
    let onRemove: () -> Void

    private var assignableRoles: [CommunityRole] {
        [.admin, .moderator, .member].filter { $0 != member.role }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            UserAvatar(username: member.username.isEmpty ? member.displayName : member.username,
                       imageURL: member.profileImageUrl,
                       size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                if !member.username.isEmpty {
                    Text("@\(member.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: DS.Spacing.s)

            CommunityRoleTag(role: member.role)

            // Actions (owner managing anyone but themselves)
            if member.role != .owner && isOwner {
                Menu {
                    ForEach(assignableRoles, id: \.self) { role in
                        Button {
                            onRoleChange(role)
                        } label: {
                            Label("Make \(role.displayName)", systemImage: role.icon)
                        }
                    }

                    Divider()

                    Button(role: .destructive, action: onRemove) {
                        Label("Remove Member", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.surfaceRaised))
                }
                .accessibilityLabel("Manage \(member.displayName)")
            }
        }
        .padding(.vertical, 2)
    }
}
