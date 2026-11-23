// File: Core/Communities/Views/Main/CommunitiesView+Discover.swift
// The Discover tab: search, category chips, popular communities and a section per trading style.

import SwiftUI

// MARK: - Discover Content
extension CommunitiesView {
    @ViewBuilder
    var discoverContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            searchBar
            categoryChips
        }

        if viewModel.discoveryCommunities.isEmpty {
            if viewModel.isLoading {
                loadingCard(text: "Finding communities…")
            } else {
                emptyDiscoverState
            }
        } else if !viewModel.searchQuery.isEmpty {
            searchResultsSection
        } else if let category = viewModel.selectedCategory {
            categoryResultsSection(category)
        } else {
            if !popularCommunities.isEmpty {
                featuredCommunitiesSection
            }
            communityTypesSections
        }
    }

    /// Popular communities (most members, boosted by recent activity), excluding private ones you can't see
    var popularCommunities: [Community] {
        viewModel.featuredCommunities.filter { !$0.isPrivate || viewModel.isUserMember(of: $0) }
    }

    // MARK: - Search Results
    var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Results", count: viewModel.discoveryCommunities.count)
            discoveryList(viewModel.discoveryCommunities)
        }
    }

    // MARK: - Single Category
    func categoryResultsSection(_ category: CommunityType) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: category.displayName, count: viewModel.discoveryCommunities.count)
            discoveryList(viewModel.discoveryCommunities)
        }
    }

    // MARK: - Popular carousel
    var featuredCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                SectionHeader(title: "Popular")
                Text("The biggest and most active communities on Arkad")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.m) {
                    ForEach(popularCommunities) { community in
                        EnhancedCommunityCard(
                            community: community,
                            isUserMember: viewModel.isUserMember(of: community),
                            onTap: { navigateToCommunitDetail(community) },
                            onJoin: { join(community) },
                            onInfo: { showCommunityPreview(community) }
                        )
                    }
                }
                .padding(.horizontal, DS.pageMargin)
            }
            .padding(.horizontal, -DS.pageMargin)
        }
    }

    // MARK: - Community Types Sections
    var communityTypesSections: some View {
        ForEach(viewModel.allCommunityTypesInOrder, id: \.self) { type in
            communityTypeSection(for: type)
        }
    }

    @ViewBuilder
    func communityTypeSection(for type: CommunityType) -> some View {
        let communities = viewModel.communitiesForType(type)
        if !communities.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                SectionHeader(
                    title: viewModel.sectionTitle(for: type),
                    count: communities.count,
                    actionTitle: communities.count > Self.typeSectionLimit ? "See all" : nil,
                    action: { selectCategory(type) }
                )
                discoveryList(Array(communities.prefix(Self.typeSectionLimit)))
            }
        }
    }

    /// How many communities each type section shows before "See all"
    static var typeSectionLimit: Int { 4 }

    // MARK: - Rows
    func discoveryList(_ communities: [Community]) -> some View {
        CommunityCardList(items: communities) { community in
            discoveryRow(community)
        }
    }

    func discoveryRow(_ community: Community) -> some View {
        let isMember = viewModel.isUserMember(of: community)
        return HStack(spacing: 0) {
            Button {
                navigateToCommunitDetail(community)
            } label: {
                CommunityRowContent(community: community) { EmptyView() }
            }
            .buttonStyle(PressableStyle())

            Group {
                if isMember {
                    JoinedTag()
                } else if community.requiresSubscription {
                    Button("View") { join(community) }
                        .buttonStyle(PillButtonStyle(kind: .gold))
                        .accessibilityLabel("View \(community.name)")
                } else {
                    Button("Join") { join(community) }
                        .buttonStyle(PillButtonStyle(kind: .gold))
                        .accessibilityLabel("Join \(community.name)")
                }
            }
            .padding(.trailing, DS.Spacing.l)
        }
        .contextMenu {
            Button {
                showCommunityPreview(community)
            } label: {
                Label("Quick Look", systemImage: "info.circle")
            }
            if !isMember && !community.requiresSubscription {
                Button {
                    join(community)
                } label: {
                    Label("Join", systemImage: "person.badge.plus")
                }
            }
        }
    }

    // MARK: - Empty State
    var emptyDiscoverState: some View {
        Group {
            if !viewModel.searchQuery.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No matches",
                    message: "No communities match \"\(viewModel.searchQuery)\". Try another name or clear your filters."
                )
            } else if hasActiveFilters {
                EmptyStateView(
                    systemImage: "line.3.horizontal.decrease",
                    title: "Nothing with these filters",
                    message: "Try a different category or fewer filters.",
                    actionTitle: "Clear filters",
                    action: clearFilters
                )
            } else {
                EmptyStateView(
                    systemImage: "person.3.fill",
                    title: "No communities yet",
                    message: "Be the first to start one. Invite traders, post callouts and run a leaderboard.",
                    actionTitle: "Create a community",
                    action: showCreate
                )
            }
        }
        .cardStyle(padding: 0)
    }

    // MARK: - Helper Methods
    func getSectionColor(for type: CommunityType) -> Color {
        type.tint
    }

    func showCommunityPreview(_ community: Community) {
        selectedCommunityForPreview = community
        showCommunityPreview = true
    }

    /// Free communities are joined right away; paid ones open the preview, which has the Subscribe button.
    func join(_ community: Community) {
        if community.requiresSubscription {
            showCommunityPreview(community)
            return
        }
        viewModel.joinCommunity(community)
        HapticManager.shared.notification(type: .success)
    }

    func selectCategory(_ category: CommunityType?) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.snappy(duration: 0.25)) {
            viewModel.selectedCategory = category
        }
    }

    func clearFilters() {
        viewModel.selectedCategory = nil
        viewModel.minimumMemberCount = 0
        viewModel.sortType = .memberCount
        Task { await viewModel.loadDiscoveryCommunities() }
    }
}

// MARK: - Search Bar, Filter and Category Chips
extension CommunitiesView {
    var searchBar: some View {
        HStack(spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("Search communities", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task {
                            await viewModel.searchCommunities(query: viewModel.searchQuery)
                        }
                    }

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                        Task { await viewModel.loadDiscoveryCommunities() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Capsule().fill(Color.surfaceRaised))

            filterButton
        }
    }

    private var filterButton: some View {
        IconButton(systemName: "slider.horizontal.3", accessibilityLabel: "Sort and filter", size: 44) {
            showFilterSheet = true
        }
        .overlay(alignment: .topTrailing) {
            if hasActiveFilters {
                Circle()
                    .fill(Color.arkadGold)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(Color.appBackground, lineWidth: 2))
                    .accessibilityHidden(true)
            }
        }
    }

    var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s) {
                Chip(title: "All", isSelected: viewModel.selectedCategory == nil) {
                    selectCategory(nil)
                }
                ForEach(viewModel.allCommunityTypesInOrder, id: \.self) { type in
                    Chip(
                        title: type.shortDisplayName,
                        systemImage: viewModel.sectionIcon(for: type),
                        isSelected: viewModel.selectedCategory == type
                    ) {
                        selectCategory(viewModel.selectedCategory == type ? nil : type)
                    }
                }
            }
            .padding(.horizontal, DS.pageMargin)
        }
        .padding(.horizontal, -DS.pageMargin)
    }

    // Check if any filters are active
    var hasActiveFilters: Bool {
        viewModel.selectedCategory != nil ||
        viewModel.minimumMemberCount > 0 ||
        viewModel.sortType != .memberCount
    }
}
