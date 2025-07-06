import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: FirebaseAuthService

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let user = authService.currentUser {
                    Text("Welcome, \(user.username)")
                        .font(.title)
                }
                Button("Sign Out") {
                    Task { try? await authService.logout() }
                }
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView().environmentObject(FirebaseAuthService.shared)
}
