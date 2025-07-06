// File: Core/Authentication/Views/LoginView.swift
// Simplified Login View

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo
                Text("ArkadTrader")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .padding(.bottom, 40)
                
                // Email Field
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                // Password Field
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Login Button
                Button(action: login) {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Login")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
                
                // Register Link
                Button("Don't have an account? Register") {
                    showRegister = true
                }
                .foregroundColor(.blue)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Welcome")
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }
    
    private func login() {
        Task {
            do {
                try await authService.login(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(FirebaseAuthService.shared)
}
