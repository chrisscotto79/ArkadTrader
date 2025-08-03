//
//  ProfileImageView.swift
//  ArkadTrader
//
//  Created by chris scotto on 8/2/25.
//


// File: Core/Profile/Views/ProfileImageView.swift
// Reusable Profile Image Component with Smart Fallbacks

import SwiftUI

struct ProfileImageView: View {
    let user: User?
    let size: CGFloat
    let showBorder: Bool
    let borderColor: Color
    let borderWidth: CGFloat
    
    // Additional customization options
    let shadowRadius: CGFloat
    let shadowOpacity: Double
    let shadowOffset: CGSize
    
    init(
        user: User?,
        size: CGFloat = 40,
        showBorder: Bool = false,
        borderColor: Color = .arkadGold,
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
        Group {
            if let imageUrl = user?.profileImageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        fallbackImageView
                    case .empty:
                        loadingImageView
                    @unknown default:
                        fallbackImageView
                    }
                }
            } else {
                fallbackImageView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            showBorder ? Circle().stroke(borderColor, lineWidth: borderWidth) : nil
        )
        .shadow(
            color: Color.black.opacity(shadowOpacity),
            radius: shadowRadius,
            x: shadowOffset.width,
            y: shadowOffset.height
        )
    }
    
    // MARK: - Private Views
    
    private var fallbackImageView: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.arkadGold.opacity(0.8),
                        Color.arkadGold.opacity(0.6)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(getInitials())
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private var loadingImageView: some View {
        Circle()
            .fill(Color.arkadGold.opacity(0.2))
            .overlay(
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.arkadGold)
            )
    }
    
    // MARK: - Helper Properties
    
    private var fontSize: CGFloat {
        // Scale font size based on circle size
        switch size {
        case 0..<30:
            return size * 0.3
        case 30..<60:
            return size * 0.35
        case 60..<100:
            return size * 0.4
        default:
            return size * 0.45
        }
    }
    
    private func getInitials() -> String {
        guard let user = user else { return "U" }
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first : nil
        
        if let lastInitial = lastInitial {
            return String(firstInitial) + String(lastInitial)
        } else {
            return String(firstInitial)
        }
    }
}

// MARK: - Convenience Initializers and Presets

extension ProfileImageView {
    // Small profile image (for lists, comments, etc.)
    static func small(user: User?) -> ProfileImageView {
        ProfileImageView(
            user: user,
            size: 32,
            showBorder: false
        )
    }
    
    // Medium profile image (for posts, cards, etc.)
    static func medium(user: User?) -> ProfileImageView {
        ProfileImageView(
            user: user,
            size: 48,
            showBorder: true,
            borderWidth: 2,
            shadowRadius: 4,
            shadowOpacity: 0.2,
            shadowOffset: CGSize(width: 0, height: 2)
        )
    }
    
    // Large profile image (for profile views, headers, etc.)
    static func large(user: User?) -> ProfileImageView {
        ProfileImageView(
            user: user,
            size: 80,
            showBorder: true,
            borderWidth: 3,
            shadowRadius: 8,
            shadowOpacity: 0.3,
            shadowOffset: CGSize(width: 0, height: 4)
        )
    }
    
    // Extra large profile image (for main profile display)
    static func extraLarge(user: User?) -> ProfileImageView {
        ProfileImageView(
            user: user,
            size: 120,
            showBorder: true,
            borderWidth: 4,
            shadowRadius: 12,
            shadowOpacity: 0.4,
            shadowOffset: CGSize(width: 0, height: 6)
        )
    }
    
    // Custom size with smart defaults
    static func custom(user: User?, size: CGFloat) -> ProfileImageView {
        let shouldShowBorder = size >= 40
        let borderWidth: CGFloat = size >= 80 ? 3 : 2
        let shadowRadius: CGFloat = size >= 60 ? 6 : (size >= 40 ? 4 : 0)
        let shadowOpacity: Double = size >= 40 ? 0.2 : 0
        
        return ProfileImageView(
            user: user,
            size: size,
            showBorder: shouldShowBorder,
            borderWidth: borderWidth,
            shadowRadius: shadowRadius,
            shadowOpacity: shadowOpacity,
            shadowOffset: CGSize(width: 0, height: shadowRadius / 2)
        )
    }
}

// MARK: - Clickable Profile Image Variant

struct ClickableProfileImageView: View {
    let user: User?
    let size: CGFloat
    let onTap: (() -> Void)?
    
    @State private var isPressed = false
    
    init(user: User?, size: CGFloat = 40, onTap: (() -> Void)? = nil) {
        self.user = user
        self.size = size
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            ProfileImageView.custom(user: user, size: size)
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .disabled(onTap == nil)
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

#Preview("Profile Image Sizes") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            VStack {
                ProfileImageView.small(user: .previewUser)
                Text("Small")
                    .font(.caption)
            }
            
            VStack {
                ProfileImageView.medium(user: .previewUser)
                Text("Medium")
                    .font(.caption)
            }
            
            VStack {
                ProfileImageView.large(user: .previewUser)
                Text("Large")
                    .font(.caption)
            }
            
            VStack {
                ProfileImageView.extraLarge(user: .previewUser)
                Text("Extra Large")
                    .font(.caption)
            }
        }
        
        ClickableProfileImageView(user: .previewUser, size: 60) {
            print("Profile tapped!")
        }
    }
    .padding()
}