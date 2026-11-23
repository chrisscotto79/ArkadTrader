// File: Shared/Components/DesignSystem.swift
// Arkad's design system: adaptive colours, spacing, and the reusable building
// blocks every screen is made of. Works in light and dark mode.
//
// Rules of thumb
// - Screens sit on `Color.appBackground`; content sits on `.cardStyle()` surfaces.
// - Gold is an accent: filled buttons (with black text), selected states, small highlights.
//   For gold *text or icons* on a surface use `Color.goldText` so it stays readable in light mode.
// - Numbers use `.arkadNumber(...)` (rounded, monospaced digits).
// - Gains/losses use `Color.marketGreen` / `Color.marketRed` (adaptive).

import SwiftUI
import UIKit

// MARK: - Tokens

enum DS {
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let s: CGFloat = 10
        static let m: CGFloat = 14
        static let l: CGFloat = 20
        static let xl: CGFloat = 28
    }

    /// Horizontal page margin used by every screen
    static let pageMargin: CGFloat = 16
}

// MARK: - Adaptive colours

extension Color {
    /// A colour that switches between light and dark mode.
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// Page background behind cards
    static let appBackground = dynamic(
        light: UIColor(red: 0.961, green: 0.961, blue: 0.949, alpha: 1),   // #F5F5F2 warm off-white
        dark: UIColor(red: 0.039, green: 0.039, blue: 0.043, alpha: 1)     // #0A0A0B
    )

    /// Card / sheet surface
    static let surface = dynamic(
        light: .white,
        dark: UIColor(red: 0.086, green: 0.086, blue: 0.094, alpha: 1)     // #161618
    )

    /// Inputs, chips, secondary buttons, icon wells: one step up from `surface`
    static let surfaceRaised = dynamic(
        light: UIColor(red: 0.937, green: 0.937, blue: 0.922, alpha: 1),   // #EFEFEB
        dark: UIColor(red: 0.137, green: 0.137, blue: 0.149, alpha: 1)     // #232326
    )

    /// 1pt card borders and dividers
    static let hairline = dynamic(
        light: UIColor.black.withAlphaComponent(0.07),
        dark: UIColor.white.withAlphaComponent(0.09)
    )

    /// Gold that's readable as text/icons on `surface` in both modes
    static let goldText = dynamic(
        light: UIColor(red: 0.588, green: 0.408, blue: 0.0, alpha: 1),     // #966800
        dark: UIColor(red: 0.996, green: 0.729, blue: 0.090, alpha: 1)     // #FEBA17
    )

    /// Soft gold wash for selected rows, badges and highlights
    static let goldTint = dynamic(
        light: UIColor(red: 0.996, green: 0.729, blue: 0.090, alpha: 0.16),
        dark: UIColor(red: 0.996, green: 0.729, blue: 0.090, alpha: 0.18)
    )

    /// Text/icons placed on a solid gold fill
    static let onGold = Color.black

    /// High-contrast fill for selected chips (black in light mode, white in dark mode)
    static let inverseFill = Color(UIColor.label)
    /// Text on `inverseFill`
    static let inverseText = Color(UIColor.systemBackground)
}

// MARK: - Typography

extension View {
    /// Rounded, monospaced-digit number style for prices, P&L and stats.
    func arkadNumber(_ size: CGFloat, weight: Font.Weight = .bold) -> some View {
        font(.system(size: size, weight: weight, design: .rounded).monospacedDigit())
    }
}

// MARK: - Surfaces

struct CardStyle: ViewModifier {
    var padding: CGFloat = DS.Spacing.l
    var radius: CGFloat = DS.Radius.l

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.hairline, lineWidth: 1)
            )
    }
}

extension View {
    /// Standard Arkad card: surface fill, continuous corners, hairline border.
    func cardStyle(padding: CGFloat = DS.Spacing.l, radius: CGFloat = DS.Radius.l) -> some View {
        modifier(CardStyle(padding: padding, radius: radius))
    }

    /// Standard screen background (extends under safe areas).
    func screenBackground() -> some View {
        background(Color.appBackground.ignoresSafeArea())
    }
}

// MARK: - Buttons

/// Solid gold, full-width call to action.
struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.onGold)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 20)
            .frame(height: 52)
            .background(Capsule().fill(Color.arkadGold))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Neutral filled button (secondary action).
struct SecondaryButtonStyle: ButtonStyle {
    var fullWidth = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 20)
            .frame(height: 52)
            .background(Capsule().fill(Color.surfaceRaised))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Small capsule button for inline actions (Follow, Join, New Post).
