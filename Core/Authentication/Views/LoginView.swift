// File: Core/Authentication/Views/LoginView.swift

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showForgotPassword = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                // Logo
                VStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Text("ARKAD")
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundColor(.arkadGold)
                        Text("TRADER")
                            .font(.largeTitle)
                            .fontWeight(.thin)
                            .foregroundColor(.arkadBlack)
                    }
                    
                    Rectangle()
                        .fill(Color.arkadGold)
                        .frame(width: 120, height: 2)
                }
                .padding(.bottom, 20)
                
                Text("Social Trading Platform")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Login Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Login") {
                        Task {
                            await login()
                        }
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadBlack)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.arkadGold)
                    .cornerRadius(12)
                    .disabled(authService.isLoading)
                    
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    Button("Forgot Password?") {
                        showForgotPassword = true
                    }
                    .font(.caption)
                    .foregroundColor(.arkadGold)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Register Link
                Button("Don't have an account? Sign Up") {
                    showRegister = true
                }
                .foregroundColor(.arkadGold)
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showRegister) {
                RegisterView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            showError = true
            return
        }
        
        do {
            try await authService.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Register View

struct RegisterView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var fullName = ""
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    TextField("Full Name", text: $fullName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Create Account") {
                        Task {
                            await register()
                        }
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadBlack)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.arkadGold)
                    .cornerRadius(12)
                    .disabled(authService.isLoading)
                    
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func register() async {
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty, !fullName.isEmpty else {
            errorMessage = "Please fill in all fields"
            showError = true
            return
        }
        
        do {
            try await authService.register(email: email, password: password, username: username, fullName: fullName)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(FirebaseAuthService.shared)
}
