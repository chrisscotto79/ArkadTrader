// File: Core/Settings/Views/HelpCenterView.swift
// Help Center: a searchable FAQ about features the app really has, plus a link to email support.

import SwiftUI

struct HelpCenterView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            List {
                if filteredTopics.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.gray)
                            Text("No answers match \"\(searchText)\"")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else {
                    ForEach(filteredTopics) { topic in
                        Section(topic.title) {
                            ForEach(topic.questions) { item in
                                FAQRow(item: item, startExpanded: !trimmedSearch.isEmpty)
                            }
                        }
                    }
                }

                Section {
                    EmailSupportButton(title: "Still need help? Email us", subject: "ArkadTrader Help")
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } footer: {
                    Text("Your app version and iOS version are added to the email for you.")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search questions")
            .navigationTitle("Help Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredTopics: [FAQTopic] {
        let query = trimmedSearch
        guard !query.isEmpty else { return FAQTopic.all }
        return FAQTopic.all.compactMap { topic in
            let matches = topic.questions.filter {
                $0.question.localizedCaseInsensitiveContains(query) ||
                $0.answer.localizedCaseInsensitiveContains(query) ||
                topic.title.localizedCaseInsensitiveContains(query)
            }
            return matches.isEmpty ? nil : FAQTopic(title: topic.title, questions: matches)
        }
    }
}

// MARK: - FAQ Row

private struct FAQRow: View {
    let item: FAQItem
    let startExpanded: Bool
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(item.answer)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)
        } label: {
            Text(item.question)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.textPrimary)
        }
        .tint(.arkadGoldDark)
        .onAppear { if startExpanded { isExpanded = true } }
        .onChange(of: startExpanded) { _, newValue in isExpanded = newValue }
    }
}

// MARK: - FAQ Content

struct FAQItem: Identifiable {
    let question: String
    let answer: String
    var id: String { question }
}

struct FAQTopic: Identifiable {
    let title: String
    let questions: [FAQItem]
    var id: String { title }

