// File: Core/Communities/ViewModels/CommunitiesViewModel.swift
// The Communities tab: your communities, Discover (one query for the biggest public communities,
// then category / size / sort filters on the phone), search, and joining.

import Foundation
import Combine
import UIKit

@MainActor
class CommunitiesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var featuredCommunities: [Community] = []
    @Published private(set) var discoveryCommunities: [Community] = []
    @Published var userCommunities: [Community] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    /// Shown as an alert when joining fails (banned, paid community, network)
    @Published var joinErrorMessage: String?
    /// Communities with a join in flight
    @Published private(set) var joiningIds: Set<String> = []

    // Search and filtering
    @Published var searchQuery = ""
    @Published var selectedCategory: CommunityType? = nil {
        didSet { applyFilters() }
    }
    @Published var sortType: CommunitySortType = .memberCount {
        didSet { applyFilters() }
    }
    /// Discovery filter: hide communities with fewer members than this
    @Published var minimumMemberCount = 0 {
        didSet { applyFilters() }
    }

    // MARK: - Private Properties
    private let communityService = CommunityFirebaseService.shared
    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    /// The biggest public communities, as last read
    private var publicCommunities: [Community] = []
    /// Results for `searchQuery`, before filters
    private var searchResults: [Community] = []
    private var discoveryTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var hasLoaded = false

    // MARK: - Initialization
    init() {
        setupBindings()
    }

    private func setupBindings() {
        // A different signed-in user (the first one is loaded by loadInitialDataIfNeeded)
        authService.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.loadUserCommunities() }
            }
            .store(in: &cancellables)

        $searchQuery
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.runSearch(query)
            }
            .store(in: &cancellables)
    }

    // MARK: - Loading

    /// Loads everything once per screen; later visits keep what's on screen.
    func loadInitialDataIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
    }

    /// Pull to refresh: your communities and Discover
    func refresh() async {
        isLoading = true
        errorMessage = ""
        async let mine: Void = loadUserCommunities()
        async let discovery: Void = loadDiscoveryCommunities()
        _ = await (mine, discovery)
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            await search(searchQuery)
        }
        isLoading = false
    }

    /// Reads the biggest public communities (one query) and applies the filters.
    /// A newer call cancels an older one, so results never arrive out of order.
    func loadDiscoveryCommunities() async {
        discoveryTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let communities = try await self.communityService.loadDiscoveryCommunities(limit: 100)
                guard !Task.isCancelled else { return }
                self.publicCommunities = communities
                self.featuredCommunities = Array(communities.sorted { $0.discoveryScore > $1.discoveryScore }.prefix(5))
                self.applyFilters()
            } catch {
                guard !Task.isCancelled else { return }
                self.handleError(error, context: "loading communities")
            }
        }
        discoveryTask = task
        await task.value
    }

    func loadUserCommunities() async {
        guard let userId = authService.currentUser?.id else {
            userCommunities = []
            return
        }
        do {
            userCommunities = try await communityService.loadUserCommunities(userId: userId)
        } catch {
            handleError(error, context: "loading your communities")
        }
    }

    // MARK: - Search and filtering

    private func runSearch(_ query: String) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.search(query)
        }
    }

    /// Public communities matching the query, plus your own (private ones included) that match by name
    func searchCommunities(query: String) async {
        searchTask?.cancel()
        await search(query)
    }

    private func search(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            applyFilters()
            return
        }
        do {
            var results = try await communityService.searchCommunities(query: trimmed)
            guard !Task.isCancelled, trimmed == searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            let lowered = trimmed.lowercased()
            let ownMatches = userCommunities.filter {
                $0.name.lowercased().contains(lowered) && !results.map(\.id).contains($0.id)
            }
            results = ownMatches + results
            searchResults = results
            applyFilters()
        } catch {
            guard !Task.isCancelled else { return }
            handleError(error, context: "searching communities")
        }
    }

    /// Category, size and sort, applied to the loaded communities (no extra reads)
    private func applyFilters() {
        let isSearching = !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
        var communities = isSearching ? searchResults : publicCommunities
        if let category = selectedCategory {
            communities = communities.filter { $0.type == category }
        }
        if minimumMemberCount > 0 {
            communities = communities.filter { $0.memberCount >= minimumMemberCount }
        }
        // Search results keep their relevance order unless a sort was picked
        if !isSearching || sortType != .memberCount {
            communities = communityService.sortCommunities(communities, by: sortType)
        }
        discoveryCommunities = communities
    }

    // MARK: - Joining

    func isJoining(_ community: Community) -> Bool {
        joiningIds.contains(community.id)
    }

    /// Joins a free community. The community shows as joined right away; the haptic plays on success.
    func joinCommunity(_ community: Community) {
        guard let userId = authService.currentUser?.id, !joiningIds.contains(community.id) else { return }
        joiningIds.insert(community.id)

        Task {
            defer { joiningIds.remove(community.id) }
            do {
                try await communityService.joinCommunity(communityId: community.id, userId: userId)
                var joined = community
                joined.memberCount += 1
                if !userCommunities.contains(where: { $0.id == community.id }) {
                    userCommunities.append(joined)
                }
                replace(joined)
                HapticManager.shared.notification(type: .success)

                // A first join is a good moment to ask about notifications. Without the
                // server there's no remote push, so only ask when it's on.
                if AppConfig.serverFunctionsEnabled {
                    await PushNotificationManager.shared.requestAuthorizationIfNeeded()
                }
            } catch let error as CommunityJoinError {
                HapticManager.shared.notification(type: .error)
                joinErrorMessage = error.errorDescription
            } catch {
                HapticManager.shared.notification(type: .error)
                joinErrorMessage = "Couldn't join \(community.name). Check your connection and try again."
            }
        }
    }

    /// Joins with an invite code (private communities). Returns the community to open.
    func joinWithInviteCode(_ code: String) async throws -> Community {
        guard let userId = authService.currentUser?.id else { throw CommunityError.noPermission }
        let community = try await communityService.joinWithInviteCode(code, userId: userId)
        if !userCommunities.contains(where: { $0.id == community.id }) {
            userCommunities.append(community)
        }
        HapticManager.shared.notification(type: .success)
        return community
    }

    /// Puts an updated copy of a community into the Discover lists
    private func replace(_ community: Community) {
        if let index = publicCommunities.firstIndex(where: { $0.id == community.id }) {
            publicCommunities[index] = community
        }
        if let index = searchResults.firstIndex(where: { $0.id == community.id }) {
            searchResults[index] = community
        }
        if let index = featuredCommunities.firstIndex(where: { $0.id == community.id }) {
            featuredCommunities[index] = community
        }
        applyFilters()
    }

    // MARK: - Community Information

    func isUserMember(of community: Community) -> Bool {
        userCommunities.contains { $0.id == community.id }
    }

    /// Communities created by the user
    var userOwnedCommunities: [Community] {
        guard let userId = authService.currentUser?.id else { return [] }
        return userCommunities.filter { $0.createdBy == userId }
    }

    /// Communities the user is a member of (but didn't create)
    var userMemberCommunities: [Community] {
        guard let userId = authService.currentUser?.id else { return [] }
        return userCommunities.filter { $0.createdBy != userId }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error, context: String) {
        errorMessage = "Error \(context): \(communityService.handleCommunityError(error))"
    }

    func clearError() {
        errorMessage = ""
    }
}

extension CommunitiesViewModel {
    /// All community types in display order
    var allCommunityTypesInOrder: [CommunityType] {
        [.dayTrading, .swingTrading, .options, .crypto, .stocks, .general]
    }

    /// Discover communities of one type, in the chosen sort order
    func communitiesForType(_ type: CommunityType) -> [Community] {
        discoveryCommunities.filter { $0.type == type }
    }

    func sectionTitle(for type: CommunityType) -> String {
        type.shortDisplayName
    }

    func sectionIcon(for type: CommunityType) -> String {
        switch type {
        case .general: return "person.3"
        case .dayTrading: return "chart.line.uptrend.xyaxis"
        case .swingTrading: return "chart.bar"
        case .options: return "option"
        case .crypto: return "bitcoinsign.circle"
        case .stocks: return "building.columns"
        }
    }
}
