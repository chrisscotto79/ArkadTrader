// File: Core/Authentication/Views/RegisterView.swift
// Simplified Register View

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var fullName = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 20)
                
                // Full Name
                TextField("Full Name", text: $fullName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Username
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                
                // Email
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                // Password
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Register Button
                Button(action: register) {
                    if authService.isLoading {
                        ProgressView()
                    } else {
                        Text("Register")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(authService.isLoading || !isFormValid)
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && !username.isEmpty && !fullName.isEmpty
    }
    
    private func register() {
        Task {
            do {
                try await authService.register(
                    email: email,
                    password: password,
                    username: username,
                    fullName: fullName
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(FirebaseAuthService.shared)
}
