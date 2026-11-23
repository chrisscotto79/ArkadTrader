// File: Core/Tickers/PostSentiment.swift
// The optional Bullish/Bearish tag on a post, its badge, and the composer's picker.
//
// Firestore: posts/{postId}.sentiment is "bullish" or "bearish", or missing for no tag.
// The rules only allow those two values (validSentiment() in firestore.rules).

import SwiftUI

enum PostSentiment: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case bullish
    case bearish

    /// The post field that stores the tag.
    static let firestoreField = "sentiment"

    var id: String { rawValue }

    /// Reads a stored value; anything other than "bullish" / "bearish" is no tag.
    init?(firestoreValue value: Any?) {
        guard let text = value as? String else { return nil }
        self.init(rawValue: text.lowercased().trimmingCharacters(in: .whitespaces))
    }

    var title: String {
        switch self {
        case .bullish: return "Bullish"
        case .bearish: return "Bearish"
        }
    }

    var systemImage: String {
        switch self {
        case .bullish: return "arrow.up.right"
        case .bearish: return "arrow.down.right"
        }
    }

    /// Adaptive market colours, readable in light and dark mode.
    var color: Color {
        switch self {
        case .bullish: return .marketGreen
        case .bearish: return .marketRed
        }
    }
}

// MARK: - Badge

/// Small green "Bullish" / red "Bearish" capsule for a post. Same shape as the app's `Tag`.
struct SentimentBadge: View {
    let sentiment: PostSentiment

    init(sentiment: PostSentiment) {
        self.sentiment = sentiment
    }

    var body: some View {
        Tag(text: sentiment.title, systemImage: sentiment.systemImage, tint: sentiment.color)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(sentiment.title)
    }
}

// MARK: - Picker

/// None / Bullish / Bearish chips for the post composer.
struct SentimentPicker: View {
    @Binding var selection: PostSentiment?

    init(selection: Binding<PostSentiment?>) {
        self._selection = selection
    }

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            chip(title: "None", systemImage: nil, tint: .primary, value: nil)
            ForEach(PostSentiment.allCases) { sentiment in
                chip(title: sentiment.title, systemImage: sentiment.systemImage,
                     tint: sentiment.color, value: sentiment)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sentiment")
    }

    private func chip(title: String, systemImage: String?, tint: Color, value: PostSentiment?) -> some View {
        let isSelected = selection == value
        return Button {
            guard selection != value else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy(duration: 0.2)) { selection = value }
        } label: {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? tint : Color.secondary)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                Capsule().fill(isSelected ? tint.opacity(0.14) : Color.surfaceRaised)
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? tint.opacity(0.45) : .clear, lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(value == nil ? "No sentiment" : title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Meter bar

/// Green (bullish) / red (bearish) bar. Pass the bullish share 0–100, or nil for a neutral
/// empty bar (not enough tagged posts). Used on the ticker page and in trending tickers.
struct SentimentMeterBar: View {
    let bullishPercent: Double?
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            if let bullishPercent {
                let fraction = min(max(bullishPercent / 100, 0), 1)
                // A thin gap where the two colours meet
                let gap: CGFloat = (fraction > 0 && fraction < 1) ? 2 : 0
                let available = max(0, proxy.size.width - gap)
                HStack(spacing: gap) {
                    if fraction > 0 {
                        Capsule()
                            .fill(Color.marketGreen)
                            .frame(width: available * fraction)
                    }
                    if fraction < 1 {
                        Capsule()
                            .fill(Color.marketRed)
                            .frame(width: available * (1 - fraction))
                    }
                }
            } else {
                Capsule().fill(Color.surfaceRaised)
            }
        }
        .frame(height: height)
        .animation(.snappy(duration: 0.3), value: bullishPercent)
        .accessibilityHidden(true)
    }
}

#Preview("Sentiment") {
    @Previewable @State var selection: PostSentiment? = .bullish
    VStack(alignment: .leading, spacing: 20) {
        SentimentPicker(selection: $selection)
        HStack {
            SentimentBadge(sentiment: .bullish)
            SentimentBadge(sentiment: .bearish)
        }
        SentimentMeterBar(bullishPercent: 62)
        SentimentMeterBar(bullishPercent: nil)
    }
    .padding()
    .cardStyle()
    .padding()
    .screenBackground()
}
