// File: Core/Communities/ViewModels/CommunityCreationViewModel.swift
// Complete Community Creation ViewModel

import Foundation
import Combine
import SwiftUI  // ← This fixes the Color error


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
    @Published var nameValidation: ValidationState = .none
    @Published var descriptionValidation: ValidationState = .none
    
    // MARK: - Private Properties
    private let communityService = CommunityFirebaseService.shared
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
        // Real-time name validation
        $name
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] name in
                self?.validateName(name)
            }
            .store(in: &cancellables)
        
        // Real-time description validation
        $description
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] description in
                self?.validateDescription(description)
            }
            .store(in: &cancellables)
        
        // Form validity
        Publishers.CombineLatest3($nameValidation, $descriptionValidation, $type)
            .map { nameValidation, descriptionValidation, _ in
                nameValidation == .valid && descriptionValidation == .valid
            }
            .assign(to: &$isFormValid)
        
        // Validation message
        Publishers.CombineLatest($nameValidation, $descriptionValidation)
            .map { [weak self] nameValidation, descriptionValidation in
                self?.getValidationMessage(nameValidation: nameValidation, descriptionValidation: descriptionValidation) ?? ""
            }
            .assign(to: &$validationMessage)
    }
    
    // MARK: - Validation Methods
    
    private func validateName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            nameValidation = .none
            return
        }
        
        if trimmedName.count < nameMinLength {
            nameValidation = .invalid("Name must be at least \(nameMinLength) characters")
            return
        }
        
        if trimmedName.count > nameMaxLength {
            nameValidation = .invalid("Name must be less than \(nameMaxLength) characters")
            return
        }
        
        // Check for inappropriate characters
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
        if trimmedName.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            nameValidation = .invalid("Only letters, numbers, spaces, hyphens, and underscores allowed")
            return
        }
        
        nameValidation = .valid
        
        // Check name availability asynchronously
        Task {
            await checkNameAvailability(trimmedName)
        }
    }
    
    private func validateDescription(_ description: String) {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedDescription.isEmpty {
            descriptionValidation = .none
            return
        }
        
        if trimmedDescription.count < descriptionMinLength {
            descriptionValidation = .invalid("Description must be at least \(descriptionMinLength) characters")
            return
        }
        
        if trimmedDescription.count > descriptionMaxLength {
            descriptionValidation = .invalid("Description must be less than \(descriptionMaxLength) characters")
            return
        }
        
        descriptionValidation = .valid
    }
    
    private func checkNameAvailability(_ name: String) async {
        do {
            let isAvailable = try await communityService.isNameAvailable(name)
            if !isAvailable {
                nameValidation = .invalid("This name is already taken")
            } else if nameValidation != .invalid("") { // Don't override other validation errors
                nameValidation = .valid
            }
        } catch {
            // Don't update validation state if name check fails
            print("Error checking name availability: \(error)")
        }
    }
    
    private func getValidationMessage(nameValidation: ValidationState, descriptionValidation: ValidationState) -> String {
        if case .invalid(let message) = nameValidation {
            return message
        }
        
        if case .invalid(let message) = descriptionValidation {
            return message
        }
        
        return ""
    }
    
    // MARK: - Public Methods
    
    /// Create the community
    func createCommunity() {
        guard isFormValid, let userId = authService.currentUser?.id else { return }
        
        Task {
            isCreating = true
            showError = false
            errorMessage = ""
            
            do {
                // Check user limits
                let canCreate = try await communityService.canUserCreateCommunity(userId: userId)
                guard canCreate.canCreate else {
                    errorMessage = canCreate.message
                    showError = true
                    isCreating = false
                    return
                }
                
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
                
                // Success!
                showSuccess = true
                resetForm()
                
            } catch {
                errorMessage = "Failed to create community: \(error.localizedDescription)"
                showError = true
            }
            
            isCreating = false
        }
    }
    
    /// Reset the form
    func resetForm() {
        name = ""
        description = ""
        type = .general
        isPrivate = false
        nameValidation = .none
        descriptionValidation = .none
        errorMessage = ""
        showError = false
    }
    
    /// Get community guidelines
    func getGuidelines() -> [CommunityGuideline] {
        return communityService.getCommunityGuidelines()
    }
    
    // MARK: - Computed Properties
    
    var characterCountText: String {
        let remaining = descriptionMaxLength - description.count
        return "\(remaining) characters remaining"
    }
    
    var characterCountColor: Color {
        let remaining = descriptionMaxLength - description.count
        if remaining < 20 {
            return .red
        } else if remaining < 50 {
            return .orange
        } else {
            return .secondary
        }
    }
    
    var nameCharacterCount: String {
        let remaining = nameMaxLength - name.count
        return "\(remaining) characters remaining"
    }
    
    var nameCharacterCountColor: Color {
        let remaining = nameMaxLength - name.count
        if remaining < 5 {
            return .red
        } else if remaining < 10 {
            return .orange
        } else {
            return .secondary
        }
    }
}

// MARK: - Supporting Types

enum ValidationState: Equatable {
    case none
    case valid
    case invalid(String)
    
    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        if case .invalid(let message) = self {
            return message
        }
        return nil
    }
}

// MARK: - Preview Helper

