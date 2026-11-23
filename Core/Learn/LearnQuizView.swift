// File: Core/Learn/LearnQuizView.swift
// A track's quiz: one multiple-choice question at a time, with the explanation shown after
// answering, then a score summary. The best score is saved to learnProgress/{trackId}-quiz.

import SwiftUI

struct LearnQuizView: View {
    let track: LearnTrack
    @ObservedObject private var store = LearnProgressStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var selected: Int?
    @State private var correctCount = 0
    @State private var isFinished = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                if isFinished {
                    resultView
                } else if track.quiz.indices.contains(index) {
                    questionView(track.quiz[index])
                } else {
                    EmptyStateView(
                        systemImage: "questionmark.circle",
                        title: "No quiz yet",
                        message: "This track doesn't have a quiz."
                    )
                }

                LearnDisclaimer()
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .screenBackground()
        .navigationTitle("\(track.title) quiz")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    // MARK: - Question

    private func questionView(_ question: LearnQuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                HStack {
                    Text("Question \(index + 1) of \(track.quiz.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(correctCount) correct")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                LearnProgressBar(
                    progress: Double(index + (selected == nil ? 0 : 1)) / Double(max(track.quiz.count, 1)),
                    tint: track.tint.color,
                    height: 5
                )
            }

            Text(question.prompt)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: DS.Spacing.s) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { optionIndex, option in
                    optionButton(option, optionIndex: optionIndex, question: question)
                }
            }

            if let selected {
                explanation(question, isCorrect: selected == question.answerIndex)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                Button {
                    advance()
                } label: {
                    Text(index + 1 < track.quiz.count ? "Next question" : "See results")
                }
                .buttonStyle(PrimaryButtonStyle())
                .transition(.opacity)
            }
        }
    }

    private func optionButton(_ option: String, optionIndex: Int, question: LearnQuizQuestion) -> some View {
        let state = optionState(optionIndex, question: question)

        return Button {
            choose(optionIndex, question: question)
        } label: {
            HStack(alignment: .center, spacing: DS.Spacing.m) {
                Text(option)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                switch state {
                case .correct:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.marketGreen)
                case .wrong:
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.marketRed)
                case .idle, .dimmed:
                    EmptyView()
                }
            }
            .font(.title3)
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(state.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .strokeBorder(state.border, lineWidth: state == .idle ? 1 : 1.5)
            )
            .opacity(state == .dimmed ? 0.55 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(selected != nil)
        .accessibilityValue(state.accessibilityValue)
    }

    private enum OptionState: Equatable {
        case idle, correct, wrong, dimmed

        var fill: Color {
            switch self {
            case .idle, .dimmed: return .surface
            case .correct: return Color.marketGreen.opacity(0.12)
            case .wrong: return Color.marketRed.opacity(0.12)
            }
        }

        var border: Color {
            switch self {
            case .idle, .dimmed: return .hairline
            case .correct: return .marketGreen
            case .wrong: return .marketRed
            }
        }

        var accessibilityValue: String {
            switch self {
            case .correct: return "Correct answer"
            case .wrong: return "Your answer, incorrect"
            case .idle, .dimmed: return ""
            }
        }
    }

    private func optionState(_ optionIndex: Int, question: LearnQuizQuestion) -> OptionState {
        guard let selected else { return .idle }
        if optionIndex == question.answerIndex { return .correct }
        if optionIndex == selected { return .wrong }
        return .dimmed
    }

    private func explanation(_ question: LearnQuizQuestion, isCorrect: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(isCorrect ? "Correct" : "Not quite", systemImage: isCorrect ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isCorrect ? Color.marketGreen : Color.goldText)
            Text(question.explanation)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Result

    private var resultView: some View {
        let total = track.quiz.count
        let fraction = total == 0 ? 0 : Double(correctCount) / Double(total)

        return VStack(spacing: DS.Spacing.l) {
            LearnProgressRing(progress: fraction, tint: track.tint.color, size: 120, lineWidth: 12) {
                VStack(spacing: 0) {
                    Text("\(correctCount)/\(total)")
                        .arkadNumber(30)
                        .foregroundStyle(Color.primary)
                    Text("correct")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, DS.Spacing.l)

            VStack(spacing: 6) {
                Text(resultTitle(fraction))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(resultMessage(fraction))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let best = store.quizResult(for: track), best.score > correctCount {
                    Text("Your best is \(best.score) of \(best.total).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: DS.Spacing.m) {
                Button("Done") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Try again") { restart() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.top, DS.Spacing.s)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: DS.Spacing.xl)
    }

    private func resultTitle(_ fraction: Double) -> String {
        switch fraction {
        case 1: return "Perfect score"
        case 0.75...: return "Nicely done"
        case 0.5...: return "Good start"
        default: return "Keep going"
        }
    }

    private func resultMessage(_ fraction: Double) -> String {
        if fraction >= 0.75 {
            return "You've got the main ideas of \(track.title.lowercased()). Revisit a lesson any time."
        }
        return "Reread the lessons in \(track.title.lowercased()), then try again. There's no limit on retakes."
    }

    // MARK: - Actions

    private func choose(_ optionIndex: Int, question: LearnQuizQuestion) {
        guard selected == nil else { return }
        let isCorrect = optionIndex == question.answerIndex
        UINotificationFeedbackGenerator().notificationOccurred(isCorrect ? .success : .warning)
        withAnimation(.snappy(duration: 0.25)) {
            selected = optionIndex
            if isCorrect { correctCount += 1 }
        }
    }

    private func advance() {
        if index + 1 < track.quiz.count {
            withAnimation(.snappy(duration: 0.25)) {
                index += 1
                selected = nil
            }
        } else {
            store.recordQuiz(for: track, score: correctCount, total: track.quiz.count)
            withAnimation(.snappy(duration: 0.3)) {
                isFinished = true
            }
        }
    }

    private func restart() {
        withAnimation(.snappy(duration: 0.25)) {
            index = 0
            selected = nil
            correctCount = 0
            isFinished = false
        }
    }
}

#Preview {
    NavigationStack {
        LearnQuizView(track: LearnContent.tracks[0])
    }
}
