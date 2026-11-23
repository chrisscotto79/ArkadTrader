// File: Core/Safety/ReportSheet.swift
// Report a post, comment, message, account or community: pick a reason, add optional
// details, submit, then a thank-you state. Present it as a sheet:
//     .sheet(item: $reportTarget) { ReportSheet(target: $0) }

import SwiftUI

struct ReportSheet: View {
    let target: ReportTarget
    /// Called once the report has been saved (e.g. to hide the post from the reporter's feed)
    var onSubmitted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason?
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false
    @FocusState private var detailsFocused: Bool

    private static let detailsLimit = 500

    var body: some View {
        NavigationStack {
            Group {
                if didSubmit {
                    thankYou
                        .transition(.opacity)
                } else {
                    form
                }
            }
            .screenBackground()
            .navigationTitle(didSubmit ? "" : "Report \(target.noun)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: didSubmit ? .confirmationAction : .cancellationAction) {
                    Button(didSubmit ? "Done" : "Cancel") { dismiss() }
                        .fontWeight(didSubmit ? Font.Weight.semibold : Font.Weight.regular)
                        .tint(Color.goldText)
                }
            }
            .animation(.snappy(duration: 0.25), value: didSubmit)
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    Text("Why are you reporting this \(target.noun)?")
                        .font(.title3.weight(.bold))
                    Text("The person won't know it was you. The Arkad team reviews every report.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                reasonList

                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    Text(reason == .other ? "Details" : "Details (optional)")
                        .font(.subheadline.weight(.semibold))
                    TextField("Anything that helps us understand", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($detailsFocused)
                        .padding(DS.Spacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                                .fill(Color.surfaceRaised)
                        )
                        .onChange(of: details) { _, newValue in
                            if newValue.count > Self.detailsLimit {
                                details = String(newValue.prefix(Self.detailsLimit))
                            }
                        }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.marketRed)
                }
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { submitBar }
    }

    private var reasonList: some View {
        VStack(spacing: 0) {
            ForEach(ReportReason.allCases) { item in
                if item != ReportReason.allCases.first {
                    Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, DS.Spacing.l)
                }
                reasonRow(item)
            }
        }
        .cardStyle(padding: 0)
    }

    private func reasonRow(_ item: ReportReason) -> some View {
        let isSelected = reason == item
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            reason = item
            errorMessage = nil
            if item == .other { detailsFocused = true }
        } label: {
            HStack(spacing: DS.Spacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.goldText : Color.secondary.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var submitBar: some View {
        Button(action: submit) {
            HStack(spacing: DS.Spacing.s) {
                if isSubmitting { ProgressView().tint(Color.onGold) }
                Text(isSubmitting ? "Sending…" : "Submit report")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canSubmit || isSubmitting)
        .padding(.horizontal, DS.pageMargin)
        .padding(.vertical, DS.Spacing.s)
        .background(Color.appBackground)
    }

    private var trimmedDetails: String {
        details.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        guard let reason else { return false }
        return reason != .other || !trimmedDetails.isEmpty
    }

    // MARK: - Thank you

    private var thankYou: some View {
        VStack {
            Spacer(minLength: 0)
            EmptyStateView(
                systemImage: "checkmark.shield.fill",
                title: "Thanks for reporting",
                message: "We'll review this \(target.noun). You can also block the person from their profile so you no longer see them.",
                actionTitle: "Done",
                action: { dismiss() }
            )
            Spacer(minLength: 0)
        }
    }

    // MARK: - Submit

    private func submit() {
        guard let reason else { return }
        guard let reporterId = FirebaseAuthService.shared.currentUser?.id else {
            errorMessage = "Sign in to send a report."
            return
        }
        isSubmitting = true
        errorMessage = nil
        detailsFocused = false
        let details = trimmedDetails.isEmpty ? nil : trimmedDetails

        Task {
            do {
                try await FirebaseServices.shared.submitReport(
                    target: target, reason: reason, details: details, reportedBy: reporterId
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                didSubmit = true
                onSubmitted?()
            } catch {
                errorMessage = "Couldn't send your report. Check your connection and try again."
            }
            isSubmitting = false
        }
    }
}

#Preview {
    ReportSheet(target: .post(id: "p1", ownerId: "u1"))
}
