// File: Core/Communities/Views/Main/CommunitiesView+Discover.swift
// The Discover tab: search, featured communities and type sections.

import SwiftUI

// MARK: - Discover Content
extension CommunitiesView {
    var discoverContent: some View {
        VStack(spacing: 28) {
            searchBar

            if viewModel.discoveryCommunities.isEmpty && !viewModel.isLoading {
                emptyDiscoverState
            } else if !viewModel.searchQuery.isEmpty {
                searchResultsSection
            } else {
                VStack(spacing: 36) {
                    if !viewModel.featuredCommunities.isEmpty && viewModel.selectedCategory == nil {
                        featuredCommunitiesSection
                    }
                    communityTypesSections
                }
            }
        }
    }

    // MARK: - Search Results
    var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: "Results",
                icon: "magnifyingglass",
                iconColor: .arkadGold,
                count: viewModel.discoveryCommunities.count
            )
            communityGrid(viewModel.discoveryCommunities)
        }
    }

    // MARK: - Featured Communities Section
    var featuredCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: "Featured",
                icon: "star.fill",
                iconColor: .arkadGold,
                count: viewModel.featuredCommunities.count
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(viewModel.featuredCommunities) { community in
                        EnhancedCommunityCard(
                            community: community,
                            style: .featured(),
                            isUserMember: viewModel.isUserMember(of: community),
                            onTap: {
                                navigateToCommunitDetail(community)
                            },
                            onJoin: {
                                viewModel.joinCommunity(community)
                                HapticManager.shared.notification(type: .success)
                            },
                            onInfo: {
                                showCommunityPreview(community)
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.horizontal, -24)
        }
    }
    
    // MARK: - Community Types Sections
    var communityTypesSections: some View {
        VStack(spacing: 32) {
            ForEach(viewModel.allCommunityTypesInOrder, id: \.self) { type in
                communityTypeSection(for: type)
            }
        }
    }
    
    func communityTypeSection(for type: CommunityType) -> some View {
        let communities = viewModel.communitiesForType(type)

        return Group {
            if !communities.isEmpty {
                VStack(alignment: .leading, spacing: 18) {
                    sectionHeader(
                        title: viewModel.sectionTitle(for: type),
                        icon: viewModel.sectionIcon(for: type),
                        iconColor: getSectionColor(for: type),
                        count: communities.count
                    )
                    communityGrid(communities)
                }
            }
        }
    }

    func communityGrid(_ communities: [Community]) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
            spacing: 18
        ) {
            ForEach(communities) { community in
                EnhancedCommunityCard(
                    community: community,
                    style: .regular(),
                    isUserMember: viewModel.isUserMember(of: community),
                    onTap: { navigateToCommunitDetail(community) },
                    onJoin: {
                        viewModel.joinCommunity(community)
                        HapticManager.shared.notification(type: .success)
                    },
                    onInfo: { showCommunityPreview(community) }
                )
            }
        }
    }

    // MARK: - Section Header
    func sectionHeader(
        title: String,
        icon: String,
        iconColor: Color,
        count: Int
    ) -> some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    if count > 0 {
                        Text("\(count) \(count == 1 ? "community" : "communities")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Empty States
    var emptyDiscoverState: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.arkadGold.opacity(0.1), Color.arkadGold.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGold.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 14) {
                Text("No Communities Available")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("Be the first to create a community!")
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)
            }
            
            Button("Create Community") {
                showCreateCommunity = true
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.arkadBlack)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGold.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: .arkadGold.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .padding(.top, 80)
    }
    
    // MARK: - Helper Methods
    func getSectionColor(for type: CommunityType) -> Color {
        type.tint
    }
    
    func showCommunityPreview(_ community: Community) {
        selectedCommunityForPreview = community
        showCommunityPreview = true
    }
}

// MARK: - Working Search Bar and Filter
extension CommunitiesView {
    var searchBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textSecondary)
                
                TextField("Search communities...", text: $viewModel.searchQuery)
                    .font(.system(size: 16))
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        // Trigger search when user presses return
                        Task {
                            await viewModel.searchCommunities(query: viewModel.searchQuery)
                        }
                    }
                
                Spacer()
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.searchQuery = ""
                        Task {
                            await viewModel.loadDiscoveryCommunities()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                viewModel.searchQuery.isEmpty ?
                                    Color.borderPrimary.opacity(0.3) :
                                    Color.arkadGold.opacity(0.5),
                                lineWidth: 1
                            )
                    )
            )
            
            // Working Filter button
            Button(action: {
                showFilterSheet = true
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(hasActiveFilters ? Color.arkadGold.opacity(0.15) : Color.arkadGold.opacity(0.1))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    hasActiveFilters ? Color.arkadGold.opacity(0.6) : Color.arkadGold.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                    
                    ZStack {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.arkadGold)
                        
                        // Active filter indicator
                        if hasActiveFilters {
                            Circle()
                                .fill(Color.arkadGold)
                                .frame(width: 8, height: 8)
                                .offset(x: 12, y: -12)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // Check if any filters are active
    var hasActiveFilters: Bool {
        viewModel.selectedCategory != nil ||
        viewModel.minimumMemberCount > 0 ||
        viewModel.sortType != .memberCount

    }
}
