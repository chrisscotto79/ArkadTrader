// File: Shared/Components/UserAvatar.swift
// Circular profile photo with an initials fallback.

import SwiftUI

struct UserAvatar: View {
    let username: String
    var imageURL: String?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Circle()
            .fill(LinearGradient(colors: [.arkadGold, .arkadGoldDark], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Text(String(username.prefix(2)).uppercased())
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundColor(.black)
            )
    }
}
