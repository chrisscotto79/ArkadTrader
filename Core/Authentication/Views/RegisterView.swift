// File: Core/Authentication/Views/RegisterView.swift
// Two-step sign-up: name + username, then email + password and agreement to the
// Terms of Service and Privacy Policy.

import SwiftUI
import UIKit
import FirebaseAuth

struct RegisterView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var fullName = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var agreeToTerms = false
    @State private var currentStep = 1
    @State private var legalDocument: LegalDocumentType?
    @State private var isSubmitting = false

    @FocusState private var fullNameFieldFocused: Bool
    @FocusState private var usernameFieldFocused: Bool
    @FocusState private var emailFieldFocused: Bool
    @FocusState private var passwordFieldFocused: Bool
    @FocusState private var confirmPasswordFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                        .padding(.top, DS.Spacing.l)

                    stepContent
                        .padding(.top, DS.Spacing.xxl)

                    signInPrompt
                        .padding(.top, DS.Spacing.xl)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxl)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(
            Color.appBackground
                .ignoresSafeArea()
                .onTapGesture { hideKeyboard() }
        )
        .interactiveDismissDisabled(isSubmitting)
        .alert("Couldn't Create Account", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(item: $legalDocument) { document in
            LegalDocumentView(documentType: document)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: DS.Spacing.m) {
            if currentStep == 2 {
                IconButton(systemName: "chevron.left", accessibilityLabel: "Back", size: 36) {
                    previousStep()
                }
                .transition(.opacity)
            } else {
                IconButton(systemName: "xmark", accessibilityLabel: "Cancel", size: 36) {
                    dismiss()
                }
                .transition(.opacity)
            }

            Spacer()

            progressIndicator
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.top, DS.Spacing.l)
    }

    private var progressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(1...2, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.arkadGold : Color.surfaceRaised)
                    .frame(width: step == currentStep ? 28 : 16, height: 6)
            }
            Text("Step \(currentStep) of 2")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
        .animation(.snappy(duration: 0.25), value: currentStep)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep) of 2")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            ArkadLogo(height: 36)

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Text(currentStep == 1 ? "Create your account" : "Secure your account")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .accessibilityAddTraits(.isHeader)
                    .contentTransition(.opacity)

                Text(currentStep == 1
                     ? "Join traders who journal their trades and learn together in communities."
                     : "Add the email and password you'll use to sign in.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        Group {
            if currentStep == 1 {
                personalInfoStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                accountInfoStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.snappy(duration: 0.35), value: currentStep)
    }

    // MARK: Step 1: Personal information

    private var personalInfoStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            CustomTextField(
                title: "Full name",
                text: $fullName,
                placeholder: "Your name",
                autocapitalization: .words,
                icon: "person",
                isValid: fullName.count >= 2,
                errorMessage: "Full name must be at least 2 characters",
                textContentType: .name,
                submitLabel: .next,
                focus: $fullNameFieldFocused
            ) {
                usernameFieldFocused = true
            }

            CustomTextField(
                title: "Username",
                text: $username,
                placeholder: "Choose a username",
                autocapitalization: .never,
                icon: "at",
                isValid: isValidUsername,
                errorMessage: "3-20 characters: letters, numbers and underscores",
                textContentType: .username,
                submitLabel: .next,
                autocorrectionDisabled: true,
                focus: $usernameFieldFocused
            ) {
                nextStep()
            }

            Button(action: nextStep) {
                HStack(spacing: 8) {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isStep1Valid)
            .padding(.top, DS.Spacing.xs)
        }
        // Usernames are lowercase
        .onChange(of: username) { _, newValue in
            let lowered = newValue.lowercased()
            if lowered != newValue { username = lowered }
        }
    }

    // MARK: Step 2: Account information

    private var accountInfoStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            CustomTextField(
                title: "Email",
                text: $email,
                placeholder: "you@example.com",
                keyboardType: .emailAddress,
                autocapitalization: .never,
                icon: "envelope",
                isValid: isValidEmail,
                errorMessage: "Please enter a valid email address",
                textContentType: .emailAddress,
                submitLabel: .next,
                autocorrectionDisabled: true,
                focus: $emailFieldFocused
            ) {
                passwordFieldFocused = true
            }

            CustomTextField(
                title: "Password",
                text: $password,
                placeholder: "Create a password",
                isSecure: true,
                icon: "lock",
                isValid: isValidPassword,
                errorMessage: "At least 8 characters, with an uppercase letter, a lowercase letter and a number",
                textContentType: .newPassword,
                submitLabel: .next,
                focus: $passwordFieldFocused
            ) {
                confirmPasswordFieldFocused = true
            }

            CustomTextField(
                title: "Confirm password",
                text: $confirmPassword,
                placeholder: "Type it again",
                isSecure: true,
                icon: "lock.shield",
                isValid: password == confirmPassword && !password.isEmpty,
                errorMessage: "Passwords don't match",
                textContentType: .newPassword,
                submitLabel: .done,
                focus: $confirmPasswordFieldFocused
            ) {
                if canRegister { register() }
            }

            termsAgreement
                .padding(.top, DS.Spacing.xs)

            Button(action: register) {
                if isSubmitting {
                    ProgressView().tint(Color.onGold)
                } else {
                    Text("Create account")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canRegister)
            .accessibilityLabel(isSubmitting ? "Creating account" : "Create account")
        }
        // Tells iOS strong-password suggestions what the password needs
        .background(PasswordRulesHint(rules: Self.passwordRules))
    }

    /// Matches `isValidPassword`
    static let passwordRules = "minlength: 8; required: lower; required: upper; required: digit; allowed: ascii-printable;"

    private var termsAgreement: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { agreeToTerms.toggle() }
            } label: {
                Image(systemName: agreeToTerms ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(agreeToTerms ? Color.goldText : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Agree to the Terms of Service and Privacy Policy")
            .accessibilityValue(agreeToTerms ? "Checked" : "Unchecked")

            VStack(alignment: .leading, spacing: 4) {
                // The links open the in-app documents (LegalDocumentView in LegalDocuments.swift)
                Text("I agree to the [Terms of Service](arkad-legal://terms) and [Privacy Policy](arkad-legal://privacy)")
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .tint(Color.goldText)
                    .multilineTextAlignment(.leading)
                    .environment(\.openURL, OpenURLAction { url in
                        switch url.host {
                        case "terms": legalDocument = .terms
                        case "privacy": legalDocument = .privacy
                        default: break
                        }
                        return .handled
                    })

                Text("By creating an account, you agree to these terms.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 3)

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
    }

    // MARK: - Sign In

    private var signInPrompt: some View {
        HStack(spacing: 4) {
            Text("Already have an account?")
                .foregroundStyle(.secondary)
            Button("Sign in") { dismiss() }
                .fontWeight(.semibold)
                .foregroundStyle(Color.goldText)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Validation

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: trimmedEmail)
    }

    private var isValidUsername: Bool {
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        return NSPredicate(format: "SELF MATCHES %@", usernameRegex).evaluate(with: username)
    }

    private var isValidPassword: Bool {
        // At least 8 characters with a lowercase letter, an uppercase letter and a number.
        // Any symbols are fine, so iOS strong passwords pass.
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$"
        return NSPredicate(format: "SELF MATCHES %@", passwordRegex).evaluate(with: password)
    }

    private var isStep1Valid: Bool {
        fullName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && isValidUsername
    }

    private var isFormValid: Bool {
        isStep1Valid && isValidEmail && isValidPassword && password == confirmPassword
    }

    private var canRegister: Bool {
        isFormValid && agreeToTerms && !isSubmitting
    }

    // MARK: - Actions

    private func nextStep() {
        if isStep1Valid {
            withAnimation(.snappy(duration: 0.35)) {
                currentStep = 2
            }
            emailFieldFocused = true
        }
    }

    private func previousStep() {
        withAnimation(.snappy(duration: 0.35)) {
            currentStep = 1
        }
        fullNameFieldFocused = true
    }

    private func register() {
        guard canRegister else { return }
        hideKeyboard()
        isSubmitting = true

        Task {
            do {
                try await authService.register(
                    email: trimmedEmail,
                    password: password,
                    username: username,
                    fullName: fullName
                )
                dismiss()
            } catch {
                errorMessage = Self.message(for: error)
                showError = true
            }
            isSubmitting = false
        }
    }

    private static func message(for error: Error) -> String {
        if error is AuthError { return error.localizedDescription }
        switch AuthErrorCode(rawValue: (error as NSError).code) {
        case .emailAlreadyInUse:
            return "There's already an account with this email. Sign in instead, or reset your password."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Please choose a stronger password."
        case .networkError:
            return "Check your connection and try again."
        default:
            return error.localizedDescription
        }
    }

    private func hideKeyboard() {
        fullNameFieldFocused = false
        usernameFieldFocused = false
        emailFieldFocused = false
        passwordFieldFocused = false
        confirmPasswordFieldFocused = false
    }
}

// MARK: - Password rules

/// Sets `passwordRules` on the new-password fields around it, so iOS suggests a strong password
/// that passes validation. SwiftUI fields don't expose the property, so this finds the
/// underlying UITextFields in the window.
private struct PasswordRulesHint: UIViewRepresentable {
    let rules: String

    func makeUIView(context: Context) -> HintView {
        let view = HintView()
        view.rules = UITextInputPasswordRules(descriptor: rules)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: HintView, context: Context) {
        uiView.apply()
    }

    final class HintView: UIView {
        var rules: UITextInputPasswordRules?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            apply()
        }

        func apply() {
            guard let rules, let root = window else { return }
            Self.textFields(in: root)
                .filter { $0.textContentType == .newPassword && $0.passwordRules == nil }
                .forEach { $0.passwordRules = rules }
        }

        private static func textFields(in view: UIView) -> [UITextField] {
            if let field = view as? UITextField { return [field] }
            return view.subviews.flatMap(textFields(in:))
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(FirebaseAuthService.shared)
}