struct PillButtonStyle: ButtonStyle {
    enum Kind { case gold, neutral, outline }
    var kind: Kind = .gold
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(
                Capsule().fill(background)
            )
            .overlay(
                Capsule().strokeBorder(kind == .outline ? Color.hairline : .clear, lineWidth: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .gold: return .onGold
        case .neutral, .outline: return .primary
        }
    }

    private var background: Color {
        switch kind {
        case .gold: return .arkadGold
        case .neutral: return .surfaceRaised
        case .outline: return .clear
        }
    }
}

/// Subtle press feedback for tappable cards and rows.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Round icon-only button (header actions like settings, compose, close).
struct IconButton: View {
    let systemName: String
    var accessibilityLabel: String
    var size: CGFloat = 38
    var filled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(filled ? Color.onGold : Color.primary)
                .frame(width: size, height: size)
                .background(Circle().fill(filled ? Color.arkadGold : Color.surfaceRaised))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Headers

/// Large, left-aligned screen title with optional trailing actions.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.top, DS.Spacing.s)
        .padding(.bottom, DS.Spacing.m)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Section title inside a screen ("Your communities", "Open positions") with an optional action.
struct SectionHeader: View {
    let title: String
    var count: Int? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            if let count {
                Text("\(count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.goldText)
            }
        }
    }
}

// MARK: - Segmented control

/// Capsule segmented control used for in-screen tabs (For You / Following / News, etc.).
struct SegmentedPicker<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.snappy(duration: 0.25)) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.inverseText : Color.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.inverseFill)
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.surfaceRaised))
    }
}

// MARK: - Chips

/// Filter chip. Selected chips use the high-contrast inverse fill.
struct Chip: View {
    let title: String
    var systemImage: String? = nil
    var isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption.weight(.semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.inverseText : Color.primary)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(isSelected ? Color.inverseFill : Color.surfaceRaised))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Small static label ("Owner", "Private", "AAPL").
struct Tag: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .goldText

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.14)))
    }
}

/// Green/red capsule showing a gain or loss.
struct ChangePill: View {
    let text: String
    let isPositive: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
            Text(text)
                .font(.caption.weight(.semibold).monospacedDigit())
        }
        .foregroundStyle(isPositive ? Color.marketGreen : Color.marketRed)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill((isPositive ? Color.marketGreen : Color.marketRed).opacity(0.14)))
    }
}

// MARK: - Icon well

/// SF Symbol inside a tinted rounded square (settings rows, stat cards, empty states).
struct IconWell: View {
    let systemName: String
    var tint: Color = .goldText
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Stats

/// Label + big number tile.
struct StatTile: View {
    let title: String
    let value: String
    var valueColor: Color = .primary
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .arkadNumber(20)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14, radius: DS.Radius.m)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            IconWell(systemName: systemImage, size: 64)
            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, DS.Spacing.xl)
    }
}

// MARK: - Brand

/// The Arkad logo (switches to the white wordmark in dark mode).
struct ArkadLogo: View {
    var height: CGFloat = 28

    var body: some View {
        Image("arkad_logo")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityLabel("Arkad")
    }
}

/// Just the bearded-face mark, for compact spots (avatars, badges, launch).
struct ArkadMark: View {
    var size: CGFloat = 32

    var body: some View {
        Image("arkad_mark")
            .resizable()
            .scaledToFit()
            .frame(height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Appearance setting

/// User's light/dark preference (Settings > Appearance).
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appAppearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Previews

#Preview("Components") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader(title: "Communities", subtitle: "Trade together") {
                IconButton(systemName: "plus", accessibilityLabel: "Create", filled: true) {}
            }
            SegmentedPicker(options: ["For You", "Following", "News"], selection: .constant("For You")) { $0 }
                .padding(.horizontal)
            HStack {
                Chip(title: "All", isSelected: true) {}
                Chip(title: "Stocks", isSelected: false) {}
                Tag(text: "Owner", systemImage: "crown.fill")
                ChangePill(text: "+2.4%", isPositive: true)
            }
            .padding(.horizontal)
            HStack {
                StatTile(title: "Total P&L", value: "+$1,284", valueColor: .marketGreen)
                StatTile(title: "Win rate", value: "62%")
            }
            .padding(.horizontal)
            VStack(alignment: .leading) {
                SectionHeader(title: "Open positions", count: 3, actionTitle: "See all") {}
                Text("Card content").foregroundStyle(.secondary)
            }
            .cardStyle()
            .padding(.horizontal)
            Button("Join community") {}.buttonStyle(PrimaryButtonStyle()).padding(.horizontal)
            Button("Not now") {}.buttonStyle(SecondaryButtonStyle()).padding(.horizontal)
            EmptyStateView(systemImage: "person.3.fill", title: "No communities yet", message: "Join one to see callouts here.", actionTitle: "Discover") {}
        }
    }
    .screenBackground()
}
