//
//  UserProfileCard.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/16/25.
//


import SwiftUI

struct UserProfileCard: View {
    let user: User
    @State private var isFollowing = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile header
            HStack {
                AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(user.username)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(user.fullName)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(user.subscriptionTier.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tierColor.opacity(0.1))
                        .foregroundColor(tierColor)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // Follow button
                FollowButton(targetUserId: user.id, targetUsername: user.username)
            }
            
            // Bio
            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Stats
            HStack {
                VStack {
                    Text("\(user.followersCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Followers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("\(user.followingCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Following")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text(user.totalProfitLoss.asCurrency)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(user.totalProfitLoss >= 0 ? .green : .red)
                    Text("Total P&L")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var tierColor: Color {
        switch user.subscriptionTier {
        case .basic: return .gray
        case .pro: return .blue
        case .elite: return .gold
        }
    }
}

extension Color {
    static let gold = Color(.systemYellow)
}