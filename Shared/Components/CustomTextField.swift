// File: Shared/Components/CustomTextField.swift
// Labelled text field in the Arkad style: a rounded `surfaceRaised` field with an
// optional leading icon, a gold focus ring, validation feedback and (for passwords)
// a show/hide toggle. Used by sign-in, sign-up and Edit Profile.

import SwiftUI
import UIKit

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var icon: String? = nil
    /// Whether the current text passes validation. Only shown once something is typed.
    var isValid: Bool = true
    /// Message shown under the field when `isValid` is false. Passing one also turns on
    /// the check / warning icon for non-secure fields.
    var errorMessage: String? = nil
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .done
    var autocorrectionDisabled: Bool = false
    /// Grows vertically (bio and other longer text)
    var multiline: Bool = false
    /// Lets the parent move focus between fields. Optional.
    var focus: FocusState<Bool>.Binding? = nil
    var onSubmit: () -> Void = {}

    @FocusState private var internalFocus: Bool
    @State private var isRevealed = false

    private var isFocused: Bool { focus?.wrappedValue ?? internalFocus }
    private var hasValidation: Bool { errorMessage != nil }
    private var showsError: Bool { hasValidation && !text.isEmpty && !isValid }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            fieldRow

            if showsError, let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.marketRed)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.2), value: showsError)
    }

    // MARK: - Field

    private var fieldRow: some View {
        HStack(alignment: multiline ? .top : .center, spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isFocused ? Color.goldText : Color.secondary)
                    .frame(width: 22)
                    .padding(.top, multiline ? 1 : 0)
                    .accessibilityHidden(true)
            }

            inputField
                .focused(focus ?? $internalFocus)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                .textContentType(textContentType)
                .autocorrectionDisabled(autocorrectionDisabled || isSecure)
                .font(.body)
                .foregroundStyle(Color.primary)
                .tint(Color.goldText)

            trailingAccessory
        }
        .padding(.horizontal, 14)
        .padding(.vertical, multiline ? 14 : 0)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(Color.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isFocused ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { setFocus(true) }
        .animation(.snappy(duration: 0.2), value: isFocused)
    }

    @ViewBuilder
    private var inputField: some View {
        let prompt = placeholder.isEmpty ? title : placeholder
        if isSecure && !isRevealed {
            SecureField(prompt, text: $text)
        } else if multiline {
            TextField(prompt, text: $text, axis: .vertical)
                .lineLimit(3...6)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
        } else {
            TextField(prompt, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(isSecure ? .never : autocapitalization)
        }
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if isSecure {
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
        } else if hasValidation && !text.isEmpty {
            Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.body)
                .foregroundStyle(isValid ? Color.marketGreen : Color.marketRed)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel(isValid ? "Valid" : "Needs attention")
        }
    }

    private var borderColor: Color {
        if isFocused { return .goldText }
        if showsError { return Color.marketRed.opacity(0.6) }
        return .clear
    }

    private func setFocus(_ value: Bool) {
        if let focus {
            focus.wrappedValue = value
        } else {
            internalFocus = value
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CustomTextField(title: "Email", text: .constant("trader@"), placeholder: "you@example.com",
                        icon: "envelope", isValid: false, errorMessage: "Enter a valid email address")
        CustomTextField(title: "Password", text: .constant(""), isSecure: true, icon: "lock")
        CustomTextField(title: "Bio", text: .constant(""), placeholder: "Tell traders about yourself", multiline: true)
    }
    .padding()
    .screenBackground()
}
