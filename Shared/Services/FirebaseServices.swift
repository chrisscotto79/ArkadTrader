import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

@MainActor
class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    private let db = Firestore.firestore()

    private init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let uid = user?.uid {
                Task { await self?.loadUser(uid: uid) }
            } else {
                self?.currentUser = nil
                self?.isAuthenticated = false
            }
        }
    }

    func login(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        await loadUser(uid: result.user.uid)
    }

    func register(email: String, password: String, username: String, fullName: String = "") async throws {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        var newUser = User(id: authResult.user.uid, email: email, username: username, fullName: fullName.isEmpty ? username : fullName)
        try await db.collection("users").document(newUser.id).setData(newUser.toFirestore())
        currentUser = newUser
        isAuthenticated = true
    }

    func logout() async throws {
        try Auth.auth().signOut()
        currentUser = nil
        isAuthenticated = false
    }

    private func loadUser(uid: String) async {
        guard let data = try? await db.collection("users").document(uid).getDocument().data(),
              let user = try? User.fromFirestore(data: data, id: uid) else {
            self.currentUser = nil
            self.isAuthenticated = false
            return
        }
        self.currentUser = user
        self.isAuthenticated = true
    }
}
