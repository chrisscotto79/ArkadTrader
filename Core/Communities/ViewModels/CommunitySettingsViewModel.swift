// File: Core/Communities/ViewModels/CommunitySettingsViewModel.swift
// Community settings: details (saved field by field), images, rules, the private invite code,
// pricing (paid mode only) and deleting the community. Members are managed in the members sheet.

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
    /// The details as last saved, so "Done" knows what changed
    @Published private(set) var savedSettings: CommunitySettings

    // Invite code (private communities, owner only)
    @Published private(set) var inviteCode: String?
    @Published private(set) var isLoadingInvite = false
    @Published var inviteError: String?

    // Community rules and moderation
    @Published var communityRules: [CommunityRule] = []
    @Published var isLoadingRules = false
    @Published var showingAddRule = false
    
    // Image handling properties
    @Published var selectedAvatarItem: PhotosPickerItem?
    @Published var selectedBannerItem: PhotosPickerItem?
    @Published var avatarImage: UIImage?
    @Published var bannerImage: UIImage?
    @Published var isUploadingAvatar = false
    @Published var isUploadingBanner = false

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
        self.savedSettings = CommunitySettings(from: community)
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
        // @Published emits before the property changes, so the new item is passed along.
        $selectedAvatarItem
            .sink { [weak self] item in
                if let item {
                    self?.handleAvatarSelection(item)
                }
            }
            .store(in: &cancellables)
        
        $selectedBannerItem
            .sink { [weak self] item in
                if let item {
                    self?.handleBannerSelection(item)
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
    //
    // Free mode: images are Firestore docs (`images/community_avatar_{cid}` and
    // `images/community_banner_{cid}`) written through ImageStore. The rules only allow it for
    // the community owner. Only the one URL field is written to the community doc, so unsaved
    // edits to the name or description aren't saved along with it.

    /// Upload community avatar image
    func uploadAvatarImage() async {
        guard let avatarImage = avatarImage else { return }
        guard isOwner else {
            errorMessage = "Only the community owner can change the avatar"
            return
        }

        isUploadingAvatar = true
        errorMessage = ""

        do {
            let avatarURL = try await ImageStore.shared.uploadCommunityAvatar(avatarImage, communityId: community.id)
            try await saveImageField("avatarURL", value: avatarURL)
            settings.avatarURL = avatarURL
        } catch {
            errorMessage = "Failed to upload avatar: \(error.localizedDescription)"
        }

        isUploadingAvatar = false
    }

    /// Upload community banner image
    func uploadBannerImage() async {
        guard let bannerImage = bannerImage else { return }
        guard isOwner else {
            errorMessage = "Only the community owner can change the banner"
            return
        }

        isUploadingBanner = true
        errorMessage = ""

        do {
            let bannerURL = try await ImageStore.shared.uploadCommunityBanner(bannerImage, communityId: community.id)
            try await saveImageField("bannerURL", value: bannerURL)
            settings.bannerURL = bannerURL
        } catch {
            errorMessage = "Failed to upload banner: \(error.localizedDescription)"
        }

        isUploadingBanner = false
    }

    /// Remove community avatar
    func removeAvatar() async {
        guard isOwner else { return }
        let currentAvatarURL = settings.avatarURL

        isLoading = true
        errorMessage = ""

        do {
            try await saveImageField("avatarURL", value: nil)
            settings.avatarURL = nil
            avatarImage = nil
            selectedAvatarItem = nil
            await deleteStoredImage(currentAvatarURL, fallbackId: ImageStore.communityAvatarId(communityId: community.id))
        } catch {
            errorMessage = "Failed to remove avatar: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Remove community banner
    func removeBanner() async {
        guard isOwner else { return }
        let currentBannerURL = settings.bannerURL

        isLoading = true
        errorMessage = ""

        do {
            try await saveImageField("bannerURL", value: nil)
            settings.bannerURL = nil
            bannerImage = nil
            selectedBannerItem = nil
            await deleteStoredImage(currentBannerURL, fallbackId: ImageStore.communityBannerId(communityId: community.id))
        } catch {
            errorMessage = "Failed to remove banner: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Writes (or, for nil, removes) one image field on the community doc.
    private func saveImageField(_ field: String, value: String?) async throws {
        let fieldValue: Any = value.map { $0 as Any } ?? FieldValue.delete()
        try await FirebaseServices.shared.db.collection("communities").document(community.id)
            .updateData([field: fieldValue])
    }

    /// Best-effort cleanup of the removed image: the Firestore image doc, or a legacy
    /// Cloud Storage file when Storage is available.
    private func deleteStoredImage(_ urlString: String?, fallbackId: String) async {
        do {
            if let imageId = ImageStore.imageId(from: urlString) {
                try await ImageStore.shared.deleteImage(id: imageId)
            } else if let urlString, AppConfig.mediaUploadsEnabled,
                      urlString.hasPrefix("https://firebasestorage.googleapis.com") || urlString.hasPrefix("gs://") {
                // reference(forURL:) raises on anything that isn't a Storage URL
                try await Storage.storage().reference(forURL: urlString).delete()
            } else {
                try await ImageStore.shared.deleteImage(id: fallbackId)
            }
        } catch {
            // Best-effort: a leftover image doc isn't shown anywhere
        }
    }

    // MARK: - Image Picker Handling

    /// Handle avatar image selection
    func handleAvatarSelection(_ selectedAvatarItem: PhotosPickerItem) {
        
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
    func handleBannerSelection(_ selectedBannerItem: PhotosPickerItem) {
        
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

    // MARK: - Image Validation

    /// Avatars are centre-cropped to a square and every image is resized before upload,
    /// so only the banner's shape is checked.
    private func validateImage(_ image: UIImage, for type: ImagePickerType) -> Bool {
        guard image.size.width >= 1, image.size.height >= 1 else {
            errorMessage = "This image couldn't be read. Try a different one."
            return false
        }

        switch type {
        case .avatar:
            break
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

    /// Saves only the details that changed (name, description, privacy). Returns true on success.
    @discardableResult
    func updateCommunity() async -> Bool {
        guard canSave else {
            errorMessage = "Please fill in all required fields correctly"
            return false
        }
        guard isOwner else {
            errorMessage = "Only the community owner can edit settings"
            return false
        }

        let name = settings.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = settings.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = name != savedSettings.name
        let descriptionChanged = description != savedSettings.description
        let privacyChanged = settings.isPrivate != savedSettings.isPrivate
        guard nameChanged || descriptionChanged || privacyChanged else { return true }

        if nameChanged {
            let nameValidation = communityService.validateCommunityName(name)
            guard nameValidation.isValid else {
                errorMessage = nameValidation.message
                return false
            }
        }
        if descriptionChanged {
            let descValidation = communityService.validateCommunityDescription(description)
            guard descValidation.isValid else {
                errorMessage = descValidation.message
                return false
            }
        }

        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        do {
            // A new name (not just new capitals) must not belong to another public community
            if nameChanged,
               Community.normalizedName(name) != Community.normalizedName(savedSettings.name),
               !(try await communityService.isNameAvailable(name)) {
                errorMessage = "Another community already uses that name."
                return false
            }
            try await communityService.updateCommunityDetails(
                communityId: community.id,
                name: nameChanged ? name : nil,
                description: descriptionChanged ? description : nil,
                isPrivate: privacyChanged ? settings.isPrivate : nil
            )
            settings.name = name
            settings.description = description
            savedSettings.name = name
            savedSettings.description = description
            savedSettings.isPrivate = settings.isPrivate
            if privacyChanged && settings.isPrivate {
                await loadInvite()
            }
            return true
        } catch {
            errorMessage = "Couldn't save your changes. Check your connection and try again."
            return false
        }
    }

    // MARK: - Invite code

    /// Invite docs can't be listed, so this phone remembers the code it made
    private var inviteDefaultsKey: String? {
        authService.currentUser.map { "communityInvite.\(community.id).\($0.id)" }
    }

    /// The owner's invite code for a private community: the one this phone made (if it still
    /// works), otherwise a new one.
    func loadInvite() async {
        guard isOwner, savedSettings.isPrivate, let userId = authService.currentUser?.id,
              let key = inviteDefaultsKey else { return }
        isLoadingInvite = true
        inviteError = nil
        defer { isLoadingInvite = false }
        do {
            if let stored = UserDefaults.standard.string(forKey: key),
               (try? await FirebaseServices.shared.communityId(forInviteCode: stored)) == community.id {
                inviteCode = stored
                return
            }
            let code = try await FirebaseServices.shared.createCommunityInvite(communityId: community.id, createdBy: userId)
            UserDefaults.standard.set(code, forKey: key)
            inviteCode = code
        } catch {
            inviteError = "Couldn't load the invite code. Try again."
        }
    }

    /// A fresh code; the old one stops working.
    func regenerateInvite() async {
        guard isOwner, let userId = authService.currentUser?.id, let key = inviteDefaultsKey else { return }
        isLoadingInvite = true
        inviteError = nil
        defer { isLoadingInvite = false }
        do {
            let code = try await FirebaseServices.shared.regenerateCommunityInvite(
                communityId: community.id, userId: userId, replacing: inviteCode
            )
            UserDefaults.standard.set(code, forKey: key)
            inviteCode = code
        } catch {
            inviteError = "Couldn't make a new code. Try again."
        }
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
    /// Returns true when the community is gone.
    @discardableResult
    func deleteCommunity() async -> Bool {
        guard isOwner else {
            errorMessage = "Only the community owner can delete the community"
            return false
        }
        
        isLoading = true
        errorMessage = ""
        
        // Its photos first (best-effort), while the community still exists
        try? await ImageStore.shared.deleteImage(id: ImageStore.communityAvatarId(communityId: community.id))
        try? await ImageStore.shared.deleteImage(id: ImageStore.communityBannerId(communityId: community.id))

        do {
            try await communityService.deleteCommunity(communityId: community.id)
            isLoading = false
            return true
        } catch {
            errorMessage = "Couldn't delete the community. Check your connection and try again."
            isLoading = false
            return false
        }
    }
    
    // MARK: - Helper Methods
    /// Undo unsaved detail edits. Images are saved as soon as they're picked, so they stay.
    func resetSettings() {
        settings.name = savedSettings.name
        settings.description = savedSettings.description
        settings.isPrivate = savedSettings.isPrivate
        errorMessage = ""
    }

    /// Unsaved edits to the details (images save on their own)
    var hasChanges: Bool {
        settings.name.trimmingCharacters(in: .whitespacesAndNewlines) != savedSettings.name ||
        settings.description.trimmingCharacters(in: .whitespacesAndNewlines) != savedSettings.description ||
        settings.isPrivate != savedSettings.isPrivate
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
        guard AppConfig.paidCommunitiesEnabled, isOwner, let userId = authService.currentUser?.id else { return }
        payoutStatus = try? await PaymentsService.stripeAccount(userId: userId)
    }

    func savePricing() async {
        guard AppConfig.paidCommunitiesEnabled, isOwner, canSavePricing else { return }
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
