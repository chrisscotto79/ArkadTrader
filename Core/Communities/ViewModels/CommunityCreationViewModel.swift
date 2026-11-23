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

    // Pricing (paid communities go through Stripe Connect)
    @Published var isPaid = false
    @Published var priceText = ""
    @Published var trialDays = 0
    /// The owner's Stripe account; nil until loaded
    @Published var payoutStatus: StripeAccountStatus?
    @Published var isLoadingPayoutStatus = false
    @Published var payoutStatusFailed = false
    
    // State
    @Published var isCreating = false
    @Published var showError = false
    @Published var showSuccess = false
    @Published var errorMessage = ""
    /// Body of the success alert
    @Published var successMessage = ""
    
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
    
    // MARK: - Pricing

    /// Paid communities need finished payout setup (`stripeAccounts/{uid}.chargesEnabled`)
    var canChargeMembers: Bool { payoutStatus?.chargesEnabled == true }

    var price: Double? { CommunityPricing.parsePrice(priceText) }

    /// nil when the price is fine (or the community is free)
    var priceValidationMessage: String? {
        guard isPaid else { return nil }
        return CommunityPricing.validationMessage(for: priceText)
    }

    /// The pricing step can continue: free, or paid with payouts ready and a valid price
    var isPricingValid: Bool {
        !isPaid || (canChargeMembers && priceValidationMessage == nil)
    }

    func loadPayoutStatus() async {
        guard let userId = authService.currentUser?.id else { return }
        isLoadingPayoutStatus = true
        payoutStatusFailed = false
        do {
            payoutStatus = try await PaymentsService.stripeAccount(userId: userId)
        } catch {
            payoutStatusFailed = true
        }
        isLoadingPayoutStatus = false
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
                
                // Every community starts free; a paid price is set through setCommunityPrice afterwards
                try await communityService.createCommunity(community)
                
                let createdName = community.name
                if isPaid, let price = self.price {
                    do {
                        try await PaymentsService.setCommunityPrice(
                            communityId: community.id,
                            isPaid: true,
                            priceMonthly: price,
                            trialDays: trialDays
                        )
                        successMessage = "\(createdName) is ready at \(CommunityPricing.format(price))/mo. Share it with traders who want your callouts."
                    } catch {
                        let reason = CloudFunctions.friendlyMessage(for: error)
                        successMessage = "\(createdName) was created as a free community. We couldn't set the price: \(reason) You can set it later in community settings."
                    }
                } else {
                    successMessage = "\(createdName) is ready. Invite traders to join you."
                }

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
        isPaid = false
        priceText = ""
        trialDays = 0
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
            return .marketRed
        } else if remaining < 50 {
            return .warning
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
            return .marketRed
        } else if remaining < 10 {
            return .warning
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

