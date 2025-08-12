// File: Core/Communities/ViewModels/CommunitiesViewModel.swift
// Updated Communities ViewModel with Complete Service Integration

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
    @Published var userStats: UserCommunityStats?
    @Published var activeCommunities = 0
    @Published var userGlobalRank = 0
    
    // Search and filtering
    @Published var searchQuery = ""
    @Published var selectedCategory: CommunityType? = nil
    @Published var showPrivateCommunities = false
    @Published var sortType: CommunitySortType = .memberCount
    
    // MARK: - Private Properties
    private let communityService = CommunityFirebaseService.shared
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
                Task {
                    await self?.loadUserCommunities()
                    await self?.loadUserStats()
                }
            }
            .store(in: &cancellables)
        
        // Setup search debouncing
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                if !query.isEmpty {
                    Task { await self?.searchCommunities(query: query) }
                } else {
                    Task { await self?.loadDiscoveryCommunities() }
                }
            }
            .store(in: &cancellables)
        
        // React to category changes
        $selectedCategory
            .sink { [weak self] _ in
                Task { await self?.loadDiscoveryCommunities() }
            }
            .store(in: &cancellables)
        
        // React to privacy filter changes
        $showPrivateCommunities
            .sink { [weak self] _ in
                Task { await self?.loadDiscoveryCommunities() }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Load initial data when view appears
    func loadInitialData() {
        Task {
            isLoading = true
            errorMessage = ""
            
            async let featuredTask = loadFeaturedCommunities()
            async let discoveryTask = loadDiscoveryCommunities()
            async let userCommunitiesTask = loadUserCommunities()
            async let userStatsTask = loadUserStats()
            
            // Wait for all tasks to complete
            await featuredTask
            await discoveryTask
            await userCommunitiesTask
            await userStatsTask
            
            isLoading = false
        }
    }
    
    /// Refresh all data
    func refreshData() {
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Data Loading Methods
    
    /// Load featured communities
    func loadFeaturedCommunities() async {
        do {
            let featured = try await communityService.loadFeaturedCommunities(limit: 3)
            featuredCommunities = featured
        } catch {
            handleError(error, context: "loading featured communities")
        }
    }
    
    /// Load discovery communities with filters
    func loadDiscoveryCommunities() async {
        do {
            var communities: [Community]
            
            // Apply category filter
            if let category = selectedCategory {
                communities = try await communityService.loadCommunitiesByCategory(category)
            } else {
                communities = try await communityService.loadDiscoveryCommunities()
            }
            
            // Apply privacy filter
            communities = communityService.filterCommunitiesByPrivacy(
                communities,
                showPrivate: showPrivateCommunities
            )
            
            // Apply sorting
            communities = communityService.sortCommunities(communities, by: sortType)
            
            discoveryCommunities = communities
            
        } catch {
            handleError(error, context: "loading discovery communities")
        }
    }
    
    /// Load user's communities
    func loadUserCommunities() async {
        guard let userId = authService.currentUser?.id else {
            userCommunities = []
            return
        }
        
        do {
            let communities = try await communityService.loadUserCommunities(userId: userId)
            userCommunities = communities
            activeCommunities = communities.count
        } catch {
            handleError(error, context: "loading user communities")
        }
    }
    
    /// Load user statistics
    func loadUserStats() async {
        guard let userId = authService.currentUser?.id else {
            userStats = nil
            return
        }
        
        do {
            let stats = try await communityService.getUserCommunityStats(userId: userId)
            userStats = stats
            activeCommunities = stats.activeCommunities
            userGlobalRank = stats.globalRank
        } catch {
            handleError(error, context: "loading user stats")
        }
    }
    
    // MARK: - Community Actions
    
    /// Join a community
    func joinCommunity(_ community: Community) {
        guard let userId = authService.currentUser?.id else { return }
        
        Task {
            do {
                try await communityService.joinCommunity(
                    communityId: community.id,
                    userId: userId
                )
                
                // Refresh data after joining
                await loadUserCommunities()
                await loadDiscoveryCommunities()
                await loadUserStats()
                
            } catch {
                handleError(error, context: "joining community")
            }
        }
    }
    
    /// Leave a community
    func leaveCommunity(_ community: Community) {
        guard let userId = authService.currentUser?.id else { return }
        
        Task {
            do {
                try await communityService.leaveCommunity(
                    communityId: community.id,
                    userId: userId
                )
                
                // Refresh data after leaving
                await loadUserCommunities()
                await loadDiscoveryCommunities()
                await loadUserStats()
                
            } catch {
                handleError(error, context: "leaving community")
            }
        }
    }
    
    /// Create a new community
    func createCommunity(_ community: Community) {
        guard let userId = authService.currentUser?.id else { return }
        
        Task {
            do {
                // Check if user can create more communities
                let canCreate = try await communityService.canUserCreateCommunity(userId: userId)
                guard canCreate.canCreate else {
                    errorMessage = canCreate.message
                    return
                }
                
                try await communityService.createCommunity(community)
                
                // Refresh data after creating
                await loadUserCommunities()
                await loadDiscoveryCommunities()
                await loadUserStats()
                
            } catch {
                handleError(error, context: "creating community")
            }
        }
    }
    
    // MARK: - Search and Filtering
    
    /// Search communities
    func searchCommunities(query: String) async {
        do {
            // Simple search first
            var results = try await communityService.searchCommunities(query: query)
            
            // Apply filters manually
            if let category = selectedCategory {
                results = results.filter { $0.type == category }
            }
            
            if !showPrivateCommunities {
                results = results.filter { !$0.isPrivate }
            }
            
            discoveryCommunities = results
        } catch {
            handleError(error, context: "searching communities")
        }
    }
    
    /// Filter by category
    func filterByCategory(_ category: CommunityType?) {
        selectedCategory = category
        // Auto-triggers loadDiscoveryCommunities via binding
    }
    
    /// Toggle private communities visibility
    func togglePrivateCommunities() {
        showPrivateCommunities.toggle()
        // Auto-triggers loadDiscoveryCommunities via binding
    }
    
    /// Sort communities
    func sortCommunitiesBy(_ sortType: CommunitySortType) {
        self.sortType = sortType
        discoveryCommunities = communityService.sortCommunities(discoveryCommunities, by: sortType)
    }
    
    // MARK: - Community Information
    
    /// Check if user is member of community
    func isUserMember(of community: Community) -> Bool {
        return userCommunities.contains { $0.id == community.id }
    }
    
    /// Check if user owns community
    func isUserOwner(of community: Community) -> Bool {
        guard let userId = authService.currentUser?.id else { return false }
        return community.createdBy == userId
    }
    
    /// Get communities created by user
    var userOwnedCommunities: [Community] {
        guard let userId = authService.currentUser?.id else { return [] }
        return userCommunities.filter { $0.createdBy == userId }
    }
    
    /// Get communities user is member of (but didn't create)
    var userMemberCommunities: [Community] {
        guard let userId = authService.currentUser?.id else { return [] }
        return userCommunities.filter { $0.createdBy != userId }
    }
    
    /// Get count of communities by type
    func communitiesCount(for type: CommunityType) -> Int {
        return discoveryCommunities.filter { $0.type == type }.count
    }
    
    // MARK: - Validation
    
    /// Validate community creation data
    func validateCommunityData(name: String, description: String) -> (isValid: Bool, message: String) {
        let nameValidation = communityService.validateCommunityName(name)
        if !nameValidation.isValid {
            return nameValidation
        }
        
        let descriptionValidation = communityService.validateCommunityDescription(description)
        if !descriptionValidation.isValid {
            return descriptionValidation
        }
        
        return (true, "")
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error, context: String) {
        let message = communityService.handleCommunityError(error)
        errorMessage = "Error \(context): \(message)"
        print("❌ CommunitiesViewModel - Error \(context): \(error)")
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = ""
    }
    
    // MARK: - Computed Properties
    
    /// Whether user has any communities
    var hasUserCommunities: Bool {
        !userCommunities.isEmpty
    }
    
    /// Count of communities user created
    var userCreatedCommunitiesCount: Int {
        userOwnedCommunities.count
    }
    
    /// Whether data is currently loading
    var isDataLoading: Bool {
        isLoading
    }
    
    /// Whether there's an active error
    var hasError: Bool {
        !errorMessage.isEmpty
    }
    
    // MARK: - Leaderboard Data
    
    @Published var leaderboardData: CommunityLeaderboards?
    
    /// Load leaderboard data
    func loadLeaderboards() async {
        do {
            let leaderboards = try await communityService.getCommunityLeaderboards()
            leaderboardData = leaderboards
        } catch {
            handleError(error, context: "loading leaderboards")
        }
    }
}


extension CommunitiesViewModel {
    
    // MARK: - Grouped Communities for Discover Tab
    
    /// Communities grouped by type in the desired display order
    var groupedDiscoveryCommunities: [(type: CommunityType, communities: [Community])] {
        // Define the display order
        let typeOrder: [CommunityType] = [
            .dayTrading,
            .swingTrading,
            .options,
            .crypto,
            .stocks,
            .general
        ]
        
        // Group communities by type
        let grouped = Dictionary(grouping: discoveryCommunities) { $0.type }
        
        // Return in the specified order, only including types that have communities
        return typeOrder.compactMap { type in
            guard let communities = grouped[type], !communities.isEmpty else {
                return nil
            }
            return (type: type, communities: communities.sorted {
                // Sort within each group by member count (descending) and then by name
                if $0.memberCount != $1.memberCount {
                    return $0.memberCount > $1.memberCount
                }
                return $0.name < $1.name
            })
        }
    }
    
    /// All community types in display order (for showing empty states)
    var allCommunityTypesInOrder: [CommunityType] {
        return [.dayTrading, .swingTrading, .options, .crypto, .stocks, .general]
    }
    
    /// Get communities for a specific type
    func communitiesForType(_ type: CommunityType) -> [Community] {
        return discoveryCommunities
            .filter { $0.type == type }
            .sorted {
                // Sort by member count (descending) and then by name
                if $0.memberCount != $1.memberCount {
                    return $0.memberCount > $1.memberCount
                }
                return $0.name < $1.name
            }
    }
    
    /// Check if a community type has any communities
    func hasCommunitiesForType(_ type: CommunityType) -> Bool {
        return discoveryCommunities.contains { $0.type == type }
    }
    
    /// Get empty community types (for showing empty states)
    var emptyCommunityTypes: [CommunityType] {
        let typesWithCommunities = Set(discoveryCommunities.map { $0.type })
        return allCommunityTypesInOrder.filter { !typesWithCommunities.contains($0) }
    }
    
    /// Get section title for a community type
    func sectionTitle(for type: CommunityType) -> String {
        return type.shortDisplayName
    }
    
    /// Get section icon for a community type
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
    
    /// Get section color for a community type
    func sectionColor(for type: CommunityType) -> String {
        switch type {
        case .dayTrading: return "red"
        case .swingTrading: return "orange"
        case .options: return "purple"
        case .crypto: return "yellow"
        case .stocks: return "green"
        case .general: return "blue"
        }
    }
}
