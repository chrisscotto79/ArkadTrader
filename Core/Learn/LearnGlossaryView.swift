// File: Core/Learn/LearnGlossaryView.swift
// Searchable A–Z list of trading terms.

import SwiftUI

struct LearnGlossaryView: View {
    @State private var query = ""

    private var sortedTerms: [LearnGlossaryTerm] {
        LearnContent.glossary.sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
    }

    private var filteredTerms: [LearnGlossaryTerm] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sortedTerms }
        return sortedTerms.filter {
            $0.term.localizedCaseInsensitiveContains(trimmed) || $0.definition.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// Terms grouped by first letter, in order.
    private var sections: [(letter: String, terms: [LearnGlossaryTerm])] {
        var result: [(letter: String, terms: [LearnGlossaryTerm])] = []
        for term in filteredTerms {
            if let last = result.last, last.letter == term.letter {
                result[result.count - 1].terms.append(term)
            } else {
                result.append((letter: term.letter, terms: [term]))
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.l, pinnedViews: [.sectionHeaders]) {
                if sections.isEmpty {
                    EmptyStateView(
                        systemImage: "character.book.closed",
                        title: "No matches",
                        message: "Nothing in the glossary matches “\(query)”."
                    )
                } else {
                    ForEach(sections, id: \.letter) { section in
                        Section {
                            VStack(spacing: 0) {
                                ForEach(Array(section.terms.enumerated()), id: \.element.id) { index, term in
                                    if index > 0 {
                                        Divider()
                                            .overlay(Color.hairline)
                                            .padding(.leading, DS.Spacing.l)
                                    }
                                    termRow(term)
                                }
                            }
                            .cardStyle(padding: 0)
                        } header: {
                            Text(section.letter)
                                .font(.headline)
                                .foregroundStyle(Color.goldText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(Color.appBackground)
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.immediately)
        .screenBackground()
        .navigationTitle("Glossary")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search terms")
        .autocorrectionDisabled()
    }

    private func termRow(_ term: LearnGlossaryTerm) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(term.term)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
            Text(term.definition)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        LearnGlossaryView()
    }
}
