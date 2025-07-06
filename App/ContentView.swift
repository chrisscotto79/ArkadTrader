import SwiftUI

struct ContentView: View {
    @StateObject private var authService = FirebaseAuthService.shared

    var body: some View {
        if authService.isAuthenticated {
            HomeView()
                .environmentObject(authService)
        } else {
            LoginView()
                .environmentObject(authService)
        }
    }
}

#Preview {
    ContentView()
}
