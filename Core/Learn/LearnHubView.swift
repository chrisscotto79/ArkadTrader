// File: Core/Learn/LearnHubView.swift
// The Learn hub: overall progress, "Continue where you left off", the tracks, the
// position-size calculator and the glossary. Pushed onto the caller's NavigationStack
// (Discover and Home); it has no NavigationStack of its own.

import SwiftUI

struct LearnHubView: View {
    @ObservedObject private var store = LearnProgressStore.shared
    /// Captured when the hub is on screen, so the card's link doesn't change (and pop the
    /// lesson) while the user is in a lesson.
    @State private var continueTarget: LearnLesson?
    @State private var isVisible = false

    init() {
        _continueTarget = State(initialValue: LearnProgressStore.shared.continueLesson)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                overviewCard

                if let lesson = continueTarget,
                   let track = LearnContent.track(containing: lesson.id) {
                    continueCard(lesson: lesson, track: track)
                }

                tracksSection
                toolsSection

                LearnDisclaimer()
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .screenBackground()
        .navigationTitle("Learn")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            isVisible = true
            continueTarget = store.continueLesson
        }
        .onDisappear { isVisible = false }
        .task {
            await store.load()
            if isVisible { continueTarget = store.continueLesson }
        }
        .refreshable {
            await store.load(force: true)
            continueTarget = store.continueLesson
        }
    }

    // MARK: - Overview

    private var overviewCard: some View {
        let total = LearnContent.totalLessonCount
        let done = store.totalCompletedLessons
        let progress = total == 0 ? 0 : Double(done) / Double(total)
        let minutes = LearnContent.tracks.reduce(0) { $0 + $1.totalMinutes }

        return HStack(spacing: DS.Spacing.l) {
            VStack(alignment: .leading, spacing: 6) {
                Text(done == 0 ? "Learn to trade, step by step" : "Your progress")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.primary)
                Text(done == 0
                     ? "\(LearnContent.tracks.count) short tracks for stocks, options, crypto and forex. Bite-sized lessons and a quiz at the end of each."
                     : "\(done) of \(total) lessons done. Keep going at your own pace.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: DS.Spacing.s) {
                    Tag(text: "\(total) lessons", systemImage: "book.closed.fill")
                    Tag(text: "About \(minutes) min", systemImage: "clock.fill", tint: .secondary)
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
            LearnPercentRing(progress: progress, size: 64)
        }
        .cardStyle()
    }

    // MARK: - Continue

    private func continueCard(lesson: LearnLesson, track: LearnTrack) -> some View {
        NavigationLink {
            LearnLessonView(lesson: lesson, track: track)
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                Text(store.hasStarted ? "Continue where you left off" : "Start here")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.goldText)
                    .textCase(.uppercase)

                HStack(spacing: DS.Spacing.m) {
                    IconWell(systemName: track.systemImage, tint: track.tint.color, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lesson.title)
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("\(track.title) · \(lesson.minutes) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.onGold)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.arkadGold))
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Opens the lesson")
    }

    // MARK: - Tracks

    private var tracksSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Tracks", count: LearnContent.tracks.count)

            VStack(spacing: DS.Spacing.m) {
                ForEach(LearnContent.tracks) { track in
                    NavigationLink {
                        LearnTrackView(track: track)
                    } label: {
                        LearnTrackCard(track: track)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    // MARK: - Tools and glossary

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Tools")

            VStack(spacing: 0) {
                NavigationLink {
                    PositionSizeCalculatorView()
                } label: {
                    toolRow(
                        systemImage: "plusminus.circle.fill",
                        tint: LearnTint.teal.color,
                        title: "Position size calculator",
                        subtitle: "How many shares to buy for the risk you choose"
                    )
                }
                .buttonStyle(PressableStyle())

                Divider()
                    .overlay(Color.hairline)
                    .padding(.leading, DS.Spacing.l + 40 + DS.Spacing.m)

                NavigationLink {
                    LearnGlossaryView()
                } label: {
                    toolRow(
                        systemImage: "character.book.closed.fill",
                        tint: LearnTint.blue.color,
                        title: "Glossary",
                        subtitle: "\(LearnContent.glossary.count) trading terms, A to Z"
                    )
                }
                .buttonStyle(PressableStyle())
            }
            .cardStyle(padding: 0)
        }
    }

    private func toolRow(systemImage: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: systemImage, tint: tint, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        LearnHubView()
    }
}
