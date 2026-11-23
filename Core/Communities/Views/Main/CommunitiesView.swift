// File: Core/Communities/Views/Main/CommunitiesView.swift
// The Communities tab: large header with a create button and a section switcher
// (Joined / Discover / Leaderboard). Each section's content is in a CommunitiesView+*.swift file.

import SwiftUI

struct CommunitiesView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var tabRouter: TabRouter
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
    /// Channel (and message) a notification points at, opened by the community page
    @State var linkedChannel: (channelId: String, messageId: String?)?
    @State var showJoinWithCode = false
    /// A linked community that can't be opened (private, or deleted)
    @State var showUnavailableCommunity = false

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
            .statusBarBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToLeaderboard) {
                if let community = selectedLeaderboardCommunity {
                    CommunityLeaderboardView(community: community)
                        .environmentObject(authService)
                }
            }
            .onAppear { openLinkedCommunity(tabRouter.pendingDeepLink) }
            .onChange(of: tabRouter.pendingDeepLink) { _, link in openLinkedCommunity(link) }
            .navigationDestination(isPresented: $navigateToCommunity) {
                if let community = selectedCommunity {
                    CommunityDetailView(
                        community: community,
                        initialChannelId: linkedChannel?.channelId,
                        initialMessageId: linkedChannel?.messageId
                    )
                }
            }
            .onChange(of: navigateToCommunity) { _, isShowing in
                // Back from a community: joins, leaves and deletes made there show up here
                if !isShowing {
                    linkedChannel = nil
                    Task { await viewModel.loadUserCommunities() }
                }
            }
            .sheet(isPresented: $showJoinWithCode) {
                JoinWithInviteCodeSheet(join: viewModel.joinWithInviteCode) { community in
                    navigateToCommunitDetail(community)
                }
            }
            .alert("This community is private", isPresented: $showUnavailableCommunity) {
                Button("Join with invite code") { showJoinWithCode = true }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Only members can open it. If someone sent you an invite code, you can join with it.")
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
                        },
                        onEnterCommunity: {
                            selectedCommunityForPreview = nil
                            showCommunityPreview = false
                            navigateToCommunitDetail(community)
                        },
                        onClose: {
                            selectedCommunityForPreview = nil
                            showCommunityPreview = false
                        },
                        onSubscribed: {
                            Task { await viewModel.loadUserCommunities() }
                        }
                    )
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                CommunityFilterSheet(viewModel: viewModel)
            }
            .alert(
                "Couldn't join",
                isPresented: Binding(
                    get: { viewModel.joinErrorMessage != nil },
                    set: { if !$0 { viewModel.joinErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.joinErrorMessage ?? "")
            }
            .task {
                await viewModel.loadInitialDataIfNeeded()
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
    /// Opens the community a notification points at. Paid-community gating happens in the detail screen.
    /// A `.channel` link opens the community page, which then opens the channel at the message.
    func openLinkedCommunity(_ link: DeepLink?) {
        let communityId: String
        var channel: (channelId: String, messageId: String?)?
        switch link {
        case .community(let id): communityId = id
        case .channel(let id, let channelId, let messageId):
            communityId = id
            channel = (channelId, messageId)
        default: return
        }
        tabRouter.pendingDeepLink = nil
        Task {
            guard let community = try? await CommunityFirebaseService.shared.getSingleCommunity(communityId: communityId) else {
                showUnavailableCommunity = true
                return
            }
            // Pop anything open first, so the link always lands on a fresh community page
            if navigateToCommunity {
                navigateToCommunity = false
                try? await Task.sleep(for: .milliseconds(400))
            }
            linkedChannel = channel
            navigateToCommunitDetail(community)
        }
    }

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
            await viewModel.refresh()
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


// MARK: - Join with invite code

/// Enter a private community's invite code to join it.
struct JoinWithInviteCodeSheet: View {
    /// Joins with the code and returns the community it opens
    let join: (String) async throws -> Community
    var onJoined: (Community) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private var cleanCode: String { CommunityInvite.normalize(code) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("8-character code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .focused($isFocused)
                        .submitLabel(.join)
                        .onSubmit(submit)
                } footer: {
                    Text(errorMessage ?? "Private communities share a code with the people they invite.")
                        .foregroundStyle(errorMessage == nil ? Color.secondary : Color.marketRed)
                }
                .listRowBackground(Color.surface)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .tint(Color.goldText)
            .navigationTitle("Join with invite code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isJoining {
                        ProgressView()
                    } else {
                        Button("Join", action: submit)
                            .fontWeight(.semibold)
                            .disabled(!CommunityInvite.isWellFormed(cleanCode))
                    }
                }
            }
            .onAppear { isFocused = true }
            .onChange(of: code) { errorMessage = nil }
        }
        .presentationDetents([.medium])
    }

    private func submit() {
        guard CommunityInvite.isWellFormed(cleanCode), !isJoining else { return }
        isJoining = true
        Task {
            do {
                let community = try await join(cleanCode)
                dismiss()
                onJoined(community)
            } catch let error as CommunityJoinError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "Couldn't join. Check your connection and try again."
            }
            isJoining = false
        }
    }
}

#Preview {
    CommunitiesView()
        .environmentObject(FirebaseAuthService.shared)
}
