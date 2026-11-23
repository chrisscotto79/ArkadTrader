// File: Core/Communities/Views/Detail/CommunitySettingsSheet.swift
// Community settings sheet for owners and admins, including custom rules and pricing (free or paid).

import SwiftUI
import PhotosUI

struct EnhancedCommunitySettingsSheet: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CommunitySettingsViewModel
    @State private var showingDeleteAlert = false
    @State private var showPayouts = false

    init(community: Community) {
        self.community = community
        self._viewModel = StateObject(wrappedValue: CommunitySettingsViewModel(community: community))
    }

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                rulesSection

                if viewModel.isOwner {
                    detailsSection
                    imagesSection
                    saveSection
                    membershipSection
                    membersSection
                    dangerSection
                } else {
                    infoSection
                }

                if !viewModel.errorMessage.isEmpty {
                    Section {
                        Label(viewModel.errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.marketRed)
                    }
                    .listRowBackground(Color.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .tint(Color.goldText)
            .navigationTitle(viewModel.isOwner ? "Manage Community" : "Rules & Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if viewModel.hasChanges {
                            viewModel.resetSettings()
                        }
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .disabled(viewModel.isLoading)
                }
            }
            .alert("Delete Community", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteCommunity()
                        if viewModel.errorMessage.isEmpty {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(community.name)\"? This action cannot be undone and will remove all channels and messages.")
            }
            .alert("Remove Member",
                   isPresented: Binding(
                    get: { viewModel.selectedMemberForRemoval != nil },
                    set: { if !$0 { viewModel.selectedMemberForRemoval = nil } }
                   ),
                   presenting: viewModel.selectedMemberForRemoval) { member in
                Button("Cancel", role: .cancel) {
                    viewModel.selectedMemberForRemoval = nil
                }
                Button("Remove", role: .destructive) {
                    Task {
                        await viewModel.removeMember(member)
                        viewModel.selectedMemberForRemoval = nil
                    }
                }
            } message: { member in
                Text("Are you sure you want to remove \(member.displayName) from the community?")
            }
        }
        .onAppear {
            // Load members (owners) and rules when the sheet appears
            if viewModel.isOwner && viewModel.members.isEmpty {
                Task {
                    await viewModel.loadMembers()
                }
            }

            if viewModel.communityRules.isEmpty {
                Task {
                    await viewModel.loadCommunityRules()
                }
            }
        }
        .task {
            await viewModel.loadPayoutStatus()
        }
        .sheet(isPresented: $showPayouts, onDismiss: {
            Task { await viewModel.loadPayoutStatus() }
        }) {
            PayoutsSheet()
        }
        .sheet(isPresented: $viewModel.showingAddRule) {
            AddCustomRuleSheet { title, description, isRequired in
                Task {
                    await viewModel.addCustomRule(title: title, description: description, isRequired: isRequired)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            HStack(spacing: DS.Spacing.m) {
                CommunityAvatar(name: community.name, imageURL: viewModel.settings.avatarURL, size: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text(community.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(CommunityFormat.summary(community))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: DS.Spacing.s)

                if viewModel.isOwner {
                    Tag(text: "Owner", systemImage: "crown.fill")
                }
            }
            .padding(.vertical, DS.Spacing.xs)
        }
        .listRowBackground(Color.surface)
    }

    // MARK: - Rules

    private var rulesSection: some View {
        Section {
            if viewModel.isLoadingRules {
                HStack(spacing: DS.Spacing.m) {
                    ProgressView()
                    Text("Loading rules…")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.communityRules.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    Text("No community rules set")
                        .foregroundStyle(.secondary)

                    if viewModel.isOwner {
                        Button("Create default trading rules") {
                            Task {
                                await viewModel.loadCommunityRules()
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
            } else {
                ForEach(viewModel.communityRules) { rule in
                    CommunityRuleRow(
                        rule: rule,
                        isOwner: viewModel.isOwner,
                        onDelete: {
                            Task {
                                await viewModel.deleteRule(rule)
                            }
                        }
                    )
                }

                if viewModel.isOwner {
                    Button {
                        viewModel.showingAddRule = true
                    } label: {
                        Label("Add custom rule", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        } header: {
            Text("Rules & Guidelines")
        }
        .listRowBackground(Color.surface)
    }

    // MARK: - Details (owner)

    private var detailsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                fieldLabel("Name")
                TextField("Community name", text: $viewModel.settings.name)
                    .padding(.horizontal, DS.Spacing.m)
                    .frame(height: 44)
                    .background(fieldBackground)
            }
            .padding(.vertical, DS.Spacing.xs)

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                fieldLabel("Description")
                TextField("What is this community about?", text: $viewModel.settings.description, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(DS.Spacing.m)
                    .background(fieldBackground)
            }
            .padding(.vertical, DS.Spacing.xs)

            Toggle("Private community", isOn: $viewModel.settings.isPrivate)
                .tint(Color.arkadGold)
        } header: {
            Text("Details")
        } footer: {
            Text("Private communities are hidden from Discover and search for anyone who isn't a member.")
        }
        .listRowBackground(Color.surface)
    }

    // MARK: - Images (owner)

    private var imagesSection: some View {
        Section {
            avatarEditor
            bannerEditor
        } header: {
            Text("Images")
        }
        .listRowBackground(Color.surface)
    }

    private var avatarEditor: some View {
        HStack(spacing: DS.Spacing.l) {
            ZStack {
                if let avatarImage = viewModel.avatarImage, viewModel.settings.avatarURL == nil {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 76 * 0.28, style: .continuous))
                } else {
                    CommunityAvatar(name: community.name, imageURL: viewModel.settings.avatarURL, size: 76)
                }

                if viewModel.isUploadingAvatar {
                    RoundedRectangle(cornerRadius: 76 * 0.28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 76, height: 76)
                    ProgressView(value: viewModel.avatarUploadProgress)
                        .progressViewStyle(.circular)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Text("Avatar")
                    .font(.subheadline.weight(.semibold))
                Text("Square image, 512×512 recommended")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: DS.Spacing.s) {
                    PhotosPicker(
                        selection: $viewModel.selectedAvatarItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Text(viewModel.hasAvatarImage ? "Change" : "Choose")
                    }
                    .buttonStyle(PillButtonStyle(kind: .neutral))
                    .disabled(viewModel.isUploadingAvatar)

                    if viewModel.hasAvatarImage {
                        Button("Remove", role: .destructive) {
                            Task {
                                await viewModel.removeAvatar()
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.marketRed)
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private var bannerEditor: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            ZStack {
                bannerPreview
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                            .strokeBorder(Color.hairline, lineWidth: 1)
                    )

                if viewModel.isUploadingBanner {
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(height: 110)
                    VStack(spacing: DS.Spacing.s) {
                        ProgressView(value: viewModel.bannerUploadProgress)
                            .frame(width: 100)
                        Text("\(Int(viewModel.bannerUploadProgress * 100))%")
                            .font(.caption.weight(.semibold).monospacedDigit())
                    }
                }
            }

            HStack(spacing: DS.Spacing.s) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Banner")
                        .font(.subheadline.weight(.semibold))
                    Text("Wide image, 1200×400 (3:1) recommended")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DS.Spacing.s)

                if viewModel.hasBannerImage {
                    Button("Remove", role: .destructive) {
                        Task {
                            await viewModel.removeBanner()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.marketRed)
                    .disabled(viewModel.isLoading)
                }

                PhotosPicker(
                    selection: $viewModel.selectedBannerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Text(viewModel.hasBannerImage ? "Change" : "Choose")
                }
                .buttonStyle(PillButtonStyle(kind: .neutral))
                .disabled(viewModel.isUploadingBanner)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    @ViewBuilder
    private var bannerPreview: some View {
        let tint = CommunityPalette.color(for: community.name).opacity(0.18)
        if let bannerURL = viewModel.settings.bannerURL, let url = URL(string: bannerURL) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    tint
                }
            }
        } else if let bannerImage = viewModel.bannerImage {
            Image(uiImage: bannerImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                tint
                Label("Add a banner", systemImage: "photo.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Save (owner)

    private var saveSection: some View {
        Section {
            Button {
                Task {
                    await viewModel.updateCommunity()
                    if viewModel.errorMessage.isEmpty {
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView().tint(Color.onGold)
                    } else {
                        Text("Save changes")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(viewModel.canSave ? Color.onGold : Color.secondary)
            }
            .disabled(!viewModel.canSave || viewModel.isLoading)
            .listRowBackground(viewModel.canSave ? Color.arkadGold : Color.surfaceRaised)
        }
    }

    // MARK: - Membership price (owner)

    private var membershipSection: some View {
        Section {
            Picker("Membership", selection: $viewModel.pricingIsPaid) {
                Text("Free").tag(false)
                Text("Paid").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.vertical, DS.Spacing.xs)

            if viewModel.pricingIsPaid {
                if viewModel.canChargeMembers {
                    paidPricingRows
                } else {
                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        Text(viewModel.payoutStatus?.stage == .inReview ? "Payouts are in review" : "Set up payouts first")
                            .font(.subheadline.weight(.semibold))
                        Text("Stripe needs to approve your payout account before members can pay.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Set up payouts") { showPayouts = true }
                            .buttonStyle(PillButtonStyle(kind: .gold))
                            .padding(.top, DS.Spacing.xs)
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }
            }

            if let error = viewModel.pricingError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.marketRed)
            } else if viewModel.pricingSaved && !viewModel.hasPricingChanges {
                Label("Pricing saved", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.marketGreen)
            }

            if viewModel.hasPricingChanges {
                Button {
                    Task { await viewModel.savePricing() }
                } label: {
                    HStack(spacing: DS.Spacing.s) {
                        if viewModel.isSavingPricing {
                            ProgressView()
                        }
                        Text(viewModel.pricingIsPaid ? "Save price" : "Make community free")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.canSavePricing)
            }
        } header: {
            Text("Membership")
        } footer: {
            Text("Arkad keeps \(CommunityPricing.feePercentText) of each payment. \(CommunityPricing.processingFeeNote)")
        }
        .listRowBackground(Color.surface)
    }

    @ViewBuilder
    private var paidPricingRows: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            fieldLabel("Monthly price")
            HStack(spacing: DS.Spacing.xs) {
                Text("$")
                    .foregroundStyle(.secondary)
                TextField("9.99", text: $viewModel.pricingPriceText)
                    .keyboardType(.decimalPad)
                    .font(.body.monospacedDigit())
                Text("/ month")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Spacing.m)
            .frame(height: 44)
            .background(fieldBackground)

            if let message = viewModel.pricingValidationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.marketRed)
            }
        }
        .padding(.vertical, DS.Spacing.xs)

        Picker("Free trial", selection: $viewModel.pricingTrialDays) {
            ForEach(CommunityPricing.trialOptions, id: \.self) { days in
                Text(CommunityPricing.trialChipTitle(days)).tag(days)
            }
        }

        if let price = viewModel.pricingPrice, viewModel.pricingValidationMessage == nil {
            CommunityEarningsBreakdown(price: price)
                .padding(.vertical, DS.Spacing.xs)
        }
    }

    // MARK: - Members (owner)

    private var membersSection: some View {
        Section {
            if viewModel.isLoadingMembers {
                HStack(spacing: DS.Spacing.m) {
                    ProgressView()
                    Text("Loading members…")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.members.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    Text("No members found")
                        .foregroundStyle(.secondary)
                    Button("Reload members") {
                        Task {
                            await viewModel.loadMembers()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, DS.Spacing.xs)
            } else {
                ForEach(viewModel.members) { member in
                    MemberRow(
                        member: member,
                        isOwner: viewModel.isOwner,
                        onRoleChange: { newRole in
                            Task {
                                await viewModel.updateMemberRole(member, to: newRole)
                            }
                        },
                        onRemove: {
                            viewModel.selectedMemberForRemoval = member
                        }
                    )
                }
            }
        } header: {
            Text("Members · \(viewModel.members.count)")
        }
        .listRowBackground(Color.surface)
    }

    // MARK: - Danger zone (owner)

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete community", systemImage: "trash")
                    .foregroundStyle(Color.marketRed)
            }
            .disabled(viewModel.isLoading)
        } header: {
            Text("Danger zone")
        } footer: {
            Text("Deleting removes every channel and message for all members.")
        }
        .listRowBackground(Color.surface)
    }

    // MARK: - Info (non-owner)

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                fieldLabel("About")
                Text(community.description)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.85))
            }
            .padding(.vertical, DS.Spacing.xs)

            LabeledContent("Privacy", value: community.isPrivate ? "Private" : "Public")
            LabeledContent("Membership", value: community.priceTagText ?? "Free")
            LabeledContent("Members", value: community.memberCount.formatted())
        } header: {
            Text("Community info")
        } footer: {
            Text("Only the owner can change these settings.")
        }
        .listRowBackground(Color.surface)
    }

    // MARK: - Building blocks

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous).fill(Color.surfaceRaised)
    }
}

// MARK: - Community Rule Row Component
struct CommunityRuleRow: View {
    let rule: CommunityRule
    let isOwner: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            Image(systemName: rule.categoryIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.goldText)
                .frame(width: 22)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: 6) {
                    Text(rule.title)
                        .font(.subheadline.weight(.semibold))
                    if rule.isRequired {
                        Tag(text: "Required", tint: .marketRed)
                    }
                }
                Text(rule.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if !rule.isDefault && isOwner {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(Color.marketRed)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete rule")
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

// MARK: - Add Custom Rule Sheet
struct AddCustomRuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var isRequired = true

    let onSave: (String, String, Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Rule title", text: $title)
                    TextField("What members should know", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Rule")
                }
                .listRowBackground(Color.surface)

                Section {
                    Toggle("Required for all members", isOn: $isRequired)
                        .tint(Color.arkadGold)
                }
                .listRowBackground(Color.surface)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .tint(Color.goldText)
            .navigationTitle("New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, description, isRequired)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
