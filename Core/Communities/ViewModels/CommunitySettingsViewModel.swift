// File: Core/Communities/ViewModels/CommunitySettingsViewModel.swift
// Simple Community Settings ViewModel

import Foundation
import Firebase
import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import Combine
import PhotosUI

@MainActor
class CommunitySettingsViewModel: ObservableObject {
    @Published var settings: CommunitySettings
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showingDeleteConfirmation = false
    
    // Member management
    @Published var members: [CommunityMemberWithRole] = []
    @Published var isLoadingMembers = false
    @Published var selectedMemberForRemoval: CommunityMemberWithRole?
    
    // Community rules and moderation
    @Published var communityRules: [CommunityRule] = []
    @Published var moderationSettings = CommunityModerationSettings()
    @Published var isLoadingRules = false
    @Published var showingAddRule = false
    
    // Image handling properties
    @Published var selectedAvatarItem: PhotosPickerItem?
    @Published var selectedBannerItem: PhotosPickerItem?
    @Published var avatarImage: UIImage?
    @Published var bannerImage: UIImage?
    @Published var isUploadingAvatar = false
    @Published var isUploadingBanner = false
    @Published var avatarUploadProgress: Double = 0
    @Published var bannerUploadProgress: Double = 0
    @Published var showingImagePicker = false
    @Published var imagePickerType: ImagePickerType = .avatar

    // Pricing (owner only). Saved through the setCommunityPrice function, never written directly.
    @Published var pricingIsPaid: Bool
    @Published var pricingPriceText: String
    @Published var pricingTrialDays: Int
    @Published var payoutStatus: StripeAccountStatus?
    @Published var isSavingPricing = false
    @Published var pricingError: String?
    @Published var pricingSaved = false
    /// The saved pricing, updated after a successful save
    @Published private(set) var savedIsPaid: Bool
    @Published private(set) var savedPrice: Double?
    @Published private(set) var savedTrialDays: Int
    
    private let community: Community
    private let communityService = CommunityFirebaseService.shared
    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(community: Community) {
        self.community = community
        self.settings = CommunitySettings(from: community)
        self.pricingIsPaid = community.isPaid
        self.pricingPriceText = CommunityPricing.inputText(for: community.priceMonthly)
        self.pricingTrialDays = community.trialDays
        self.savedIsPaid = community.isPaid
        self.savedPrice = community.priceMonthly
        self.savedTrialDays = community.trialDays
        
        // Set up image selection handlers
        setupImageHandlers()
    }
    
