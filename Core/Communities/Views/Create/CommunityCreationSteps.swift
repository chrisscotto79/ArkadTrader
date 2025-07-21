//
//  CommunityCreationSteps.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/19/25.
//

// File: Core/Communities/ViewModels/CommunityCreationViewModel.swift
// Community Creation Logic

import Foundation
import Combine

@MainActor
class CommunityCreationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var name = ""
    @Published var description = ""
    @Published var type: CommunityType = .general
    @Published var isPrivate = false
    
    // State
    @Published var isCreating = false
    @Published var showError = false
    @Published var showSuccess = false
    @Published var errorMessage = ""
    
    // Validation
    @Published var isFormValid = false
    @Published var validationMessage = ""
    
    // MARK: - Private Properties
    private let communityService = CommunityFirebaseService()
    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    private let nameMinLength = 3
    private let nameMaxLength = 30
    private let descriptionMinLength = 10
    private let descriptionMaxLength = 280
    private let maxCommunitiesPerUser = 2
    
    // MARK: - Initialization
    init() {
        setupValidation()
    }
    
    // MARK: - Setup
    private func setupValidation() {
        // Combine form fields to validate
        Publishers.CombineLatest3($name, $description, $type)
            .map { [weak self] name, description, type in
                self?.validateForm(name: name, description: description, type: type) ?? false
            }
            .assign(to: &$isFormValid)
        
        // Update validation message
        Publishers.CombineLatest($name, $description)
            .map { [weak self] name, description in
                self?.getValidationMessage(name: name, description: description) ?? ""
            }
            .assign(to: &$validationMessage)
    }
    
    // MARK: - Public Methods
    
    /// Create the community
    func createCommunity() {
        guard isFormValid else { return }
        guard let userId = authService.currentUser?.id else {
            showErrorMessage("Please log in to create a community")
            return
        }
        
        Task {
            await performCommunityCreation(userId: userId)
        }
    }
    
    /// Reset the form
    func resetForm() {
        name = ""
        description = ""
        type = .general
        isPrivate = false
        errorMessage = ""
        showError = false
        showSuccess = false
    }
    
    // MARK: - Private Methods
    
    private func performCommunityCreation(userId: String) async {
        isCreating = true
        
        do {
            // Check if user has reached community limit
            try await validateUserCommunityLimit(userId: userId)
            
            // Create the community
            let community = Community(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                type: type,
                creatorId: userId,
                memberCount: 1,
                isPrivate: isPrivate
            )
            
            try await communityService.createCommunity(community)
            
            // Track analytics
            await trackCommunityCreation(community: community)
            
            // Show success
            showSuccess = true
            
            // Reset form for next use
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.resetForm()
            }
            
        } catch let error as CommunityCreationError {
            showErrorMessage(error.localizedDescription)
        } catch {
            showErrorMessage("Failed to create community. Please try again.")
        }
        
        isCreating = false
    }
    
    private func validateUserCommunityLimit(userId: String) async throws {
        let userCommunities = try await communityService.getUserOwnedCommunities(userId: userId)
        
        if userCommunities.count >= maxCommunitiesPerUser {
            throw CommunityCreationError.communityLimitReached
        }
    }
    
    private func validateForm(name: String, description: String, type: CommunityType) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedName.count >= nameMinLength && trimmedName.count <= nameMaxLength else {
            return false
        }
        
        guard trimmedDescription.count >= descriptionMinLength && trimmedDescription.count <= descriptionMaxLength else {
            return false
        }
        
        // Check for inappropriate content
        guard !containsInappropriateContent(trimmedName) && !containsInappropriateContent(trimmedDescription) else {
            return false
        }
        
        return true
    }
    
    private func getValidationMessage(name: String, description: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedName.isEmpty && trimmedName.count < nameMinLength {
            return "Community name must be at least \(nameMinLength) characters"
        }
        
        if trimmedName.count > nameMaxLength {
            return "Community name cannot exceed \(nameMaxLength) characters"
        }
        
        if !trimmedDescription.isEmpty && trimmedDescription.count < descriptionMinLength {
            return "Description must be at least \(descriptionMinLength) characters"
        }
        
        if trimmedDescription.count > descriptionMaxLength {
            return "Description cannot exceed \(descriptionMaxLength) characters"
        }
        
        if containsInappropriateContent(trimmedName) || containsInappropriateContent(trimmedDescription) {
            return "Please remove inappropriate content"
        }
        
        return ""
    }
    
    private func containsInappropriateContent(_ text: String) -> Bool {
        let inappropriateWords = [
            "spam", "scam", "fake", "fraud", "pump", "dump",
            // Add more inappropriate words as needed
        ]
        
        let lowercaseText = text.lowercased()
        return inappropriateWords.contains { lowercaseText.contains($0) }
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func trackCommunityCreation(community: Community) async {
        // Track community creation for analytics
        do {
            try await FirebaseServices.shared.trackUserActivity(
                userId: community.createdBy,
                action: "community_created",
                details: [
                    "community_id": community.id,
                    "community_name": community.name,
                    "community_type": community.type.rawValue,
                    "is_private": community.isPrivate
                ]
            )
        } catch {
            print("Failed to track community creation: \(error)")
        }
    }
}

