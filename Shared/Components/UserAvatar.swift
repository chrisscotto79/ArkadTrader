// File: Shared/Components/UserAvatar.swift
// Circular profile photo with a gold initials fallback. Resolves https:// and
// arkad-image:// photos through ArkadAsyncImage.

import SwiftUI

struct UserAvatar: View {
    let username: String
    var imageURL: String?
    var size: CGFloat = 40

    var body: some View {
        ArkadAsyncImage(urlString: imageURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            initials
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.hairline, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var initialsText: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        return String(trimmed.prefix(2)).uppercased()
    }

    private var initials: some View {
        Circle()
            .fill(Color.arkadGold)
            .overlay {
                if initialsText.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(Color.onGold)
                } else {
                    Text(initialsText)
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.onGold)
                        .minimumScaleFactor(0.5)
                }
            }
    }
}

#Preview {
    HStack(spacing: 12) {
        UserAvatar(username: "trader", size: 56)
        UserAvatar(username: "", size: 40)
        UserAvatar(username: "ab", imageURL: "https://example.com/missing.jpg", size: 32)
    }
    .padding()
    .screenBackground()
}
