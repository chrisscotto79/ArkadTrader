// File: Core/Learn/LearnComponents.swift
// Small building blocks shared by the Learn screens: progress ring and bar, track card,
// lesson meta line and the education disclaimer.

import SwiftUI

// MARK: - Progress ring

struct LearnProgressRing<Center: View>: View {
    let progress: Double
    var tint: Color = .goldText
    var size: CGFloat = 44
    var lineWidth: CGFloat = 5
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy(duration: 0.4), value: progress)
            center()
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((progress * 100).rounded())) percent complete")
    }
}

extension LearnProgressRing where Center == EmptyView {
    init(progress: Double, tint: Color = .goldText, size: CGFloat = 44, lineWidth: CGFloat = 5) {
        self.init(progress: progress, tint: tint, size: size, lineWidth: lineWidth) { EmptyView() }
    }
}

/// Ring with a percentage (or a checkmark when complete) in the middle.
struct LearnPercentRing: View {
    let progress: Double
    var tint: Color = .goldText
    var size: CGFloat = 44

    var body: some View {
        LearnProgressRing(progress: progress, tint: tint, size: size, lineWidth: size * 0.11) {
            if progress >= 1 {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.32, weight: .bold))
                    .foregroundStyle(tint)
            } else {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: size * 0.24, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.primary)
                    .minimumScaleFactor(0.6)
            }
        }
    }
}

// MARK: - Progress bar

struct LearnProgressBar: View {
    let progress: Double
    var tint: Color = .goldText
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.16))
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * max(0, min(progress, 1)))
                    .animation(.snappy(duration: 0.4), value: progress)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Track card

/// A track in the Learn hub: icon, title, one-line summary, lesson count and progress.
struct LearnTrackCard: View {
    let track: LearnTrack
    @ObservedObject private var store = LearnProgressStore.shared

    var body: some View {
        let progress = store.progress(for: track)
        let completed = store.completedLessonCount(in: track)

        HStack(alignment: .center, spacing: DS.Spacing.m) {
            IconWell(systemName: track.systemImage, tint: track.tint.color, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text(track.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DS.Spacing.s) {
                    LearnProgressBar(progress: progress, tint: track.tint.color, height: 5)
                        .frame(maxWidth: 120)
                    Text(progressCaption(completed: completed))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)

            if store.isTrackComplete(track) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(track.tint.color)
                    .accessibilityLabel("Complete")
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .cardStyle(padding: 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func progressCaption(completed: Int) -> String {
        if completed == 0 {
            return "\(track.lessons.count) lessons · \(track.totalMinutes) min"
        }
        return "\(completed) of \(track.lessons.count) lessons"
    }
}

// MARK: - Disclaimer

/// Footer line on lesson, quiz and tool screens.
struct LearnDisclaimer: View {
    var body: some View {
        Label("For education only. This isn't financial advice.", systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .padding(.vertical, DS.Spacing.s)
    }
}
