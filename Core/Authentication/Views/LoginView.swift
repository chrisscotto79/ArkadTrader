// File: Core/Authentication/Views/LoginView.swift
// Sign in: email + password, remember-me (email only), password reset and sign-up.

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showForgotPassword = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var rememberMe = false

    @FocusState private var emailFieldFocused: Bool
    @FocusState private var passwordFieldFocused: Bool

    private static let savedEmailKey = "saved_email"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.top, DS.Spacing.xxl)

                formSection
                    .padding(.top, DS.Spacing.xxl)

                signUpPrompt
                    .padding(.top, DS.Spacing.xl)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(
            Color.appBackground
                .ignoresSafeArea()
                .onTapGesture { hideKeyboard() }
        )
        .onAppear(perform: loadSavedEmail)
        .alert("Couldn't Sign In", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(initialEmail: isValidEmail ? email : "")
                .environmentObject(authService)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            ArkadLogo(height: 40)

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Text("Welcome back")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .accessibilityAddTraits(.isHeader)

                Text("Sign in to get back to your trading journal and communities.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Form

    private var formSection: some View {
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
                placeholder: "Your password",
                isSecure: true,
                icon: "lock",
                isValid: password.count >= 6,
                errorMessage: "Password must be at least 6 characters",
                textContentType: .password,
                submitLabel: .go,
                focus: $passwordFieldFocused
            ) {
                if isFormValid { login() }
            }

            optionsRow

            Button(action: login) {
                HStack(spacing: 8) {
                    if authService.isLoading {
                        ProgressView().tint(Color.onGold)
                    } else {
                        Text("Sign in")
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isFormValid || authService.isLoading)
            .padding(.top, DS.Spacing.xs)
        }
    }

    private var optionsRow: some View {
        HStack {
            Button(action: toggleRememberMe) {
                HStack(spacing: 8) {
                    Image(systemName: rememberMe ? "checkmark.circle.fill" : "circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(rememberMe ? Color.goldText : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                    Text("Remember me")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remember my email")
            .accessibilityValue(rememberMe ? "On" : "Off")

            Spacer()

            Button("Forgot password?") { showForgotPassword = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.goldText)
        }
    }

    // MARK: - Sign Up

    private var signUpPrompt: some View {
        HStack(spacing: 4) {
            Text("New to Arkad?")
                .foregroundStyle(.secondary)
            Button("Create an account") { showRegister = true }
                .fontWeight(.semibold)
                .foregroundStyle(Color.goldText)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Validation

    private var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }

    private var isFormValid: Bool {
        isValidEmail && password.count >= 6
    }

    // MARK: - Actions

    private func login() {
        hideKeyboard()

        Task {
            do {
                try await authService.login(email: email, password: password)

                // Remember only the email address (never the password)
                if rememberMe {
                    UserDefaults.standard.set(email, forKey: Self.savedEmailKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: Self.savedEmailKey)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func toggleRememberMe() {
        withAnimation(.snappy(duration: 0.2)) {
            rememberMe.toggle()
        }
        if !rememberMe {
            UserDefaults.standard.removeObject(forKey: Self.savedEmailKey)
        }
    }

    /// Prefills the email field when "Remember me" was used on a previous sign-in.
    private func loadSavedEmail() {
        guard let saved = UserDefaults.standard.string(forKey: Self.savedEmailKey),
              !saved.isEmpty else { return }
        if email.isEmpty {
            email = saved
        }
        rememberMe = true
    }

    private func hideKeyboard() {
        emailFieldFocused = false
        passwordFieldFocused = false
    }
}

#Preview {
    LoginView()
        .environmentObject(FirebaseAuthService.shared)
}