    static let all: [FAQTopic] = [
        FAQTopic(title: "Portfolio", questions: [
            FAQItem(
                question: "How do I log a trade?",
                answer: "Open the Portfolio tab and tap Add Trade. Choose the asset type, then enter the ticker, entry price, quantity and entry date. Notes are optional. ArkadTrader is a journal: trades are entered by you and nothing is placed with a broker."
            ),
            FAQItem(
                question: "How do I close a trade?",
                answer: "In Portfolio, tap an open trade and choose Close. Enter the exit price and exit date. The trade moves to Closed and its profit or loss counts toward your realized P&L."
            ),
            FAQItem(
                question: "Can I edit or delete a trade?",
                answer: "Yes. Tap any trade in Portfolio to edit its details or delete it. Some fields are read-only once a position is closed. Deleting a trade cannot be undone."
            ),
            FAQItem(
                question: "What is the starting balance?",
                answer: "It is the cash you started with. Portfolio uses it to work out your account value and available cash. Set it the first time you open Portfolio, or later with Set balance."
            ),
            FAQItem(
                question: "How do I record a deposit or withdrawal?",
                answer: "In Portfolio, tap Deposit / Withdraw and enter the amount. Your account balance is adjusted by that amount."
            ),
            FAQItem(
                question: "What does the Realized P&L chart show?",
                answer: "It shows the running total of profit and loss from your closed trades over time. Use 1W, 1M, 1Y or All to change the range. Open trades are not included until you close them."
            ),
            FAQItem(
                question: "Where do the prices of open positions come from?",
                answer: "Open stock positions are revalued with market quotes from Finnhub when quotes are available. Other positions, or any stock without a quote, are valued at your entry price."
            )
        ]),
        FAQTopic(title: "Feed & Posts", questions: [
            FAQItem(
                question: "How do I post?",
                answer: "On the Home tab, tap New Post. Write up to 500 characters, add $TICKERS and hashtags, and attach up to 6 images such as charts or screenshots, then tap Post."
            ),
            FAQItem(
                question: "How do I share a trade result?",
                answer: "When creating a post, choose the Trade Result post type and fill in the ticker, entry price, exit price and position size. The numbers show as a trade card on your post. Leave P&L blank to have it worked out for you."
            ),
            FAQItem(
                question: "How do I delete one of my posts?",
                answer: "Tap the ••• (More) menu on your post and choose Delete Post. This cannot be undone."
            ),
            FAQItem(
                question: "What are the For You, Following and News tabs?",
                answer: "For You shows recent posts from everyone. Following shows posts from people you follow. News shows general market news from Finnhub."
            )
        ]),
        FAQTopic(title: "People", questions: [
            FAQItem(
                question: "How do I follow someone?",
                answer: "Open their profile by tapping their name or avatar, or find them with Search, then tap Follow. Their posts appear in your Following feed. Tap the button again to unfollow."
            ),
            FAQItem(
                question: "What can I search for?",
                answer: "Use the Search tab to find people, posts, trades by ticker, and communities. Filter the results by type with the buttons under the search bar."
            ),
            FAQItem(
                question: "How do I edit my profile?",
                answer: "Go to the Profile tab, tap the gear icon to open Settings, and tap Edit Profile. You can change your profile photo, full name, username and bio (up to 150 characters)."
            )
        ]),
        FAQTopic(title: "Communities", questions: [
            FAQItem(
                question: "How do I join or create a community?",
                answer: "Open the Communities tab. Browse Discover to find and join a community, or tap Create to start your own with a name, description and optional avatar and banner. Communities you belong to are listed under Joined."
            ),
            FAQItem(
                question: "What are channels?",
                answer: "Each community has channels for different topics. Open a channel to chat with members, reply to and react to messages, and share images and documents."
            ),
            FAQItem(
                question: "What is a trade callout?",
                answer: "A callout is a trade idea posted in a channel with a ticker, direction, entry price and, optionally, a stop and target. Members can tap Track in Portfolio to log it as their own trade, and its status can be updated as the trade plays out."
            ),
            FAQItem(
                question: "What is a private community?",
                answer: "Private communities are hidden from Discover and search for anyone who isn't a member."
            ),
            FAQItem(
                question: "How do I leave a community?",
                answer: "Open the community, tap its menu and choose Leave Community. Community owners can't leave their own community."
            )
        ]),
        FAQTopic(title: "Leaderboards", questions: [
            FAQItem(
                question: "How are leaderboards ranked?",
                answer: "Leaderboards rank traders by their closed trades in Portfolio: highest win rate, highest total realized P&L, most closed trades, and best profit factor. Win rate and profit factor need at least 3 closed trades. Choose Week, Month, Year or All Time to change the period."
            ),
            FAQItem(
                question: "Where can I see leaderboards?",
                answer: "In the Communities tab, open Leaderboard to see top communities and top traders across Arkad. Each community also has its own leaderboard of its members."
            )
        ]),
        FAQTopic(title: "Account & Data", questions: [
            FAQItem(
                question: "How do I export my data?",
                answer: "Open Settings (the gear icon on your Profile) and tap Export Data. ArkadTrader creates CSV files of your trades and posts on your device. Use the share sheet to save them to Files or send them to another app."
            ),
            FAQItem(
                question: "How do I reset my password?",
                answer: "On the sign-in screen, tap Forgot Password? and enter your email address. We'll email you a link to set a new password."
            ),
            FAQItem(
                question: "How do I delete my account?",
                answer: "Open Settings and tap Delete Account at the bottom. This permanently deletes your sign-in and your profile and cannot be undone. Trades, posts and messages you created are not removed by this step; email us if you want them removed too. If you are asked to sign in again first, sign out, sign back in, and try again right away."
            ),
            FAQItem(
                question: "Who can see my information?",
                answer: "Other signed-in users can see your profile, posts and comments. Members of a community can see its channel messages. Your trades can appear in search results, and your closed trades are used for leaderboards. See the Privacy Policy in Settings > About ArkadTrader for details."
            )
        ])
    ]
}

#Preview {
    HelpCenterView()
}
