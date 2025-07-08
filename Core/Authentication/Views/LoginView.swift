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
            VStack(spacing: 10) {
                // Logo Image
                Image("arkad_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 350, height: 150)
                    .padding(.top, 90)
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
                .background(Color.arkadGold)
                .foregroundColor(.arkadBlack)
                .cornerRadius(10)
                .disabled(authService.isLoading || email.isEmpty || password.isEmpty)

                // Register Link
                Button("Don't have an account? Register") {
                    showRegister = true
                }
                .foregroundColor(.arkadGold)

                Spacer()
            }
            .padding()
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
