// File: Core/Profile/Views/ProfileImageView.swift
// A user's profile photo in a circle, with a gold initials fallback (from the full name).

import SwiftUI

struct ProfileImageView: View {
    let user: User?
    let size: CGFloat
    let showBorder: Bool
    let borderColor: Color
    let borderWidth: CGFloat

    // Kept for source compatibility; the Arkad style doesn't use avatar shadows.
    let shadowRadius: CGFloat
    let shadowOpacity: Double
    let shadowOffset: CGSize

    init(
        user: User?,
        size: CGFloat = 40,
        showBorder: Bool = false,
        borderColor: Color = .surface,
        borderWidth: CGFloat = 2,
        shadowRadius: CGFloat = 0,
        shadowOpacity: Double = 0,
        shadowOffset: CGSize = .zero
    ) {
        self.user = user
        self.size = size
        self.showBorder = showBorder
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
        self.shadowOffset = shadowOffset
    }

    var body: some View {
        ArkadAsyncImage(urlString: user?.profileImageUrl) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            fallbackImageView
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if showBorder {
                Circle().strokeBorder(borderColor, lineWidth: borderWidth)
            } else {
                Circle().strokeBorder(Color.hairline, lineWidth: 1)
            }
        }
        .shadow(
            color: Color.black.opacity(shadowOpacity),
            radius: shadowRadius,
            x: shadowOffset.width,
            y: shadowOffset.height
        )
        .accessibilityHidden(true)
    }

    // MARK: - Private Views

    private var fallbackImageView: some View {
        Circle()
            .fill(Color.arkadGold)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.onGold)
                    .minimumScaleFactor(0.5)
            )
    }

    // MARK: - Helpers

    private var initials: String {
        guard let user else { return "?" }
        let names = user.fullName.split(separator: " ")
        if let first = names.first?.first {
            let last = names.count > 1 ? names.last?.first.map(String.init) ?? "" : ""
            return (String(first) + last).uppercased()
        }
        let fromUsername = String(user.username.prefix(2)).uppercased()
        return fromUsername.isEmpty ? "?" : fromUsername
    }
}

// MARK: - Presets

extension ProfileImageView {
    /// Lists, comments
    static func small(user: User?) -> ProfileImageView {
        ProfileImageView(user: user, size: 32)
    }

    /// Posts, cards
    static func medium(user: User?) -> ProfileImageView {
        ProfileImageView(user: user, size: 48)
    }

    /// Headers
    static func large(user: User?) -> ProfileImageView {
        ProfileImageView(user: user, size: 80)
    }

    /// Main profile display
    static func extraLarge(user: User?) -> ProfileImageView {
        ProfileImageView(user: user, size: 112)
    }

    static func custom(user: User?, size: CGFloat) -> ProfileImageView {
        ProfileImageView(user: user, size: size)
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension User {
    static let previewUser = User(
        id: "preview-id",
        email: "john@example.com",
        username: "johndoe",
        fullName: "John Doe"
    )

    static let previewUserWithImage: User = {
        var user = User.previewUser
        user.profileImageUrl = "https://example.com/profile.jpg"
        return user
    }()
}
#endif

#Preview {
    let user = User(id: "preview", email: "john@example.com", username: "johndoe", fullName: "John Doe")
    HStack(spacing: 16) {
        ProfileImageView.small(user: user)
        ProfileImageView.medium(user: user)
        ProfileImageView.large(user: user)
    }
    .padding()
    .screenBackground()
}
