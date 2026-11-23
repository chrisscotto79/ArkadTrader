// File: Core/Communities/Views/Create/CreateCommunityView.swift
// Four-step community creation flow: basics, category, privacy, review.

import SwiftUI

struct CreateCommunityView: View {
    @StateObject private var viewModel = CommunityCreationViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1

    private var totalSteps: Int { 4 }

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
            Text("\(viewModel.name) is ready. Invite traders to join you.")
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
        switch currentStep {
        case 1: basicInfoStep
        case 2: categoryStep
        case 3: settingsStep
        case 4: reviewStep
        default: EmptyView()
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

            tipsCard([
                "Say what you trade and on what timeframe",
                "Mention the experience level you're aiming for",
                "Keep it welcoming and professional"
            ])
        }
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

    // MARK: Step 4 — Review

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
                }
                .cardStyle(padding: 0)
            }
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.m) {
                CommunityAvatar(name: viewModel.name, size: 56)
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
        switch currentStep {
        case 1:
            return viewModel.nameValidation.isValid && viewModel.descriptionValidation.isValid
        case 2, 3:
            return true
        case 4:
            return viewModel.isFormValid && !viewModel.isCreating
        default:
            return false
        }
    }
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
