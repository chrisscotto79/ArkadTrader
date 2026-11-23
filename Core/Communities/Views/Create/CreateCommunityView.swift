// File: Core/Communities/Views/Create/CreateCommunityView.swift
// Community creation flow: basics (with optional photos), category, privacy, free or paid, review.
// Photos are uploaded through ImageStore after the community doc exists. The "Free or paid?"
// step only appears when AppConfig.paidCommunitiesEnabled is on; otherwise there are four steps.
// A paid community is saved as free first, then priced with the setCommunityPrice function.

import SwiftUI
import PhotosUI

struct CreateCommunityView: View {
    @StateObject private var viewModel = CommunityCreationViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    @State private var showPayouts = false
    @State private var avatarItem: PhotosPickerItem?
    @State private var bannerItem: PhotosPickerItem?

    /// The steps in order. Pricing is left out in free mode.
    private var steps: [CreateStep] {
        AppConfig.paidCommunitiesEnabled
            ? [.basics, .category, .privacy, .pricing, .review]
            : [.basics, .category, .privacy, .review]
    }

    private var totalSteps: Int { steps.count }

    /// The step on screen (`currentStep` is 1-based)
    private var step: CreateStep { steps[min(max(currentStep, 1), totalSteps) - 1] }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressIndicator

                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        stepContent
                    }
                    .padding(.horizontal, DS.pageMargin)
                    .padding(.top, DS.Spacing.s)
                    .padding(.bottom, DS.Spacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) { actionBar }
            .navigationTitle("New Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.goldText)
                }
            }
        }
        .alert("Community created", isPresented: $viewModel.showSuccess) {
            Button("Done") {
                dismiss()
            }
        } message: {
            Text(viewModel.successMessage)
        }
        .sheet(isPresented: $showPayouts, onDismiss: {
            Task { await viewModel.loadPayoutStatus() }
        }) {
            PayoutsSheet()
        }
        .alert("Couldn't create community", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - Progress

    private var progressIndicator: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(spacing: 6) {
                ForEach(1...totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? Color.arkadGold : Color.surfaceRaised)
                        .frame(height: 4)
                }
            }
            Text("Step \(currentStep) of \(totalSteps)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.vertical, DS.Spacing.m)
        .animation(.snappy(duration: 0.25), value: currentStep)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep) of \(totalSteps)")
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .basics: basicInfoStep
        case .category: categoryStep
        case .privacy: settingsStep
        case .pricing: pricingStep
        case .review: reviewStep
        }
    }

    // MARK: Step 1 — Basics

    private var basicInfoStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            stepHeader(
                title: "Name your community",
                subtitle: "A clear name and description help the right traders find you."
            )

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                fieldLabel("Name")
                HStack(spacing: DS.Spacing.s) {
                    TextField("e.g. Morning Momentum", text: $viewModel.name)
                        .font(.body)
                        .textInputAutocapitalization(.words)
                    validationIcon(for: viewModel.nameValidation)
                }
                .padding(.horizontal, DS.Spacing.l)
                .frame(height: 52)
                .background(inputBackground)

                fieldFooter(error: viewModel.nameValidation.errorMessage,
                            count: viewModel.nameCharacterCount,
                            countColor: viewModel.nameCharacterCountColor)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                fieldLabel("Description")
                HStack(alignment: .top, spacing: DS.Spacing.s) {
                    TextField(
                        "What do you trade, who is it for and what can members expect?",
                        text: $viewModel.description,
                        axis: .vertical
                    )
                    .font(.body)
                    .lineLimit(4...8)
                    validationIcon(for: viewModel.descriptionValidation)
                }
                .padding(DS.Spacing.l)
                .background(inputBackground)

                fieldFooter(error: viewModel.descriptionValidation.errorMessage,
                            count: viewModel.characterCountText,
                            countColor: viewModel.characterCountColor)
            }

            photosSection

            tipsCard([
                "Say what you trade and on what timeframe",
                "Mention the experience level you're aiming for",
                "Keep it welcoming and professional"
            ])
        }
    }

    // MARK: Photos (optional, uploaded after the community is created)

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            fieldLabel("Photos (optional)")

            HStack(spacing: DS.Spacing.m) {
                PhotosPicker(selection: $avatarItem, matching: .images, photoLibrary: .shared()) {
                    avatarPickerPreview
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(viewModel.avatarImage == nil ? "Add a community avatar" : "Change the community avatar")

                PhotosPicker(selection: $bannerItem, matching: .images, photoLibrary: .shared()) {
                    bannerPickerPreview
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(viewModel.bannerImage == nil ? "Add a community banner" : "Change the community banner")
            }

            HStack(alignment: .firstTextBaseline) {
                if let photoError = viewModel.photoError {
                    Text(photoError)
                        .font(.caption)
                        .foregroundStyle(Color.marketRed)
                } else {
                    Text("A square avatar and a wide banner (3:1). You can change them later in settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DS.Spacing.s)
                if viewModel.avatarImage != nil || viewModel.bannerImage != nil {
                    Button("Remove") {
                        withAnimation(.snappy(duration: 0.2)) {
                            viewModel.avatarImage = nil
                            viewModel.bannerImage = nil
                            viewModel.photoError = nil
                            avatarItem = nil
                            bannerItem = nil
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.marketRed)
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, DS.Spacing.xs)
        }
        .onChange(of: avatarItem) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                withAnimation(.snappy(duration: 0.2)) { viewModel.setAvatar(from: data) }
            }
        }
        .onChange(of: bannerItem) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                withAnimation(.snappy(duration: 0.2)) { viewModel.setBanner(from: data) }
            }
        }
    }

    private var avatarPickerPreview: some View {
        let shape = RoundedRectangle(cornerRadius: 72 * 0.28, style: .continuous)
        return ZStack(alignment: .bottomTrailing) {
            if let avatarImage = viewModel.avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(Color.hairline, lineWidth: 1))
            } else {
                shape
                    .fill(Color.surfaceRaised)
                    .frame(width: 72, height: 72)
                    .overlay(shape.strokeBorder(Color.hairline, lineWidth: 1))
                    .overlay(
                        Image(systemName: "person.crop.square")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    )
            }

            Image(systemName: "camera.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.onGold)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.arkadGold))
                .overlay(Circle().strokeBorder(Color.appBackground, lineWidth: 2))
                .offset(x: 6, y: 6)
        }
        .padding(.trailing, 6)
        .padding(.bottom, 6)
    }

    private var bannerPickerPreview: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
        return ZStack {
            if let bannerImage = viewModel.bannerImage {
                Image(uiImage: bannerImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.surfaceRaised
                Label("Add a banner", systemImage: "photo.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.hairline, lineWidth: 1))
        .contentShape(shape)
        .padding(.bottom, 6)
    }

    // MARK: Step 2 — Category

    private var categoryStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            stepHeader(
                title: "Pick a focus",
                subtitle: "Your category decides where you show up in Discover. Members can still talk about anything."
            )

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: DS.Spacing.m), GridItem(.flexible(), spacing: DS.Spacing.m)],
                spacing: DS.Spacing.m
            ) {
                ForEach(CommunityType.allCases, id: \.self) { type in
                    categoryCard(type)
                }
            }
        }
    }

    private func categoryCard(_ type: CommunityType) -> some View {
        let isSelected = viewModel.type == type
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy(duration: 0.2)) { viewModel.type = type }
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                HStack {
                    IconWell(systemName: type.categoryIcon, tint: type.categoryColor, size: 36)
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.goldText : Color(.tertiaryLabel))
                }
                Text(type.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text(type.categoryDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(DS.Spacing.m + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectableBackground(isSelected: isSelected))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Step 3 — Privacy

    private var settingsStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            stepHeader(
                title: "Who can join?",
                subtitle: "You can change this later in community settings."
            )

            VStack(spacing: DS.Spacing.m) {
                privacyOption(
                    title: "Public",
                    subtitle: "Anyone can find and join your community",
                    icon: "globe",
                    isSelected: !viewModel.isPrivate,
                    action: { viewModel.isPrivate = false }
                )
                privacyOption(
                    title: "Private",
                    subtitle: "Hidden from Discover and search for anyone who isn't a member",
                    icon: "lock.fill",
                    isSelected: viewModel.isPrivate,
                    action: { viewModel.isPrivate = true }
                )
            }

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                fieldLabel("Community guidelines")
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    ForEach(viewModel.getGuidelines(), id: \.title) { guideline in
                        guidelineRow(guideline)
                    }
                }
                .cardStyle(padding: DS.Spacing.l)
            }
        }
    }

    private func privacyOption(title: String, subtitle: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy(duration: 0.2)) { action() }
        } label: {
            HStack(spacing: DS.Spacing.m) {
                IconWell(systemName: icon, tint: isSelected ? .goldText : .secondary, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: DS.Spacing.s)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.goldText : Color(.tertiaryLabel))
            }
            .padding(DS.Spacing.l)
            .background(selectableBackground(isSelected: isSelected))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func guidelineRow(_ guideline: CommunityGuideline) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            Image(systemName: guideline.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.goldText)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(guideline.title)
                    .font(.subheadline.weight(.semibold))
                Text(guideline.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Step 4 — Free or paid (paid communities only)

    private var pricingStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            stepHeader(
                title: "Free or paid?",
                subtitle: "Charge a monthly price for access, or keep it free. You can change this later."
            )

            VStack(spacing: DS.Spacing.m) {
                privacyOption(
                    title: "Free",
                    subtitle: "Anyone can join at no cost",
                    icon: "person.2.fill",
                    isSelected: !viewModel.isPaid,
                    action: { viewModel.isPaid = false }
                )
                privacyOption(
                    title: "Paid",
                    subtitle: "Members subscribe monthly through Stripe",
                    icon: "dollarsign.circle.fill",
                    isSelected: viewModel.isPaid,
                    action: { viewModel.isPaid = true }
                )
            }

            if viewModel.isPaid {
                paidSettings
            }
        }
        .task {
            if viewModel.payoutStatus == nil {
                await viewModel.loadPayoutStatus()
            }
        }
    }

    @ViewBuilder
    private var paidSettings: some View {
        if viewModel.isLoadingPayoutStatus && viewModel.payoutStatus == nil {
            HStack(spacing: DS.Spacing.m) {
                ProgressView()
                Text("Checking your payout setup…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        } else if !viewModel.canChargeMembers {
            payoutsRequiredCard
        } else {
            priceFields
        }
    }

    private var payoutsRequiredCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                IconWell(systemName: "banknote.fill", size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.payoutStatus?.stage == .inReview ? "Payouts are in review" : "Set up payouts first")
                        .font(.body.weight(.semibold))
                    Text(payoutsRequiredMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button("Set up payouts") { showPayouts = true }
                .buttonStyle(PrimaryButtonStyle())

            Button("Create as free for now") {
                withAnimation(.snappy(duration: 0.2)) { viewModel.isPaid = false }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .cardStyle()
    }

    private var payoutsRequiredMessage: String {
        if viewModel.payoutStatusFailed {
            return "We couldn't check your payout setup. Open payouts to try again, or start free and add a price later."
        }
        if viewModel.payoutStatus?.stage == .inReview {
            return "Stripe is still checking your details. Start free now and add a price in settings once you're approved."
        }
        return "Stripe pays you each month. Setup takes a few minutes, or start free and add a price later in settings."
    }

    private var priceFields: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                fieldLabel("Monthly price")
                HStack(spacing: DS.Spacing.xs) {
                    Text("$")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("9.99", text: $viewModel.priceText)
                        .keyboardType(.decimalPad)
                        .font(.body.monospacedDigit())
                    Text("/ month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.Spacing.l)
                .frame(height: 52)
                .background(inputBackground)

                if !viewModel.priceText.isEmpty, let message = viewModel.priceValidationMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.marketRed)
                        .padding(.horizontal, DS.Spacing.xs)
                } else {
                    Text("Between \(CommunityPricing.format(CommunityPricing.minimumPrice)) and \(CommunityPricing.format(CommunityPricing.maximumPrice)) a month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.xs)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                fieldLabel("Free trial")
                HStack(spacing: DS.Spacing.s) {
                    ForEach(CommunityPricing.trialOptions, id: \.self) { days in
                        Chip(title: CommunityPricing.trialChipTitle(days), isSelected: viewModel.trialDays == days) {
                            viewModel.trialDays = days
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            if let price = viewModel.price, viewModel.priceValidationMessage == nil {
                CommunityEarningsBreakdown(price: price)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                Text(CommunityPricing.processingFeeNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Last step — Review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            stepHeader(
                title: "Ready to launch",
                subtitle: "This is how your community will appear to other traders."
            )

            previewCard

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                fieldLabel("Summary")
                VStack(spacing: 0) {
                    summaryRow("Name", viewModel.name)
                    summaryDivider
                    summaryRow("Category", viewModel.type.displayName)
                    summaryDivider
                    summaryRow("Privacy", viewModel.isPrivate ? "Private" : "Public")
                    if AppConfig.paidCommunitiesEnabled {
                        summaryDivider
                        summaryRow("Membership", membershipSummary)
                    }
                }
                .cardStyle(padding: 0)
            }
        }
    }

    private var membershipSummary: String {
        guard viewModel.isPaid, let price = viewModel.price else { return "Free" }
        let trial = viewModel.trialDays > 0 ? " · \(CommunityPricing.trialLabel(viewModel.trialDays))" : ""
        return "\(CommunityPricing.format(price))/mo\(trial)"
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            if let bannerImage = viewModel.bannerImage {
                Image(uiImage: bannerImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 96)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
            }

            HStack(spacing: DS.Spacing.m) {
                if let avatarImage = viewModel.avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 56 * 0.28, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 56 * 0.28, style: .continuous)
                                .strokeBorder(Color.hairline, lineWidth: 1)
                        )
                } else {
                    CommunityAvatar(name: viewModel.name, size: 56)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(viewModel.name.isEmpty ? "Your community" : viewModel.name)
                            .font(.headline)
                            .lineLimit(1)
                        if viewModel.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("\(viewModel.type.shortDisplayName) · 1 member")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Text(viewModel.description)
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DS.Spacing.s) {
                Tag(text: "Owner", systemImage: "crown.fill")
                Tag(text: viewModel.type.displayName, tint: viewModel.type.tint)
                if viewModel.isPaid, let price = viewModel.price {
                    Tag(text: "\(CommunityPricing.format(price))/mo")
                }
                if viewModel.isPrivate {
                    Tag(text: "Private", systemImage: "lock.fill", tint: .secondary)
                }
            }
        }
        .cardStyle(padding: DS.Spacing.l)
    }

    private var summaryDivider: some View {
        Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, DS.Spacing.l)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: DS.Spacing.m) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: DS.Spacing.s)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.l)
        .frame(minHeight: 48)
    }

    // MARK: - Supporting Views

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .padding(.leading, DS.Spacing.xs)
    }

    private func fieldFooter(error: String?, count: String, countColor: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.marketRed)
            }
            Spacer(minLength: DS.Spacing.s)
            Text(count)
                .font(.caption.monospacedDigit())
                .foregroundStyle(countColor)
        }
        .padding(.horizontal, DS.Spacing.xs)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous).fill(Color.surfaceRaised)
    }

    private func selectableBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
            .fill(isSelected ? Color.goldTint : Color.surface)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .strokeBorder(isSelected ? Color.goldText : Color.hairline, lineWidth: isSelected ? 1.5 : 1)
            )
    }

    private func tipsCard(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Label("Tips", systemImage: "lightbulb.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.goldText)
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                    Circle().fill(Color.secondary).frame(width: 4, height: 4)
                    Text(tip)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: DS.Spacing.l)
    }

    @ViewBuilder
    private func validationIcon(for state: ValidationState) -> some View {
        switch state {
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.marketGreen)
                .transition(.scale.combined(with: .opacity))
        case .invalid:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.marketRed)
                .transition(.scale.combined(with: .opacity))
        case .none:
            EmptyView()
        }
    }

    // MARK: - Bottom Action Bar

    private var actionBar: some View {
        HStack(spacing: DS.Spacing.m) {
            if currentStep > 1 {
                Button("Back") {
                    withAnimation(.snappy(duration: 0.25)) { currentStep -= 1 }
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: 120)
            }

            Button {
                if currentStep == totalSteps {
                    viewModel.createCommunity()
                } else {
                    withAnimation(.snappy(duration: 0.25)) { currentStep += 1 }
                }
            } label: {
                if currentStep == totalSteps && viewModel.isCreating {
                    ProgressView().tint(Color.onGold)
                } else {
                    Text(currentStep == totalSteps ? "Create community" : "Continue")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canProceed || (currentStep == totalSteps && viewModel.isCreating))
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.vertical, DS.Spacing.s)
        .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Computed Properties

    private var canProceed: Bool {
        switch step {
        case .basics:
            return viewModel.nameValidation.isValid && viewModel.descriptionValidation.isValid
        case .category, .privacy:
            return true
        case .pricing:
            return viewModel.isPricingValid
        case .review:
            return viewModel.isFormValid && viewModel.isPricingValid && !viewModel.isCreating
        }
    }
}

/// One screen of the create flow
private enum CreateStep {
    case basics, category, privacy, pricing, review
}

// MARK: - Text Field Style
/// Filled input used in the create flow (kept for any callers outside this file).
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, DS.Spacing.l)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous).fill(Color.surfaceRaised)
            )
    }
}

#Preview {
    CreateCommunityView()
}
