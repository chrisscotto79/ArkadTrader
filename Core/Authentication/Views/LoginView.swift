// File: Core/Authentication/Views/LoginView.swift

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showRegister = false
    @State private var showForgotPassword = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                // Logo - Text-Based (Professional)
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
                    TextField("Email", text: $authViewModel.email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $authViewModel.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Login") {
                        Task {
                            await authViewModel.login()
                        }
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadBlack)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.arkadGold)
                    .cornerRadius(12)
                    .disabled(authViewModel.isLoading)
                    
                    if authViewModel.isLoading {
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
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
            .alert("Error", isPresented: $authViewModel.showError) {
                Button("OK") { }
            } message: {
                Text(authViewModel.errorMessage)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
