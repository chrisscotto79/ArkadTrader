// File: Core/Onboarding/OnboardingViewModel.swift
// State for the four onboarding steps: experience, interests, suggested communities and
// notifications. Answers are saved to users/{uid} (docs/backend-contracts.md, section 7).

import Foundation
import SwiftUI

/// How much trading experience the user says they have. Raw values are stored in
/// `users/{uid}.experienceLevel`.
enum TradingExperience: String, CaseIterable, Identifiable {
    case new
    case intermediate
    case experienced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .new: return "New to trading"
        case .intermediate: return "Some experience"
        case .experienced: return "Experienced"
        }
    }

    var subtitle: String {
        switch self {
        case .new: return "I'm just getting started"
        case .intermediate: return "I trade now and then"
        case .experienced: return "I trade often and know my setups"
        }
    }

    var systemImage: String {
        switch self {
        case .new: return "leaf.fill"
        case .intermediate: return "chart.line.uptrend.xyaxis"
        case .experienced: return "flame.fill"
        }
    }
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case experience, interests, communities, notifications
    }

    @Published private(set) var step: Step = .experience
    @Published var experienceLevel: TradingExperience?
    @Published var interests: Set<CommunityType> = []

    // Suggested communities
    @Published private(set) var suggestions: [Community] = []
    @Published private(set) var isLoadingSuggestions = false
    @Published private(set) var suggestionsError: String?
    @Published private(set) var joinedIds: Set<String> = []
    @Published private(set) var joiningIds: Set<String> = []

    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let authService = FirebaseAuthService.shared
    private let communityService = CommunityFirebaseService.shared
    private var loadedInterests: Set<CommunityType>?

    static let suggestionLimit = 8

    // MARK: - Progress

    var stepNumber: Int { step.rawValue + 1 }
    var stepCount: Int { Step.allCases.count }
    var isFirstStep: Bool { step == .experience }

    var canContinue: Bool {
        switch step {
        case .experience: return experienceLevel != nil
        case .interests: return !interests.isEmpty
        case .communities, .notifications: return true
        }
    }

    // MARK: - Navigation

    func next() {
        guard canContinue, let following = Step(rawValue: step.rawValue + 1) else { return }
        step = following
        if following == .communities, loadedInterests != interests {
            Task { await loadSuggestions() }
        }
    }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func toggleInterest(_ type: CommunityType) {
        if interests.contains(type) {
            interests.remove(type)
        } else {
            interests.insert(type)
        }
    }

    // MARK: - Suggested communities

    /// Public communities matching the chosen interests, most active first.
    func loadSuggestions() async {
        guard let user = authService.currentUser else { return }
        isLoadingSuggestions = true
        suggestionsError = nil
        let wanted = interests

        do {
            let communities = try await communityService.loadDiscoveryCommunities(limit: 50)
            joinedIds.formUnion(user.communityIds)
            suggestions = Array(
                communities
                    .filter { !$0.isPrivate && !$0.requiresSubscription && $0.createdBy != user.id }
                    .filter { wanted.isEmpty || wanted.contains($0.type) }
                    .sorted { $0.discoveryScore > $1.discoveryScore }
                    .prefix(Self.suggestionLimit)
            )
            loadedInterests = wanted
        } catch {
            suggestionsError = "Check your connection and try again."
        }
        isLoadingSuggestions = false
    }

    func join(_ community: Community) async {
        guard let userId = authService.currentUser?.id,
              !joinedIds.contains(community.id),
              !joiningIds.contains(community.id) else { return }

        joiningIds.insert(community.id)
        do {
            try await communityService.joinCommunity(communityId: community.id, userId: userId)
            joinedIds.insert(community.id)
            if authService.currentUser?.communityIds.contains(community.id) == false {
                authService.currentUser?.communityIds.append(community.id)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = "Couldn't join \(community.name). Please try again."
        }
        joiningIds.remove(community.id)
    }

    // MARK: - Finish

    /// Last step. Optionally asks for notification permission (in free mode only price alerts
    /// use it, as local notifications), then saves the answers.
    func finish(enableNotifications: Bool) async {
        if enableNotifications {
            await PushNotificationManager.shared.requestAuthorization()
        }
        await save()
    }

    /// Saves whatever has been answered so far and leaves onboarding.
    func skip() async {
        await save()
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        do {
            try await authService.completeOnboarding(
                experienceLevel: experienceLevel?.rawValue,
                interests: CommunityType.allCases.filter { interests.contains($0) }.map(\.rawValue)
            )
        } catch {
            // The app has already moved on (the local profile is updated first). If the write
            // failed, onboarding simply shows again next time.
        }
        isSaving = false
    }
}
