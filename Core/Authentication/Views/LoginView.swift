// File: Core/Authentication/Views/LoginView.swift
// Enhanced Login View with better UX, validation, and design

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
    @State private var isPasswordVisible = false
    
    @FocusState private var emailFieldFocused: Bool
    @FocusState private var passwordFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background gradient
                    LinearGradient(
                        gradient: Gradient(colors: [Color.arkadGold.opacity(0.1), Color.white]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Logo and Header Section
                            logoSection
                                .padding(.top, max(50, geometry.safeAreaInsets.top + 20))
                            
                            // Login Form
                            loginFormSection
                                .padding(.top, 40)
                            
                            // Bottom Actions
                            bottomActionsSection
                                .padding(.top, 30)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(50, geometry.safeAreaInsets.bottom + 20))
                    }
                }
            }
            .navigationBarHidden(true)
            .onTapGesture {
                hideKeyboard()
            }
        }
        .alert("Login Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
                .environmentObject(authService)
        }
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 20) {
            // App Logo
            Image("arkad_logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280, maxHeight: 120)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            // Welcome Text
            VStack(spacing: 8) {
                Text("Welcome Back")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Sign in to continue your trading journey")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Login Form Section
    private var loginFormSection: some View {
        VStack(spacing: 20) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(emailFieldFocused ? .arkadGold : .gray)
                        .font(.title3)
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .focused($emailFieldFocused)
                        .submitLabel(.next)
                        .onSubmit {
                            passwordFieldFocused = true
                        }
                    
                    if !email.isEmpty {
                        Image(systemName: isValidEmail ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(isValidEmail ? .green : .red)
                            .font(.title3)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(emailFieldFocused ? Color.arkadGold : Color.gray.opacity(0.3), lineWidth: emailFieldFocused ? 2 : 1)
                )
                .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
                
                if !email.isEmpty && !isValidEmail {
                    Text("Please enter a valid email address")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(passwordFieldFocused ? .arkadGold : .gray)
                        .font(.title3)
                    
                    Group {
                        if isPasswordVisible {
                            TextField("Enter your password", text: $password)
                        } else {
                            SecureField("Enter your password", text: $password)
                        }
                    }
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($passwordFieldFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        if isFormValid {
                            login()
                        }
                    }
                    
                    Button(action: { isPasswordVisible.toggle() }) {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(passwordFieldFocused ? Color.arkadGold : Color.gray.opacity(0.3), lineWidth: passwordFieldFocused ? 2 : 1)
                )
                .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
                
                if !password.isEmpty && password.count < 6 {
                    Text("Password must be at least 6 characters")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Remember Me & Forgot Password
            HStack {
                Button(action: { rememberMe.toggle() }) {
                    HStack(spacing: 8) {
                        Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                            .foregroundColor(rememberMe ? .arkadGold : .gray)
                        
                        Text("Remember me")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                Button(action: { showForgotPassword = true }) {
                    Text("Forgot Password?")
                        .font(.subheadline)
                        .foregroundColor(.arkadGold)
                        .fontWeight(.medium)
                }
            }
            
            // Login Button
            Button(action: login) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .arkadBlack))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                        Text("Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.arkadBlack)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: isFormValid && !authService.isLoading ?
                                         [Color.arkadGold, Color.arkadGold.opacity(0.8)] :
                                         [Color.gray.opacity(0.3), Color.gray.opacity(0.2)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: isFormValid ? Color.arkadGold.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                .scaleEffect(isFormValid && !authService.isLoading ? 1.0 : 0.98)
                .animation(.easeInOut(duration: 0.2), value: isFormValid)
            }
            .disabled(!isFormValid || authService.isLoading)
        }
    }
    
    // MARK: - Bottom Actions Section
    private var bottomActionsSection: some View {
        VStack(spacing: 20) {
            // Divider with "or"
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                Text("or")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            
            // Social Login Buttons (Placeholder for future implementation)
            VStack(spacing: 12) {
                socialLoginButton(
                    title: "Continue with Apple",
                    icon: "applelogo",
                    backgroundColor: .black,
                    foregroundColor: .white
                ) {
                    // TODO: Implement Apple Sign In
                }
                
                socialLoginButton(
                    title: "Continue with Google",
                    icon: "globe",
                    backgroundColor: .white,
                    foregroundColor: .primary
                ) {
                    // TODO: Implement Google Sign In
                }
            }
            
            // Register Link
            HStack {
                Text("Don't have an account?")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Button(action: { showRegister = true }) {
                    Text("Sign Up")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                }
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Helper Views
    private func socialLoginButton(
        title: String,
        icon: String,
        backgroundColor: Color,
        foregroundColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                
                Text(title)
                    .fontWeight(.medium)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Computed Properties
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
                
                // Save credentials if remember me is checked
                if rememberMe {
                    UserDefaults.standard.set(email, forKey: "saved_email")
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
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
