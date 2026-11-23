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
        }
        .onAppear {
            if viewModel.members.isEmpty {
                Task {
                    await viewModel.loadMembers(for: community)
                }
            }
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
                    MembersListRow(member: member, community: community)
                }
            }
        }
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

// MARK: - Members List Row Component
struct MembersListRow: View {
    let member: CommunityMemberWithRole
    let community: Community

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
            }

            Spacer(minLength: DS.Spacing.s)

            CommunityRoleTag(role: member.role)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let joined = "Joined \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))"
        return member.username.isEmpty ? joined : "@\(member.username) · \(joined)"
    }
}

// MARK: - Members List ViewModel
class MembersListViewModel: ObservableObject {
    @Published var members: [CommunityMemberWithRole] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    func loadMembers(for community: Community) async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }

        do {
            let loadedMembers = try await CommunityFirebaseService.shared.getCommunityMembersWithRoles(communityId: community.id)

            await MainActor.run {
                self.members = loadedMembers
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load members: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
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
