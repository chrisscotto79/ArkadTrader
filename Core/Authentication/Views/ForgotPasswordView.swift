// File: Core/Authentication/Views/ForgotPasswordView.swift
// Sends a Firebase password reset email.

import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss

    /// Prefilled from the sign-in screen when a valid email was already typed
    var initialEmail: String = ""

    @State private var email = ""
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var emailFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    header

                    CustomTextField(
                        title: "Email",
                        text: $email,
                        placeholder: "you@example.com",
                        keyboardType: .emailAddress,
                        autocapitalization: .never,
                        icon: "envelope",
                        textContentType: .emailAddress,
                        submitLabel: .send,
                        autocorrectionDisabled: true,
                        focus: $emailFocused
                    ) {
                        if canSend { sendResetEmail() }
                    }

                    Button(action: sendResetEmail) {
                        if isSending {
                            ProgressView().tint(Color.onGold)
                        } else {
                            Text("Send reset link")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSend)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.l)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.goldText)
                }
            }
            .alert("Check your email", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("If an account exists for \(email), you'll get a link to reset your password.")
            }
            .alert("Couldn't Send Link", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            if email.isEmpty { email = initialEmail }
            emailFocused = email.isEmpty
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            IconWell(systemName: "key.fill", size: 52)

            Text("Reset your password")
                .font(.system(size: 30, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            Text("Enter the email you sign in with and we'll send you a link to set a new password.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var canSend: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
    }

    private func sendResetEmail() {
        emailFocused = false
        isSending = true
        Task {
            do {
                try await authService.resetPassword(email: email)
                isSending = false
                showSuccess = true
            } catch {
                isSending = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(FirebaseAuthService.shared)
}
