// File: Shared/Components/UserAvatar.swift
// Circular profile photo with a gold initials fallback. Resolves https:// and
// arkad-image:// photos through ArkadAsyncImage.
//
// Initials always come from `UserAvatar.initials(fullName:username:)` so the same person
// gets the same letters everywhere: first letter of the first and last word of the full
// name when there is one, otherwise the first two characters of the username.

import SwiftUI

struct UserAvatar: View {
    let username: String
    var fullName: String?
    var imageURL: String?
    var size: CGFloat

    /// Scales the initials with Dynamic Type; capped so they always fit the circle.
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

    init(username: String, fullName: String? = nil, imageURL: String? = nil, size: CGFloat = 40) {
        self.username = username
        self.fullName = fullName
        self.imageURL = imageURL
        self.size = size
    }

    /// Convenience for when the whole user is at hand (uses their full name for initials).
    init(user: User?, size: CGFloat = 40) {
        self.init(username: user?.username ?? "", fullName: user?.fullName,
                  imageURL: user?.profileImageUrl, size: size)
    }

    var body: some View {
        ArkadAsyncImage(urlString: imageURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            initialsView
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.hairline, lineWidth: 1))
        .accessibilityHidden(true)
    }

    // MARK: - Initials

    /// Initials for a person, the same way everywhere in the app.
    /// - Full name (or a username that contains spaces, e.g. a display name): first letter
    ///   of the first word + first letter of the last word ("Chris Scott" -> "CS", "Chris" -> "C").
    /// - Otherwise the first two characters of the username, without a leading "@" ("chris" -> "CH").
    /// Returns "" when there is nothing to show (the view then draws a person icon).
    static func initials(fullName: String?, username: String) -> String {
        let name = (fullName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = username.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))

        let source = name.isEmpty && handle.contains(" ") ? handle : name
        let words = source.split(whereSeparator: { $0.isWhitespace })
        if let first = words.first?.first {
            let last = words.count > 1 ? words.last?.first.map(String.init) ?? "" : ""
            return (String(first) + last).uppercased()
        }
        return String(handle.prefix(2)).uppercased()
    }

    private var initialsText: String {
        Self.initials(fullName: fullName, username: username)
    }

    private var initialsView: some View {
        Circle()
            .fill(Color.arkadGold)
            .overlay {
                if initialsText.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(Color.onGold)
                } else {
                    Text(initialsText)
                        .font(.system(size: min(size * 0.38 * textScale, size * 0.5),
                                      weight: .bold, design: .rounded))
                        .foregroundStyle(Color.onGold)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, size * 0.08)
                }
            }
    }
}

#Preview {
    HStack(spacing: 12) {
        UserAvatar(username: "trader", fullName: "Chris Scott", size: 56)
        UserAvatar(username: "trader", size: 56)
        UserAvatar(username: "", size: 40)
        UserAvatar(username: "ab", imageURL: "https://example.com/missing.jpg", size: 32)
    }
    .padding()
    .screenBackground()
}