// MARK: - Community Creation Error
enum CommunityCreationError: LocalizedError {
    case communityLimitReached
    case inappropriateContent
    case duplicateName
    case networkError
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .communityLimitReached:
            return "You've reached the maximum of 2 communities. Delete or transfer ownership of an existing community to create a new one."
        case .inappropriateContent:
            return "Community name or description contains inappropriate content. Please revise and try again."
        case .duplicateName:
            return "A community with this name already exists. Please choose a different name."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .unauthorized:
            return "You don't have permission to create communities. Please log in and try again."
        }
    }
}

// MARK: - Extended Community Service
extension CommunityFirebaseService {
    
    /// Get communities owned by a specific user
    func getUserOwnedCommunities(userId: String) async throws -> [Community] {
        // For now, filter from all user communities
        let userCommunities = try await getUserCommunities(userId: userId)
        return userCommunities.filter { $0.createdBy == userId }
    }
    
    /// Check if community name is available
    func isNameAvailable(_ name: String) async throws -> Bool {
        let existingCommunities = try await searchCommunities(
            query: name,
            category: nil,
            includePrivate: true
        )
        
        return !existingCommunities.contains {
            $0.name.lowercased() == name.lowercased()
        }
    }
    
    /// Get community creation guidelines
    func getCommunityGuidelines() -> [CommunityGuideline] {
        return [
            CommunityGuideline(
                title: "Be Respectful",
                description: "Treat all members with respect and maintain a professional trading environment.",
                icon: "hand.raised.fill"
            ),
            CommunityGuideline(
                title: "No Financial Advice",
                description: "Share analysis and ideas, but avoid giving direct financial advice.",
                icon: "exclamationmark.triangle.fill"
            ),
            CommunityGuideline(
                title: "Stay On Topic",
                description: "Keep discussions relevant to your community's trading focus.",
                icon: "target"
            ),
            CommunityGuideline(
                title: "No Spam or Promotion",
                description: "Avoid excessive self-promotion or spam content.",
                icon: "hand.point.left.fill"
            )
        ]
    }
}

// MARK: - Community Guidelines
struct CommunityGuideline {
    let title: String
    let description: String
    let icon: String
}

// MARK: - Preview Helper
extension CommunityCreationViewModel {
    static func preview() -> CommunityCreationViewModel {
        let viewModel = CommunityCreationViewModel()
        viewModel.name = "Day Traders Elite"
        viewModel.description = "A community for experienced day traders to share strategies and market insights."
        viewModel.type = .dayTrading
        return viewModel
    }
}

// MARK: - Form Validation Extensions
extension String {
    var isValidCommunityName: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 3 && trimmed.count <= 30 && !trimmed.isEmpty
    }
    
    var isValidCommunityDescription: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 10 && trimmed.count <= 280 && !trimmed.isEmpty
    }
}
