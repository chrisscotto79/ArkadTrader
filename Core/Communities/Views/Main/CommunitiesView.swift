// File: Core/Communities/Views/Main/CommunitiesView.swift
// The Communities tab: large header with a create button and a section switcher
// (Joined / Discover / Leaderboard). Each section's content is in a CommunitiesView+*.swift file.

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

    // Leaderboard state
    @State var selectedLeaderboardMode: LeaderboardMode = .communities
    @StateObject var globalLeaderboardViewModel = GlobalLeaderboardViewModel()
    @State var globalProfileUser: User?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                contentSection
            }
            .screenBackground()
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
            .sheet(isPresented: $showCreateCommunity, onDismiss: {
                Task { await viewModel.loadUserCommunities() }
            }) {
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

    /// Large title, create button, and the always-visible section switcher
    var header: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Communities") {
                IconButton(
                    systemName: "plus",
                    accessibilityLabel: "Create a community",
                    filled: true
                ) {
                    HapticManager.shared.impact(style: .light)
                    showCreateCommunity = true
                }
            }

            SegmentedPicker(
                options: CommunityMainTab.allCases,
                selection: tabSelection,
                title: { $0.shortName }
            )
            .padding(.horizontal, DS.pageMargin)
            .padding(.bottom, DS.Spacing.s)
        }
    }

    /// Picking a section by hand stops the automatic "new users land on Discover" switch
    private var tabSelection: Binding<CommunityMainTab> {
        Binding(
            get: { selectedTab },
            set: { selectedTab = $0; hasChosenTab = true }
        )
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

    func showCreate() {
        HapticManager.shared.impact(style: .light)
        showCreateCommunity = true
    }

    func goToDiscover() {
        hasChosenTab = true
        withAnimation(.snappy(duration: 0.25)) { selectedTab = .discover }
    }
}

// MARK: - Content Section
extension CommunitiesView {
    var contentSection: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.xl) {
                switch selectedTab {
                case .discover:
                    discoverContent
                case .myCommunities:
                    myCommunitiesContent
                case .leaderboard:
                    if viewModel.userCommunities.isEmpty && selectedLeaderboardMode == .communities {
                        leaderboardModePicker
                        emptyLeaderboardState
                    } else {
                        leaderboardContent
                    }
                }
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.m)
            .padding(.bottom, DS.Spacing.xxl)
            .animation(.snappy(duration: 0.25), value: selectedTab)
        }
        .scrollDismissesKeyboard(.immediately)
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
        CommunityPalette.initials(for: name)
    }
}


#Preview {
    CommunitiesView()
        .environmentObject(FirebaseAuthService.shared)
}
