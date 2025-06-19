//
//  UserListView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

//
//  UserListView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

import SwiftUI

struct UserListView: View {
    let users: [User]
    let title: String
    
    var body: some View {
        NavigationView {
            List(users) { user in
                UserRowView(user: user)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct UserRowView: View {
    let user: User
    @State private var isFollowing = false
    
    var body: some View {
        HStack {
            // Profile picture placeholder
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(userInitials)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.fullName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button(action: {
                isFollowing.toggle()
            }) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                    .foregroundColor(isFollowing ? .primary : .white)
                    .cornerRadius(20)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var userInitials: String {
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first ?? Character("") : Character("")
        return String(firstInitial) + String(lastInitial)
    }
}

#Preview {
    let sampleUsers = [
        User(email: "john@example.com", username: "johndoe", fullName: "John Doe"),
        User(email: "jane@example.com", username: "janesmith", fullName: "Jane Smith")
    ]
    
    UserListView(users: sampleUsers, title: "Following")
}
