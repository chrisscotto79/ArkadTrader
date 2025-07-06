import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if !errorMessage.isEmpty {
                Text(errorMessage).foregroundColor(.red)
            }

            Button("Sign In") { Task { await signIn() } }
                .buttonStyle(.borderedProminent)

            Button("Register") { Task { await register() } }
                .buttonStyle(.bordered)
        }
        .padding()
    }

    private func signIn() async {
        do {
            try await authService.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func register() async {
        do {
            let name = email.split(separator: "@").first.map(String.init) ?? "user"
            try await authService.register(email: email, password: password, username: name, fullName: name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    LoginView().environmentObject(FirebaseAuthService.shared)
}
