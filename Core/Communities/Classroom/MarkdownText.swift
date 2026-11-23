// File: Core/Communities/Classroom/MarkdownText.swift
// Renders lesson Markdown in the Learn lesson style. SwiftUI's Text only lays out inline
// Markdown, so the blocks (headings, lists, quotes, code, rules) are split here and each
// line's inline Markdown (bold, italic, code, links) goes through AttributedString(markdown:).
// Only https links are kept and opened. Parsed results are cached, so a lesson isn't parsed
// again every time its view is rebuilt.

import SwiftUI

enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullets([String])
    case numbered(start: Int, items: [String])
    case quote(String)
    case code(String)
    case rule

    // MARK: - Parsing

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var numbered: [String] = []
        var numberedStart = 1
        var quote: [String] = []
        var code: [String] = []
        var inCode = false

        func flushParagraph() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))) }
            paragraph = []
        }
        func flushLists() {
            if !bullets.isEmpty { blocks.append(.bullets(bullets)) }
            if !numbered.isEmpty { blocks.append(.numbered(start: numberedStart, items: numbered)) }
            bullets = []
            numbered = []
        }
        func flushQuote() {
            if !quote.isEmpty { blocks.append(.quote(quote.joined(separator: "\n"))) }
            quote = []
        }
        func flushAll() {
            flushParagraph()
            flushLists()
            flushQuote()
        }

        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(code.joined(separator: "\n")))
                    code = []
                    inCode = false
                } else {
                    flushAll()
                    inCode = true
                }
                continue
            }
            if inCode {
                code.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushAll()
                continue
            }

            if let heading = headingLine(line) {
                flushAll()
                blocks.append(.heading(level: heading.level, text: heading.text))
                continue
            }

            if isRule(line) {
                flushAll()
                blocks.append(.rule)
                continue
            }

            if line.hasPrefix(">") {
                flushParagraph()
                flushLists()
                quote.append(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
                continue
            }

            if let item = bulletItem(line) {
                flushParagraph()
                flushQuote()
                if !numbered.isEmpty { flushLists() }
                bullets.append(item)
                continue
            }

            if let item = numberedItem(line) {
                flushParagraph()
                flushQuote()
                if !bullets.isEmpty { flushLists() }
                if numbered.isEmpty { numberedStart = item.number }
                numbered.append(item.text)
                continue
            }

            // A plain line right after a list item continues that item
            if !rawLine.isEmpty, rawLine.first?.isWhitespace == true {
                if !bullets.isEmpty {
                    bullets[bullets.count - 1] += " " + line
                    continue
                }
                if !numbered.isEmpty {
                    numbered[numbered.count - 1] += " " + line
                    continue
                }
            }

            flushLists()
            flushQuote()
            paragraph.append(line)
        }

        if inCode, !code.isEmpty { blocks.append(.code(code.joined(separator: "\n"))) }
        flushAll()
        return blocks
    }

    private static func headingLine(_ line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes) else { return nil }
        let rest = line.dropFirst(hashes)
        guard rest.first == " " else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : (hashes, text)
    }

    private static func isRule(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    private static func bulletItem(_ line: String) -> String? {
        guard let first = line.first, "-*+".contains(first) else { return nil }
        let rest = line.dropFirst()
        guard rest.first == " " else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    private static func numberedItem(_ line: String) -> (number: Int, text: String)? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 4, let number = Int(digits) else { return nil }
        let rest = line.dropFirst(digits.count)
        guard let marker = rest.first, marker == "." || marker == ")" else { return nil }
        let afterMarker = rest.dropFirst()
        guard afterMarker.first == " " else { return nil }
        let text = afterMarker.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : (number, text)
    }

    // MARK: - Inline

    /// Inline Markdown (bold, italic, `code`, [links](https://…)); falls back to plain text.
    /// Links that aren't https are dropped (their text stays).
    static func inline(_ text: String) -> AttributedString {
        if let hit = MarkdownCache.inline.object(forKey: text as NSString) { return hit.value }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        var result = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        for run in result.runs {
            if let url = run.link, url.scheme?.lowercased() != "https" {
                result[run.range].link = nil
            }
        }
        MarkdownCache.inline.setObject(MarkdownCache.Box(result), forKey: text as NSString)
        return result
    }

    /// `parse`, cached by the Markdown text.
    static func cachedParse(_ markdown: String) -> [MarkdownBlock] {
        if let hit = MarkdownCache.blocks.object(forKey: markdown as NSString) { return hit.value }
        let blocks = parse(markdown)
        MarkdownCache.blocks.setObject(MarkdownCache.Box(blocks), forKey: markdown as NSString)
        return blocks
    }
}

/// Parsed lesson Markdown, kept in memory (NSCache drops entries under memory pressure).
private enum MarkdownCache {
    final class Box<Value>: NSObject {
        let value: Value
        init(_ value: Value) { self.value = value }
    }

    static let blocks: NSCache<NSString, Box<[MarkdownBlock]>> = {
        let cache = NSCache<NSString, Box<[MarkdownBlock]>>()
        cache.countLimit = 50
        return cache
    }()

    static let inline: NSCache<NSString, Box<AttributedString>> = {
        let cache = NSCache<NSString, Box<AttributedString>>()
        cache.countLimit = 2000
        return cache
    }()
}

/// A block of lesson Markdown, laid out like the app's Learn lessons.
struct MarkdownText: View {
    private let blocks: [MarkdownBlock]
    var tint: Color

    init(_ markdown: String, tint: Color = .goldText) {
        self.blocks = MarkdownBlock.cachedParse(markdown)
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(tint)
        // Only https links open, whatever the Markdown says
        .environment(\.openURL, OpenURLAction { url in
            url.scheme?.lowercased() == "https" ? .systemAction : .discarded
        })
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(MarkdownBlock.inline(text))
                .font(headingFont(level))
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, level <= 2 ? DS.Spacing.s : DS.Spacing.xs)
                .accessibilityAddTraits(.isHeader)

        case .paragraph(let text):
            Text(MarkdownBlock.inline(text))
                .font(.body)
                .foregroundStyle(Color.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                        Circle()
                            .fill(tint)
                            .frame(width: 6, height: 6)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                            .accessibilityHidden(true)
                        Text(MarkdownBlock.inline(item))
                            .font(.body)
                            .foregroundStyle(Color.primary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .numbered(let start, let items):
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                        Text("\(start + index).")
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(tint)
                            .frame(minWidth: 22, alignment: .leading)
                        Text(MarkdownBlock.inline(item))
                            .font(.body)
                            .foregroundStyle(Color.primary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .quote(let text):
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                Image(systemName: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.goldText)
                    .accessibilityHidden(true)
                Text(MarkdownBlock.inline(text))
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.l)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(Color.goldTint)
            )

        case .code(let text):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.callout.monospaced())
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: true, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.l)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(Color.surfaceRaised)
            )

        case .rule:
            Divider()
                .overlay(Color.hairline)
                .padding(.vertical, DS.Spacing.xs)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2.weight(.bold)
        case 2: return .title3.weight(.bold)
        default: return .headline
        }
    }
}

#Preview {
    ScrollView {
        MarkdownText("""
        # Reading the tape
        Price is the **only** thing that pays. Read [the guide](https://example.com).

        - Watch volume on breakouts
        - Respect your *stop*

        1. Plan the trade
        2. Trade the plan

        > Size so a loss doesn't hurt.

        ```
        risk = (entry - stop) * shares
        ```
        """)
        .padding()
    }
    .screenBackground()
}
