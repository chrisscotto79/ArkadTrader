// File: Core/Onboarding/OnboardingView.swift
// Shown after registering (or for any account with onboardingCompleted == false).
// Four calm steps with a progress bar: experience, interests, suggested communities,
// notifications. Every step can be skipped.

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @ObservedObject private var pushManager = PushNotificationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ZStack {
                stepContent
                    .id(viewModel.step)
                    .transition(AnyTransition.asymmetric(
                        insertion: AnyTransition.opacity.combined(with: AnyTransition.offset(x: 24)),
                        removal: AnyTransition.opacity.combined(with: AnyTransition.offset(x: -24))
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            bottomBar
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .screenBackground()
        .disabled(viewModel.isSaving)
        .task { await pushManager.refreshAuthorizationStatus() }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: DS.Spacing.m) {
            HStack {
                IconButton(systemName: "chevron.left", accessibilityLabel: "Back", size: 36) {
                    withAnimation(.snappy(duration: 0.35)) { viewModel.back() }
                }
                .opacity(viewModel.isFirstStep ? 0 : 1)
                .disabled(viewModel.isFirstStep)

                Spacer()

                Text("Step \(viewModel.stepNumber) of \(viewModel.stepCount)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())

                Spacer()

                Button("Skip") {
                    Task { await viewModel.skip() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
            }

            OnboardingProgressBar(current: viewModel.stepNumber, total: viewModel.stepCount)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.s)
        .padding(.bottom, DS.Spacing.l)
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .experience:
            OnboardingStepScroll(
                title: "How much have you traded?",
                subtitle: "We'll tailor Arkad to where you are. You can change this later."
            ) {
                VStack(spacing: DS.Spacing.m) {
                    ForEach(TradingExperience.allCases) { level in
                        ExperienceOptionCard(
                            level: level,
                            isSelected: viewModel.experienceLevel == level
                        ) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.snappy(duration: 0.2)) {
                                viewModel.experienceLevel = level
                            }
                        }
                    }
                }
            }

        case .interests:
            OnboardingStepScroll(
                title: "What do you want to trade?",
                subtitle: "Pick as many as you like. We'll suggest communities to match."
            ) {
                OnboardingFlowLayout(spacing: DS.Spacing.s) {
                    ForEach(CommunityType.allCases, id: \.self) { type in
                        Chip(
                            title: type.displayName,
                            systemImage: type.onboardingIcon,
                            isSelected: viewModel.interests.contains(type)
                        ) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.snappy(duration: 0.2)) {
                                viewModel.toggleInterest(type)
                            }
                        }
                    }
                }
            }

        case .communities:
            OnboardingStepScroll(
                title: "Communities for you",
                subtitle: "Join a few to see callouts and chat. You can leave any time."
            ) {
                communitiesList
            }

        case .notifications:
            notificationsStep
        }
    }

    @ViewBuilder
    private var communitiesList: some View {
        if viewModel.isLoadingSuggestions && viewModel.suggestions.isEmpty {
            ProgressView()
                .tint(Color.goldText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        } else if let error = viewModel.suggestionsError {
            EmptyStateView(
                systemImage: "wifi.exclamationmark",
                title: "Couldn't load communities",
                message: error,
                actionTitle: "Try again"
            ) {
                Task { await viewModel.loadSuggestions() }
            }
        } else if viewModel.suggestions.isEmpty {
            EmptyStateView(
                systemImage: "person.3.fill",
                title: "No matches yet",
                message: "There aren't any public communities for these interests yet. You can browse or start one from the Communities tab."
            )
        } else {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.suggestions.enumerated()), id: \.element.id) { index, community in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.hairline)
                            .frame(height: 1)
                            .padding(.leading, DS.Spacing.l + 48 + DS.Spacing.m)
                    }
                    SuggestedCommunityRow(
                        community: community,
                        isJoined: viewModel.joinedIds.contains(community.id),
                        isJoining: viewModel.joiningIds.contains(community.id)
                    ) {
                        Task { await viewModel.join(community) }
                    }
                }
            }
            .cardStyle(padding: 0)
        }
    }

    private var notificationsStep: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                IconWell(systemName: "bell.badge.fill", size: 88)
                    .padding(.top, DS.Spacing.xxl)

                VStack(spacing: DS.Spacing.s) {
                    Text(usesRemotePush ? "Stay in the loop" : "Get price alerts")
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text(usesRemotePush
                         ? "Get a heads-up when it matters. You choose exactly what in Settings."
                         : "Allow notifications so Arkad can tell you when a price crosses a target you set.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    if usesRemotePush {
                        benefitRow(icon: "megaphone.fill", text: "New callouts in your communities")
                        benefitRow(icon: "bubble.left.fill", text: "Replies and mentions")
                        benefitRow(icon: "bell.badge.fill", text: "Price alerts you set")
                    } else {
                        benefitRow(icon: "bell.badge.fill", text: "A banner when a price alert triggers")
                        benefitRow(icon: "clock.badge.checkmark", text: "Alerts are checked while Arkad is open")
                        benefitRow(icon: "tray.fill", text: "Callouts, replies and new followers wait in your inbox")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Remote push needs Cloud Functions. In free mode only price alerts use notifications.
    private var usesRemotePush: Bool { AppConfig.serverFunctionsEnabled }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: icon, size: 32)
            Text(text)
                .font(.subheadline.weight(.medium))
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: DS.Spacing.s) {
            if viewModel.step == .notifications {
                if pushManager.authorizationStatus == .notDetermined {
                    Button {
                        Task { await viewModel.finish(enableNotifications: true) }
                    } label: {
                        saveLabel(usesRemotePush ? "Turn on notifications" : "Get price alerts")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Not now") {
                        Task { await viewModel.finish(enableNotifications: false) }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                } else {
                    Button {
                        Task { await viewModel.finish(enableNotifications: false) }
                    } label: {
                        saveLabel("Start using Arkad")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                Button("Continue") {
                    withAnimation(.snappy(duration: 0.35)) { viewModel.next() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!viewModel.canContinue)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.m)
        .padding(.bottom, DS.Spacing.l)
        .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func saveLabel(_ title: String) -> some View {
        if viewModel.isSaving {
            ProgressView().tint(Color.onGold)
        } else {
            Text(title)
        }
    }
}

// MARK: - Building blocks

/// Gold segments, one per step, filled up to the current one.
private struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.arkadGold : Color.surfaceRaised)
                    .frame(height: 4)
            }
        }
        .animation(.snappy(duration: 0.35), value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

/// Large title, subtitle and the step's content, scrollable.
private struct OnboardingStepScroll<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct ExperienceOptionCard: View {
    let level: TradingExperience
    let isSelected: Bool
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.m) {
                IconWell(systemName: level.systemImage, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text(level.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: DS.Spacing.s)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.goldText : Color.secondary.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(DS.Spacing.l)
            .background {
                ZStack {
                    shape.fill(Color.surface)
                    shape.fill(Color.goldTint).opacity(isSelected ? 1 : 0)
                }
            }
            .overlay(
                shape.strokeBorder(isSelected ? Color.goldText : Color.hairline, lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SuggestedCommunityRow: View {
    let community: Community
    let isJoined: Bool
    let isJoining: Bool
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            CommunityAvatar(community: community, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(community.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text("\(community.type.shortDisplayName) · \(memberText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !community.description.isEmpty {
                    Text(community.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: DS.Spacing.s)

            joinButton
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
    }

    private var memberText: String {
        community.memberCount == 1 ? "1 member" : "\(community.memberCount) members"
    }

    @ViewBuilder
    private var joinButton: some View {
        if isJoined {
            Label("Joined", systemImage: "checkmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
                .frame(height: 34)
        } else {
            Button(action: onJoin) {
                if isJoining {
                    ProgressView()
                        .tint(Color.onGold)
                        .frame(width: 36)
                } else {
                    Text("Join")
                }
            }
            .buttonStyle(PillButtonStyle(kind: .gold))
            .disabled(isJoining)
            .accessibilityLabel("Join \(community.name)")
        }
    }
}

/// Lays chips out in rows, wrapping to the next line when a row is full.
private struct OnboardingFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width
            widest = max(widest, x)
            x += spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private extension CommunityType {
    var onboardingIcon: String {
        switch self {
        case .general: return "person.3"
        case .dayTrading: return "chart.line.uptrend.xyaxis"
        case .swingTrading: return "chart.bar"
        case .options: return "option"
        case .crypto: return "bitcoinsign.circle"
        case .stocks: return "building.columns"
        }
    }
}

#Preview {
    OnboardingView()
}
