//
//  UserProfileCard.swift
//  ArkadTrader
//
//  Updated with navigation to other user profiles
//

import SwiftUI

struct UserProfileCard: View {
    let user: User
    @State private var isFollowing = false
    @State private var showOtherUserProfile = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        Button(action: {
            showOtherUserProfile = true
        }) {
            VStack(spacing: 16) {
                // Profile header
                HStack {
                    AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(user.username)")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.arkadGold)
                            .overlay(
                                Text(userInitials)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(user.fullName)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
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
                    
                    // Follow button (non-tappable for card navigation)
                    Button(action: {
                        // This button has its own action and won't trigger card navigation
                    }) {
                        SimpleFollowButton(targetUserId: user.id, targetUsername: user.username)
                    }
                    .buttonStyle(PlainButtonStyle())
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
                        Text("\(user.followersCount ?? 0)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Followers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("\(user.followingCount ?? 0)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
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
            .background(Color.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showOtherUserProfile) {
            OtherUserProfileView(user: user)
                .environmentObject(authService)
        }
    }
    
    private var userInitials: String {
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first : nil
        
        if let lastInitial = lastInitial {
            return String(firstInitial) + String(lastInitial)
        } else {
            return String(firstInitial)
        }
    }
    
    private var tierColor: Color {
        switch user.subscriptionTier {
        case .basic: return .gray
        case .pro: return .blue
        case .elite: return .arkadGold
        }
    }
}


