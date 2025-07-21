//
//  CommunitiesViewModel.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/19/25.
//

// File: Core/Communities/ViewModels/CommunitiesViewModel.swift
// Main Communities Tab ViewModel

import Foundation
import Combine

@MainActor
class CommunitiesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var featuredCommunities: [Community] = []
    @Published var discoveryCommunities: [Community] = []
    @Published var userCommunities: [Community] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // User stats
    @Published var activeCommunities = 0
    @Published var userGlobalRank = 0
    
    // Search and filtering
    @Published var searchQuery = ""
    @Published var selectedCategory: CommunityType? = nil
    @Published var showPrivateCommunities = false
    
    // MARK: - Private Properties
    private let communityService = CommunityFirebaseService()
    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // React to auth state changes
        authService.$currentUser
            .compactMap { $0 }
            .sink { [weak self] _ in
                Task { await self?.loadUserCommunities() }
            }
            .store(in: &cancellables)
        
        // Setup search debouncing
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                if !query.isEmpty {
                    Task { await self?.searchCommunities(query: query) }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Load initial data when view appears
    func loadInitialData() {
        Task {
            isLoading = true
            errorMessage = ""
            
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadFeaturedCommunities() }
                group.addTask { await self.loadDiscoveryCommunities() }
                group.addTask { await self.loadUserCommunities() }
                group.addTask { await self.loadUserStats() }
            }
            
            isLoading = false
        }
    }
    
    /// Refresh all communities data
    func refreshData() {
        Task {
            await loadInitialData()
        }
    }
    
    /// Join a community
    func joinCommunity(_ community: Community) async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            try await communityService.joinCommunity(communityId: community.id, userId: userId)
            
            // Update local state
            if !userCommunities.contains(where: { $0.id == community.id }) {
                var updatedCommunity = community
                updatedCommunity.memberCount += 1
                userCommunities.append(updatedCommunity)
                
                // Update discovery list
                if let index = discoveryCommunities.firstIndex(where: { $0.id == community.id }) {
                    discoveryCommunities[index].memberCount += 1
                }
            }
            
            await loadUserStats()
            
        } catch {
            errorMessage = "Failed to join community: \(error.localizedDescription)"
        }
    }
    
    /// Leave a community
    func leaveCommunity(_ community: Community) async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            try await communityService.leaveCommunity(communityId: community.id, userId: userId)
            
            // Update local state
            userCommunities.removeAll { $0.id == community.id }
            
            // Update discovery list
            if let index = discoveryCommunities.firstIndex(where: { $0.id == community.id }) {
                discoveryCommunities[index].memberCount -= 1
            }
            
            await loadUserStats()
            
        } catch {
            errorMessage = "Failed to leave community: \(error.localizedDescription)"
        }
    }
    
    /// Create a new community
    func createCommunity(_ community: Community) async -> Bool {
        do {
            try await communityService.createCommunity(community)
            
            // Add to user communities
            userCommunities.append(community)
            
            // Refresh data
            await loadDiscoveryCommunities()
            await loadUserStats()
            
            return true
        } catch {
            errorMessage = "Failed to create community: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Check if user is member of community
    func isUserMemberOf(_ community: Community) -> Bool {
        return userCommunities.contains { $0.id == community.id }
    }
    
    /// Get user's role in community
    func getUserRoleIn(_ community: Community) async -> String? {
        guard let userId = authService.currentUser?.id else { return nil }
        return try? await communityService.getUserRole(communityId: community.id, userId: userId)
    }
    
    // MARK: - Private Methods
    
    private func loadFeaturedCommunities() async {
        do {
            featuredCommunities = try await communityService.getFeaturedCommunities(limit: 10)
        } catch {
            print("Error loading featured communities: \(error)")
        }
    }
    
    private func loadDiscoveryCommunities() async {
        do {
            discoveryCommunities = try await communityService.getPublicCommunities(limit: 50)
        } catch {
            print("Error loading discovery communities: \(error)")
            errorMessage = "Failed to load communities"
        }
    }
    
    private func loadUserCommunities() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            userCommunities = try await communityService.getUserCommunities(userId: userId)
        } catch {
            print("Error loading user communities: \(error)")
        }
    }
    
    private func loadUserStats() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            let stats = try await communityService.getUserCommunityStats(userId: userId)
            activeCommunities = stats.activeCommunities
            userGlobalRank = stats.globalRank
        } catch {
            print("Error loading user stats: \(error)")
        }
    }
    
    private func searchCommunities(query: String) async {
        do {
            let results = try await communityService.searchCommunities(
                query: query,
                category: selectedCategory,
                includePrivate: showPrivateCommunities
            )
            discoveryCommunities = results
        } catch {
            print("Error searching communities: \(error)")
            errorMessage = "Search failed"
        }
    }
    
    // MARK: - Filtering
    func filterCommunitiesByCategory(_ category: CommunityType?) {
        selectedCategory = category
        Task {
            await loadDiscoveryCommunities()
        }
    }
    
    func togglePrivateCommunities() {
        showPrivateCommunities.toggle()
        Task {
            await loadDiscoveryCommunities()
        }
    }
    
    // MARK: - Sorting
    func sortCommunitiesBy(_ sortType: CommunitySortType) {
        switch sortType {
        case .memberCount:
            discoveryCommunities.sort { $0.memberCount > $1.memberCount }
        case .newest:
            discoveryCommunities.sort { $0.createdAt > $1.createdAt }
        case .alphabetical:
            discoveryCommunities.sort { $0.name < $1.name }
        case .mostActive:
            // TODO: Implement activity sorting when we have activity data
            break
        }
    }
}

