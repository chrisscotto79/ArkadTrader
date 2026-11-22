// File: Core/Communities/Views/Main/CommunitiesView.swift
// The Communities tab: header with a section switcher (My Communities / Discover / Leaderboard).
// Each section's content is in a CommunitiesView+*.swift file.

import SwiftUI

struct CommunitiesView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject var viewModel = CommunitiesViewModel()
    @State var showCreateCommunity = false
    @State var selectedTab: CommunityMainTab = .myCommunities
    @State var hasChosenTab = false
    
    @State var selectedCommunityForPreview: Community?
    @State var showCommunityPreview = false
    @State var showFilterSheet = false
    
    // Navigation state
    @State var selectedCommunity: Community?
    @State var navigateToCommunity = false
    
    @State var selectedLeaderboardCommunity: Community?
    @State var navigateToLeaderboard = false
    
    // Enhanced leaderboard state
    @State var selectedLeaderboardMode: LeaderboardMode = .communities
    @StateObject var globalLeaderboardViewModel = GlobalLeaderboardViewModel()
    @State var globalProfileUser: User?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                contentSection
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToLeaderboard) {
                if let community = selectedLeaderboardCommunity {
                    CommunityLeaderboardView(community: community)
                        .environmentObject(authService)
                }
            }
            .navigationDestination(isPresented: $navigateToCommunity) {
                if let community = selectedCommunity {
                    CommunityDetailView(community: community)
                }
            }
            .sheet(isPresented: $showCreateCommunity) {
                CreateCommunityView()
            }
            .sheet(isPresented: $showCommunityPreview) {
                if let community = selectedCommunityForPreview {
                    CommunityPreviewSheet(
                        community: community,
                        isUserMember: viewModel.isUserMember(of: community),
                        onJoin: {
                            viewModel.joinCommunity(community)
                            HapticManager.shared.notification(type: .success)
                        },
                        onEnterCommunity: {
                            selectedCommunityForPreview = nil
                            showCommunityPreview = false
                            navigateToCommunitDetail(community)
                        },
                        onClose: {
                            selectedCommunityForPreview = nil
                            showCommunityPreview = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                CommunityFilterSheet(viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadInitialData()
            }
            .onChange(of: viewModel.userCommunities.isEmpty) { _, isEmpty in
                // New users land on Discover rather than an empty list
                if isEmpty && !hasChosenTab && selectedTab == .myCommunities {
                    selectedTab = .discover
                }
            }
        }
    }

    // MARK: - Header

    /// Title, create button, and the always-visible section switcher
    var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Communities")
                    .font(.largeTitle.weight(.bold))
                Spacer()
                Button {
                    HapticManager.shared.impact(style: .light)
                    showCreateCommunity = true
                } label: {
                    Label("Create", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.arkadGold))
                }
                .accessibilityLabel("Create a community")
            }

            Picker("Section", selection: Binding(
                get: { selectedTab },
                set: { selectedTab = $0; hasChosenTab = true }
            )) {
                ForEach(CommunityMainTab.allCases, id: \.self) { tab in
                    Text(tab.shortName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Navigation Helpers
    func navigateToCommunitDetail(_ community: Community) {
        HapticManager.shared.impact(style: .light)
        selectedCommunity = community
        navigateToCommunity = true
    }
    
    func navigateToLeaderboard(_ community: Community) {
        HapticManager.shared.impact(style: .light)
        selectedLeaderboardCommunity = community
        navigateToLeaderboard = true
    }
}

// MARK: - Content Section
extension CommunitiesView {
    var contentSection: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 24) {
                switch selectedTab {
                case .discover:
                    discoverContent
                case .myCommunities:
                    myCommunitiesContent
                case .leaderboard:
                    if viewModel.userCommunities.isEmpty {
                        emptyLeaderboardState
                    } else {
                        leaderboardContent
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .refreshable {
            viewModel.refreshData()
        }
    }
}


// MARK: - Helper Methods
extension CommunitiesView {
    func getCommunityColor(for type: CommunityType) -> Color {
        type.tint
    }
    
    func getCommunityInitials(from name: String) -> String {
        let words = name.components(separatedBy: " ")
        if words.count >= 2 {
            let first = String(words[0].prefix(1))
            let second = String(words[1].prefix(1))
            return (first + second).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}


#Preview {
    CommunitiesView()
        .environmentObject(FirebaseAuthService.shared)
}
