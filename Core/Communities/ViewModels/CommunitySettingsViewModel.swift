// New file: CommunitySettingsViewModel.swift
@MainActor
class CommunitySettingsViewModel: ObservableObject {
    @Published var settings: CommunitySettings
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let community: Community
    private let communityService = CommunityFirebaseService.shared
    
    init(community: Community) {
        self.community = community
        self.settings = CommunitySettings(from: community)
    }
    
    func updateCommunity() async {
        // Simple update logic
    }
    
    func deleteCommunity() async {
        // Simple delete logic  
    }
}