    // MARK: - Image Selection Setup
    private func setupImageHandlers() {
        $selectedAvatarItem
            .sink { [weak self] item in
                if item != nil {
                    self?.handleAvatarSelection()
                }
            }
            .store(in: &cancellables)
        
        $selectedBannerItem
            .sink { [weak self] item in
                if item != nil {
                    self?.handleBannerSelection()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Validation
    var canSave: Bool {
        !settings.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !settings.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        settings.name.count >= 3 &&
        settings.description.count >= 10
    }
    
    var isOwner: Bool {
        guard let currentUser = authService.currentUser else { return false }
        return community.createdBy == currentUser.id
    }
    
    // MARK: - Image Upload Methods
    
    /// Upload community avatar image
    func uploadAvatarImage() async {
        guard let avatarImage = avatarImage else { return }
        
        isUploadingAvatar = true
        avatarUploadProgress = 0
        errorMessage = ""
        
        do {
            let avatarURL = try await uploadImageToStorage(
                image: avatarImage,
                path: "community_images/\(community.id)_avatar_\(Date().timeIntervalSince1970).jpg",
                compressionQuality: 0.8,
                maxSize: CGSize(width: 512, height: 512),
                isAvatar: true
            )
            
            // Update settings
            settings.avatarURL = avatarURL
            
            // Auto-save if owner
            if isOwner {
                await updateCommunity()
            }
            
        } catch {
            errorMessage = "Failed to upload avatar: \(error.localizedDescription)"
        }
        
        isUploadingAvatar = false
    }

    /// Upload community banner image
    func uploadBannerImage() async {
        guard let bannerImage = bannerImage else { return }
        
        isUploadingBanner = true
        bannerUploadProgress = 0
        errorMessage = ""
        
        do {
            let bannerURL = try await uploadImageToStorage(
                image: bannerImage,
                path: "community_images/\(community.id)_banner_\(Date().timeIntervalSince1970).jpg",
                compressionQuality: 0.9,
                maxSize: CGSize(width: 1200, height: 400),
                isAvatar: false
            )
            
            // Update settings
            settings.bannerURL = bannerURL
            
            // Auto-save if owner
            if isOwner {
                await updateCommunity()
            }
            
        } catch {
            errorMessage = "Failed to upload banner: \(error.localizedDescription)"
        }
        
        isUploadingBanner = false
    }

    /// Generic image upload method
    private func uploadImageToStorage(
        image: UIImage,
        path: String,
        compressionQuality: CGFloat = 0.8,
        maxSize: CGSize,
        isAvatar: Bool
    ) async throws -> String {
        
        // Resize and compress image
        let resizedImage = resizeImage(image, to: maxSize)
        guard let imageData = resizedImage.jpegData(compressionQuality: compressionQuality) else {
            throw ImageUploadError.compressionFailed
        }
        
        // Validate file size (max 5MB for avatar, 8MB for banner)
        let maxBytes = isAvatar ? 5 * 1024 * 1024 : 8 * 1024 * 1024
        guard imageData.count <= maxBytes else {
            throw ImageUploadError.fileTooLarge
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference().child(path)
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload with progress monitoring using continuation
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
            let uploadTask = storageRef.putData(imageData, metadata: metadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let metadata = metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: ImageUploadError.uploadFailed)
                }
            }
            
            // Monitor progress
            uploadTask.observe(.progress) { [weak self] snapshot in
                guard let progress = snapshot.progress else { return }
                let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                
                Task { @MainActor in
                    if isAvatar {
                        self?.avatarUploadProgress = percentComplete
                    } else {
                        self?.bannerUploadProgress = percentComplete
                    }
                }
            }
        }
        
        // Get download URL
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    /// Remove community avatar
    func removeAvatar() async {
        guard isOwner, let currentAvatarURL = settings.avatarURL else { return }
        
        isLoading = true
        
        do {
            // Remove from storage
            try await deleteImageFromStorage(url: currentAvatarURL)
            
            // Update settings
            settings.avatarURL = nil
            avatarImage = nil
            
            // Save changes
            await updateCommunity()
            
        } catch {
            errorMessage = "Failed to remove avatar: \(error.localizedDescription)"
        }
        
        isLoading = false
    }

    /// Remove community banner
    func removeBanner() async {
        guard isOwner, let currentBannerURL = settings.bannerURL else { return }
        
        isLoading = true
        
        do {
            // Remove from storage
            try await deleteImageFromStorage(url: currentBannerURL)
            
            // Update settings
            settings.bannerURL = nil
            bannerImage = nil
            
            // Save changes
            await updateCommunity()
            
        } catch {
            errorMessage = "Failed to remove banner: \(error.localizedDescription)"
        }
        
        isLoading = false
    }

    /// Delete image from Firebase Storage
    private func deleteImageFromStorage(url: String) async throws {
        let storage = Storage.storage()
        let storageRef = storage.reference(forURL: url)
        try await storageRef.delete()
    }
    
    // MARK: - Image Picker Handling

    /// Handle avatar image selection
    func handleAvatarSelection() {
        guard let selectedAvatarItem = selectedAvatarItem else { return }
        
        Task {
            do {
                if let data = try await selectedAvatarItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    
                    // Validate image
                    if validateImage(image, for: .avatar) {
                        await MainActor.run {
                            self.avatarImage = image
                        }
                        await uploadAvatarImage()
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load avatar image: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Handle banner image selection
    func handleBannerSelection() {
        guard let selectedBannerItem = selectedBannerItem else { return }
        
        Task {
            do {
                if let data = try await selectedBannerItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    
                    // Validate image
                    if validateImage(image, for: .banner) {
                        await MainActor.run {
                            self.bannerImage = image
                        }
                        await uploadBannerImage()
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load banner image: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Open image picker for specific type
    func openImagePicker(for type: ImagePickerType) {
        imagePickerType = type
        showingImagePicker = true
    }

    // MARK: - Image Validation

    /// Validate uploaded image
    private func validateImage(_ image: UIImage, for type: ImagePickerType) -> Bool {
        let maxSize: CGFloat = 10 * 1024 * 1024 // 10MB in bytes
        
        guard let imageData = image.jpegData(compressionQuality: 1.0),
              imageData.count <= Int(maxSize) else {
            errorMessage = "Image is too large. Maximum size is 10MB."
            return false
        }
        
        // Check dimensions
        switch type {
        case .avatar:
            // Avatar should be square-ish
            let ratio = image.size.width / image.size.height
            if ratio < 0.8 || ratio > 1.2 {
                errorMessage = "Avatar should be square or nearly square (1:1 ratio)."
                return false
            }
        case .banner:
            // Banner should be wide
            let ratio = image.size.width / image.size.height
            if ratio < 2.0 {
                errorMessage = "Banner should be wide format (at least 2:1 ratio)."
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Image Helper Methods
    
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }

    // MARK: - Helper Properties

    var hasAvatarImage: Bool {
        avatarImage != nil || settings.avatarURL != nil
    }

    var hasBannerImage: Bool {
        bannerImage != nil || settings.bannerURL != nil
    }

    var isUploadingAnyImage: Bool {
        isUploadingAvatar || isUploadingBanner
    }
    
    // MARK: - Update Community
    func updateCommunity() async {
        guard canSave else {
            errorMessage = "Please fill in all required fields correctly"
            return
        }
        
        guard isOwner else {
            errorMessage = "Only the community owner can edit settings"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            // Validate name
            let nameValidation = communityService.validateCommunityName(settings.name)
            if !nameValidation.isValid {
                errorMessage = nameValidation.message
                isLoading = false
                return
            }
            
            // Validate description
            let descValidation = communityService.validateCommunityDescription(settings.description)
            if !descValidation.isValid {
                errorMessage = descValidation.message
                isLoading = false
                return
            }
            
            // Update the community
            let updatedCommunity = settings.updateCommunity(community)
            try await communityService.updateCommunity(updatedCommunity)
            
            // Success - the UI will dismiss automatically
            
        } catch {
            errorMessage = "Failed to update community: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Community Rules Management
    func loadCommunityRules() async {
        isLoadingRules = true
        
        do {
            communityRules = try await communityService.getCommunityRules(communityId: community.id)
            
            // If no rules exist, create default financial disclaimer rules
            if communityRules.isEmpty && isOwner {
                let defaultRules = CommunityRule.getDefaultTradingRules()
                try await communityService.createDefaultRules(communityId: community.id, rules: defaultRules)
                communityRules = defaultRules
            }
            
            // Sort by order
            communityRules.sort { $0.order < $1.order }
            
        } catch {
            errorMessage = "Failed to load community rules: \(error.localizedDescription)"
        }
        
        isLoadingRules = false
    }
    
    func addCustomRule(title: String, description: String, isRequired: Bool) async {
        guard isOwner else {
            errorMessage = "Only the community owner can add rules"
            return
        }
        
        let newOrder = (communityRules.map { $0.order }.max() ?? 0) + 1
        let customRule = CommunityRule(
            title: title,
            description: description,
            isRequired: isRequired,
            order: newOrder,
            isDefault: false
        )
        
        do {
            try await communityService.addCommunityRule(communityId: community.id, rule: customRule)
            communityRules.append(customRule)
            communityRules.sort { $0.order < $1.order }
        } catch {
            errorMessage = "Failed to add rule: \(error.localizedDescription)"
        }
    }
    
    func deleteRule(_ rule: CommunityRule) async {
        guard isOwner else {
            errorMessage = "Only the community owner can delete rules"
            return
        }
        
        guard !rule.isDefault else {
            errorMessage = "Cannot delete default financial disclaimer rules"
            return
        }
        
        do {
            try await communityService.deleteCommunityRule(communityId: community.id, ruleId: rule.id)
            communityRules.removeAll { $0.id == rule.id }
        } catch {
            errorMessage = "Failed to delete rule: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Delete Community
    func deleteCommunity() async {
        guard isOwner else {
            errorMessage = "Only the community owner can delete the community"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            try await communityService.deleteCommunity(communityId: community.id)
            // Success - the UI will handle navigation
        } catch {
            errorMessage = "Failed to delete community: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Helper Methods
    func resetSettings() {
        settings = CommunitySettings(from: community)
        errorMessage = ""
    }
    
    var hasChanges: Bool {
        settings.name != community.name ||
        settings.description != community.description ||
        settings.isPrivate != community.isPrivate ||
        settings.avatarURL != community.avatarURL ||
        settings.bannerURL != community.bannerURL
    }
    
    // MARK: - Pricing

    var canChargeMembers: Bool { payoutStatus?.chargesEnabled == true }

    var pricingPrice: Double? { CommunityPricing.parsePrice(pricingPriceText) }

    var pricingValidationMessage: String? {
        guard pricingIsPaid else { return nil }
        return CommunityPricing.validationMessage(for: pricingPriceText)
    }

    var hasPricingChanges: Bool {
        if pricingIsPaid != savedIsPaid { return true }
        guard pricingIsPaid else { return false }
        return pricingPrice != savedPrice || pricingTrialDays != savedTrialDays
    }

    var canSavePricing: Bool {
        guard hasPricingChanges, !isSavingPricing else { return false }
        if pricingIsPaid {
            return canChargeMembers && pricingValidationMessage == nil
        }
        return true
    }

    func loadPayoutStatus() async {
        guard isOwner, let userId = authService.currentUser?.id else { return }
        payoutStatus = try? await PaymentsService.stripeAccount(userId: userId)
    }

    func savePricing() async {
        guard isOwner, canSavePricing else { return }
        isSavingPricing = true
        pricingError = nil
        pricingSaved = false
        do {
            let price = pricingIsPaid ? pricingPrice : nil
            try await PaymentsService.setCommunityPrice(
                communityId: community.id,
                isPaid: pricingIsPaid,
                priceMonthly: price,
                trialDays: pricingIsPaid ? pricingTrialDays : 0
            )
            savedIsPaid = pricingIsPaid
            savedPrice = price
            savedTrialDays = pricingIsPaid ? pricingTrialDays : 0
            pricingSaved = true
        } catch {
            pricingError = CloudFunctions.friendlyMessage(for: error)
        }
        isSavingPricing = false
    }

    // MARK: - Member Management
    func loadMembers() async {
        isLoadingMembers = true
        errorMessage = ""
        
        do {
            members = try await communityService.getCommunityMembersWithRoles(communityId: community.id)
        } catch {
            errorMessage = "Failed to load members: \(error.localizedDescription)"
        }
        
        isLoadingMembers = false
    }
    
    func removeMember(_ member: CommunityMemberWithRole) async {
        guard isOwner else {
            errorMessage = "Only the community owner can remove members"
            return
        }
        
        guard member.role != .owner else {
            errorMessage = "Cannot remove the community owner"
            return
        }
        
        isLoading = true
        
        do {
            try await communityService.removeMemberFromCommunity(
                communityId: community.id,
                userId: member.userId
            )
            
            // Remove from local list
            members.removeAll { $0.id == member.id }
            
        } catch {
            errorMessage = "Failed to remove member: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateMemberRole(_ member: CommunityMemberWithRole, to newRole: CommunityRole) async {
        guard isOwner else {
            errorMessage = "Only the community owner can change member roles"
            return
        }
        
        guard member.role != .owner else {
            errorMessage = "Cannot change the owner's role"
            return
        }
        
        isLoading = true
        
        do {
            try await communityService.updateMemberRole(
                communityId: community.id,
                userId: member.userId,
                newRole: newRole
            )
            
            // Update local list
            if let index = members.firstIndex(where: { $0.id == member.id }) {
                members[index] = CommunityMemberWithRole(
                    userId: member.userId,
                    username: member.username,
                    fullName: member.fullName,
                    role: newRole,
                    joinedAt: member.joinedAt
                )
            }
            
        } catch {
            errorMessage = "Failed to update member role: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Types

enum ImagePickerType {
    case avatar
    case banner
}

enum ImageUploadError: LocalizedError {
    case compressionFailed
    case fileTooLarge
    case invalidFormat
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .fileTooLarge:
            return "Image file is too large"
        case .invalidFormat:
            return "Invalid image format"
        case .uploadFailed:
            return "Failed to upload image"
        }
    }
}
