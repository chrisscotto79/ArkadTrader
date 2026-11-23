// File: Core/Communities/Views/Chat/ReplyQuoteHeader.swift
// The compact quote above a reply: who it answers and a one-line preview.
// Tapping it jumps to the original when that message is loaded.

import SwiftUI

struct ReplyQuoteHeader: View {
    let reply: MessageReplyRef
    /// The original is in the loaded messages, so tapping can scroll to it
    var canJump: Bool = true
    /// The original has been deleted since
    var isOriginalDeleted: Bool = false
    let onTap: () -> Void

    private var quoteText: String {
        if isOriginalDeleted { return "Original message deleted" }
        return reply.preview.isEmpty ? "Original message" : reply.preview
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(reply.authorUsername.isEmpty ? "Reply" : reply.authorUsername)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.goldText)
                    .lineLimit(1)
                    .layoutPriority(1)
                Text(quoteText)
                    .font(.caption)
                    .italic(isOriginalDeleted)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                    .fill(Color.surfaceRaised.opacity(0.6))
            )
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.arkadGold)
                    .frame(width: 3)
                    .padding(.vertical, 4)
            }
            .frame(maxWidth: 280, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!canJump)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reply to \(reply.authorUsername): \(quoteText)")
        .accessibilityHint(canJump ? "Shows the original message" : "")
    }
}

#Preview {
    VStack(alignment: .leading) {
        ReplyQuoteHeader(
            reply: MessageReplyRef(messageId: "1", authorId: "a", authorUsername: "trader",
                                   preview: "Long $TSLA callout"),
            onTap: {}
        )
    }
    .padding()
}
