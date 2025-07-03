// File: Core/Authentication/Views/LoginView.swift
// Complete LoginView with Firebase integration

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct LoginView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showForgotPassword = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var rememberMe = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Top spacer for centering
                        Spacer()
                            .frame(height: geometry.size.height * 0.1)
                        
                        // Logo and branding
                        VStack(spacing: 20) {
                            // Logo
                            VStack(spacing: 12) {
                                HStack(spacing: 2) {
                                    Text("ARKAD")
                                        .font(.system(size: 36, weight: .black, design: .default))
                                        .foregroundColor(.arkadGold)
                                    Text("TRADER")
                                        .font(.system(size: 36, weight: .thin, design: .default))
                                        .foregroundColor(.arkadBlack)
                                }
                                
                                Rectangle()
                                    .fill(Color.arkadGold)
                                    .frame(width: 140, height: 3)
                            }
                            
                            Text("Social Trading Platform")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .fontWeight(.medium)
                        }
                        .padding(.bottom, 50)
                        
                        // Login Form
                        VStack(spacing: 24) {
                            VStack(spacing: 20) {
                                // Email Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Email")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    TextField("Enter your email", text: $email)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .autocapitalization(.none)
                                        .keyboardType(.emailAddress)
                                        .textContentType(.emailAddress)
                                }
                                
                                // Password Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Password")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    SecureField("Enter your password", text: $password)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .textContentType(.password)
                                }
                                
                                // Remember Me & Forgot Password
                                HStack {
                                    Button(action: { rememberMe.toggle() }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                                .foregroundColor(rememberMe ? .arkadGold : .gray)
                                            Text("Remember me")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Forgot Password?") {
                                        showForgotPassword = true
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.arkadGold)
                                }
                                
                                // Error Message
                                if !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 4)
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
                                        Text("Sign In")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.arkadBlack)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(isFormValid ? Color.arkadGold : Color.gray.opacity(0.3))
                                )
                            }
                            .disabled(!isFormValid || authService.isLoading)
                            
                            // Divider
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
                            .padding(.vertical, 8)
                            
                            // Social Login Buttons (placeholder for future implementation)
                            VStack(spacing: 12) {
                                SocialLoginButton(
                                    title: "Continue with Apple",
                                    icon: "applelogo",
                                    color: .black
                                ) {
                                    // TODO: Implement Apple Sign In
                                }
                                
                                SocialLoginButton(
                                    title: "Continue with Google",
                                    icon: "globe",
                                    color: .blue
                                ) {
                                    // TODO: Implement Google Sign In
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        // Bottom spacer and register link
                        Spacer()
                            .frame(height: 40)
                        
                        // Register Link
                        VStack(spacing: 16) {
                            HStack {
                                Text("Don't have an account?")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Button("Sign Up") {
                                    showRegister = true
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.arkadGold)
                            }
                            
                            // Terms and Privacy
                            VStack(spacing: 4) {
                                Text("By continuing, you agree to our")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                HStack(spacing: 4) {
                                    Button("Terms of Service") {
                                        // TODO: Show terms
                                    }
                                    .font(.caption)
                                    .foregroundColor(.arkadGold)
                                    
                                    Text("and")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Button("Privacy Policy") {
                                        // TODO: Show privacy policy
                                    }
                                    .font(.caption)
                                    .foregroundColor(.arkadGold)
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
                .environmentObject(authService)
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    // MARK: - Helper Properties
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@") && password.count >= 6
    }
    
    // MARK: - Helper Methods
    
    private func login() {
        hideKeyboard()
        errorMessage = ""
        
        Task {
            do {
                try await authService.login(email: email, password: password)
                // Success is handled automatically by the environment object
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
