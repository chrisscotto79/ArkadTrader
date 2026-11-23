// File: Core/Learn/LearnPromoCard.swift
// Compact Home feed card that opens the Learn hub. Push-navigates inside the caller's
// NavigationStack (HomeView has one), so it needs no setup: `LearnPromoCard()`.

import SwiftUI

struct LearnPromoCard: View {
    @ObservedObject private var store = LearnProgressStore.shared

    var body: some View {
        NavigationLink {
            LearnHubView()
        } label: {
            label
        }
        .buttonStyle(PressableStyle())
        .task { await store.load() }
    }

    private var label: some View {
        let total = LearnContent.totalLessonCount
        let done = store.totalCompletedLessons
        let started = done > 0

        return HStack(spacing: DS.Spacing.m) {
            if started {
                LearnPercentRing(progress: total == 0 ? 0 : Double(done) / Double(total), size: 48)
            } else {
                IconWell(systemName: "graduationcap.fill", size: 48)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(started ? "Keep learning" : "New to trading?")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text(subtitle(done: done, total: total))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(DS.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .fill(Color.goldTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .strokeBorder(Color.goldText.opacity(0.25), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Learn")
    }

    private func subtitle(done: Int, total: Int) -> String {
        guard done > 0 else { return "Start with the basics" }
        if done >= total { return "All \(total) lessons done. Review any time." }
        if let next = store.continueLesson {
            return "\(done) of \(total) lessons · Next: \(next.title)"
        }
        return "\(done) of \(total) lessons done"
    }
}

#Preview {
    NavigationStack {
        LearnPromoCard()
            .padding()
            .screenBackground()
    }
}