// MARK: - Supporting Types
enum CommunitySortType: CaseIterable {
    case memberCount
    case newest
    case alphabetical
    case mostActive
    
    var displayName: String {
        switch self {
        case .memberCount: return "Most Members"
        case .newest: return "Newest"
        case .alphabetical: return "A-Z"
        case .mostActive: return "Most Active"
        }
    }
}

// MARK: - User Community Stats
struct UserCommunityStats {
    let activeCommunities: Int
    let globalRank: Int
    let totalMembers: Int
    let communitiesOwned: Int
    let communitiesModerated: Int
}

// MARK: - Placeholder Service
class CommunityFirebaseService {
    
    // MARK: - Community CRUD
    func createCommunity(_ community: Community) async throws {
        // TODO: Implement with Firebase
        // This will use the existing FirebaseServices community methods
        try await FirebaseServices.shared.createCommunity(community)
    }
    
    func getFeaturedCommunities(limit: Int) async throws -> [Community] {
        // TODO: Implement featured algorithm
        // For now, return most popular public communities
        return try await FirebaseServices.shared.getCommunities(limit: limit)
    }
    
    func getPublicCommunities(limit: Int) async throws -> [Community] {
        return try await FirebaseServices.shared.getCommunities(limit: limit)
    }
    
    func getUserCommunities(userId: String) async throws -> [Community] {
        return try await FirebaseServices.shared.getUserCommunities(userId: userId)
    }
    
    func searchCommunities(query: String, category: CommunityType?, includePrivate: Bool) async throws -> [Community] {
        // TODO: Implement advanced search with filters
        return try await FirebaseServices.shared.searchCommunities(query: query)
    }
    
    // MARK: - Membership
    func joinCommunity(communityId: String, userId: String) async throws {
        try await FirebaseServices.shared.joinCommunity(communityId: communityId, userId: userId)
    }
    
    func leaveCommunity(communityId: String, userId: String) async throws {
        try await FirebaseServices.shared.leaveCommunity(communityId: communityId, userId: userId)
    }
    
    func getUserRole(communityId: String, userId: String) async throws -> String {
        // TODO: Implement role checking
        return "member"
    }
    
    // MARK: - Stats
    func getUserCommunityStats(userId: String) async throws -> UserCommunityStats {
        // TODO: Implement comprehensive stats
        let userCommunities = try await getUserCommunities(userId: userId)
        
        return UserCommunityStats(
            activeCommunities: userCommunities.count,
            globalRank: Int.random(in: 1...1000), // TODO: Calculate real rank
            totalMembers: userCommunities.reduce(0) { $0 + $1.memberCount },
            communitiesOwned: userCommunities.filter { $0.createdBy == userId }.count,
            communitiesModerated: 0 // TODO: Implement moderator tracking
        )
    }
}

// MARK: - Preview Data
extension CommunitiesViewModel {
    static func preview() -> CommunitiesViewModel {
        let viewModel = CommunitiesViewModel()
        
        // Mock data for previews
        viewModel.featuredCommunities = [
            Community(name: "Day Traders Elite", description: "Advanced day trading strategies and live market analysis", type: .dayTrading, creatorId: "mock1"),
            Community(name: "Options Hub", description: "Options trading community for all skill levels", type: .options, creatorId: "mock2"),
            Community(name: "Crypto Signals", description: "Cryptocurrency trading signals and discussions", type: .crypto, creatorId: "mock3")
        ]
        
        viewModel.discoveryCommunities = viewModel.featuredCommunities
        viewModel.activeCommunities = 3
        viewModel.userGlobalRank = 42
        
        return viewModel
    }
}
