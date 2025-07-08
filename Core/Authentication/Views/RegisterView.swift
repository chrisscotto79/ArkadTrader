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
            VStack(spacing: 16) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.arkadGold)
                    .padding(.top, 10)

                Group {
                    TextField("Full Name", text: $fullName)
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                    TextField("Email", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                }
                .padding()
                .background(Color.arkadWhite)
                .cornerRadius(10)
                .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)

                Button(action: register) {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .arkadBlack))
                    } else {
                        Text("Register")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.arkadGold)
                            .foregroundColor(.arkadBlack)
                            .cornerRadius(10)
                    }
                }
                .disabled(authService.isLoading || !isFormValid)

                Spacer()
            }
            .padding()
            .background(Color.arkadWhite.ignoresSafeArea())
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            }.foregroundColor(.arkadGold))
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
