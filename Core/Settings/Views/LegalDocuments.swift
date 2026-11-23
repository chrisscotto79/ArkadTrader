// File: Core/Settings/Views/LegalDocuments.swift
// Terms of Service and Privacy Policy, shown from About and from sign-up.
// The same text lives in docs/terms-of-service.md and docs/privacy-policy.md for hosting on the web.
// Keep the two in sync and bump `LegalDocumentType.effectiveDate` when either changes.

import SwiftUI

// MARK: - Legal Document View

/// Shows the Terms of Service or Privacy Policy.
/// Presented from AboutView and RegisterView.
struct LegalDocumentView: View {
    let documentType: LegalDocumentType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    header

                    ForEach(Array(documentType.sections.enumerated()), id: \.offset) { index, section in
                        VStack(alignment: .leading, spacing: DS.Spacing.s) {
                            Text("\(index + 1). \(section.heading)")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            Text(section.body)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }

                    Text("Questions? Email \(AppInfo.supportEmail).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, DS.Spacing.s)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.pageMargin + 4)
                .padding(.vertical, DS.Spacing.xl)
            }
            .screenBackground()
            .navigationTitle(documentType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.goldText)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(documentType.title)
                .font(.system(size: 30, weight: .bold))
            Text("Effective \(LegalDocumentType.effectiveDate)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(documentType.summary)
                .font(.callout)
                .foregroundStyle(.primary)
                .padding(DS.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .fill(Color.goldTint)
                )
                .padding(.top, DS.Spacing.s)
        }
    }
}

struct LegalSection {
    let heading: String
    let body: String
}

enum LegalDocumentType: String, Identifiable {
    case terms
    case privacy

    /// Shown at the top of both documents. Update whenever the text changes.
    static let effectiveDate = "November 23, 2026"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: return "Terms of Service"
        case .privacy: return "Privacy Policy"
        }
    }

    /// Plain-language summary shown above the full text
    var summary: String {
        switch self {
        case .terms:
            return "Arkad is a community and trading-journal app. It doesn't place trades or give financial advice, and nothing here is a promise of returns. Be honest, be respectful, and trade at your own risk."
        case .privacy:
            return "We collect what's needed to run your account, your communities and your journal. We don't sell your personal information. You can export your data or delete your account at any time in Settings."
        }
    }

    var sections: [LegalSection] {
        switch self {
        case .terms: return Self.termsSections
        case .privacy: return Self.privacySections
        }
    }

    // MARK: Terms of Service

    private static var termsSections: [LegalSection] {
        [
            LegalSection(
                heading: "Agreement",
                body: "These Terms of Service (\"Terms\") are an agreement between you and Arkad (\"Arkad\", \"we\", \"us\") and govern your use of the Arkad app and related services (the \"Service\"). By creating an account or using the Service you agree to these Terms and to our Privacy Policy. If you don't agree, don't use the Service."
            ),
            LegalSection(
                heading: "What Arkad is",
                body: "Arkad is a social app for traders. You can join and run trading communities, chat in channels, share trade callouts, post to a feed, follow other traders, and keep a journal of trades you enter yourself.\n\nArkad is not a broker, dealer, investment adviser, exchange or bank. The Service does not place, route or execute trades, and does not hold or move your money or securities. Portfolio values are calculated from information you enter and from third-party market data, and may be inaccurate."
            ),
            LegalSection(
                heading: "Not financial advice",
                body: "Everything on Arkad, including posts, callouts, community messages, leaderboards, performance figures, news and quotes, is for information and education only. It is not investment, financial, legal or tax advice, and it is not a recommendation to buy or sell anything.\n\nTrading stocks, options, cryptocurrency and foreign exchange involves substantial risk, including the loss of more than you invest. Past performance, including results shown on profiles and leaderboards, does not guarantee future results. Results are based on numbers users enter themselves and are not verified by Arkad. You are solely responsible for your own trading decisions. Consider speaking with a licensed professional."
            ),
            LegalSection(
                heading: "Eligibility and your account",
                body: "You must be at least 18 years old (or the age of majority where you live) to use Arkad. You agree to give accurate information when you sign up and to keep it up to date.\n\nKeep your password secure. You're responsible for activity on your account. Tell us right away at \(AppInfo.supportEmail) if you think your account has been accessed without permission. You can delete your account at any time in Settings."
            ),
            LegalSection(
                heading: "Your content",
                body: "You own the content you post, including posts, comments, images, messages, callouts and trade entries (\"Your Content\"). You give Arkad a worldwide, non-exclusive, royalty-free licence to host, store, copy, display and distribute Your Content only as needed to operate, improve and promote the Service. This licence ends when you delete the content or your account, except for copies other users have already shared, copies kept for legal reasons, and backups that are deleted on a normal schedule.\n\nYou confirm you have the right to post Your Content and that it doesn't break these Terms or anyone else's rights."
            ),
            LegalSection(
                heading: "Community rules",
                body: "When you use Arkad you agree not to:\n• Post content that is illegal, hateful, harassing, threatening, sexually explicit or violent.\n• Mislead people: fake trades or results, impersonation, or false claims about yourself.\n• Manipulate markets, including pump-and-dump schemes, spreading false information to move a price, or coordinating to manipulate a security or token.\n• Promise or guarantee returns, or present yourself as a licensed professional if you aren't.\n• Share other people's private information, or content you don't have the rights to.\n• Spam, run scams, solicit money outside the Service under false pretences, or send malware.\n• Scrape, reverse engineer, overload or try to get around the security of the Service.\n\nYou can report content and block users in the app. We may remove content, limit features or suspend or close accounts that break these rules."
            ),
            LegalSection(
                heading: "Running a community",
                body: "If you create or moderate a community you are responsible for it, including its name, description, channels, rules, and how you moderate members. You must follow these Terms, keep callouts honest (don't misrepresent entries, exits or results), and remove content that breaks these Terms when you become aware of it. Arkad may moderate, hide or remove any community."
            ),
            LegalSection(
                heading: "Paid communities",
                body: "Arkad is free to download and use. We plan to let community owners charge for access to their communities. When that feature is available:\n• Prices, billing periods and what members get are set by the community owner and shown before you pay.\n• Payments are processed through Apple's in-app purchase system and are subject to Apple's terms, including its refund policy.\n• Arkad keeps a percentage of each payment as a platform fee. The fee and payout terms will be shown to community owners before they enable paid access.\n• Paying for a community buys access to its content. It doesn't buy advice from Arkad, and neither Arkad nor the owner guarantees any trading result.\n\nWe'll update these Terms with the full details before paid communities launch."
            ),
            LegalSection(
                heading: "Third-party services",
                body: "The Service relies on third parties, including Google Firebase for accounts and data storage and Finnhub for market news and quotes. Market data may be delayed, incomplete or wrong, and is provided only for your information. Your use of a third-party service may be governed by that provider's own terms. If you link a brokerage, the read-only connection is made by SnapTrade, and your use of it may be governed by SnapTrade's terms. Holdings and trades imported from a brokerage come as the brokerage reports them and may be delayed, incomplete or wrong."
            ),
            LegalSection(
                heading: "Our rights",
                body: "Arkad, its logo and the Service's design and software belong to Arkad and its licensors. These Terms don't give you any right to use our name or branding. We may change, suspend or stop any part of the Service at any time. We may suspend or end your access if you break these Terms or if we need to in order to protect users, the Service or Arkad, or to comply with the law."
            ),
            LegalSection(
                heading: "Disclaimers",
                body: "The Service is provided \"as is\" and \"as available\". To the fullest extent permitted by law, Arkad disclaims all warranties, express or implied, including merchantability, fitness for a particular purpose, accuracy and non-infringement. We don't promise the Service will be uninterrupted, secure or error-free, or that any content, data or results are accurate."
            ),
            LegalSection(
                heading: "Limitation of liability",
                body: "To the fullest extent permitted by law, Arkad will not be liable for any indirect, incidental, special, consequential or punitive damages, or for any trading losses, lost profits, lost data or loss of goodwill, arising from your use of the Service or reliance on any content in it. Arkad's total liability for any claim relating to the Service is limited to the greater of the amount you paid Arkad in the 12 months before the claim, or US $100. Some places don't allow these limits, so they may not apply to you."
            ),
            LegalSection(
                heading: "Indemnity",
                body: "You agree to defend and hold Arkad harmless from claims, losses and costs (including reasonable legal fees) arising from Your Content, your communities, your use of the Service, or your breach of these Terms or of anyone's rights."
            ),
            LegalSection(
                heading: "Copyright complaints",
                body: "If you believe content on Arkad infringes your copyright, email \(AppInfo.supportEmail) with a description of the work, where the content appears in the app, your contact details, and a statement that you have a good-faith belief the use isn't authorised. We'll review and remove infringing content."
            ),
            LegalSection(
                heading: "Changes to these Terms",
                body: "We may update these Terms as the Service changes. When we make material changes we'll tell you in the app before they take effect. If you keep using Arkad after the changes take effect, you accept the updated Terms."
            ),
            LegalSection(
                heading: "Apple",
                body: "If you got Arkad from the Apple App Store, these Terms are between you and Arkad, not Apple. Apple isn't responsible for the app or its content and has no obligation to provide maintenance or support. Apple and its subsidiaries are third-party beneficiaries of these Terms and may enforce them against you."
            ),
            LegalSection(
                heading: "Contact",
                body: "Questions about these Terms? Email \(AppInfo.supportEmail)."
            )
        ]
    }

    // MARK: Privacy Policy

    private static var privacySections: [LegalSection] {
        [
            LegalSection(
                heading: "Who we are",
                body: "This Privacy Policy explains how Arkad (\"Arkad\", \"we\", \"us\") collects, uses and shares information when you use the Arkad app and related services (the \"Service\")."
            ),
            LegalSection(
                heading: "Information you give us",
                body: "• Account: your email address and password. Passwords are handled by Firebase Authentication; Arkad never sees or stores your password.\n• Profile: your full name, username, bio and profile photo.\n• Trading journal: the trades you enter (symbol, asset type, prices, quantity, dates, notes), your starting balance, deposits and withdrawals, and whether each trade is shown on your profile.\n• Social activity: posts, images, comments, likes, bookmarks, follows, communities you create or join, channel messages, files you share, trade callouts, and reports and blocks you make.\n• Support: what you send us when you email support."
            ),
            LegalSection(
                heading: "Information collected automatically",
                body: "The app includes Google Firebase Analytics, which records basic usage events (such as app opens, screens viewed and session length) and device information (such as device model, operating system version, app version, language and an app-instance identifier). We use this to understand how the app is used and to fix problems. We don't use it to show ads.\n\nThe app doesn't access your location, contacts or microphone. It uses your camera or photo library only when you choose to take or pick a photo to upload."
            ),
            LegalSection(
                heading: "How we use information",
                body: "• To create and secure your account and keep you signed in.\n• To run the Service: show your profile, feed, communities, chats, callouts, leaderboards and portfolio.\n• To calculate your portfolio values, performance and leaderboard rankings.\n• To moderate content, respond to reports, and prevent fraud, spam and abuse.\n• To answer support requests and send important service messages.\n• To understand usage and improve the app.\n• To comply with the law and enforce our Terms."
            ),
            LegalSection(
                heading: "What other users can see",
                body: "Other signed-in users can see your profile (name, username, bio, photo, follower counts), your posts and comments, and trades you've chosen to show on your profile. Members of a community can see your messages, files and callouts in that community. Closed trades shown on your profile are used for leaderboards. Anything you post publicly can be seen, saved or shared by others."
            ),
            LegalSection(
                heading: "How we share information",
                body: "We don't sell your personal information, and we don't share it for cross-context behavioural advertising. We share information only:\n• With service providers who run the Service for us: Google Firebase (authentication, database, file storage and analytics) and Finnhub (market news and quotes). For quotes, the app sends Finnhub only the ticker symbols of your open stock positions, never your account details. If you link a brokerage, SnapTrade (which makes the read-only connection) and Cloudflare (which runs the service that talks to SnapTrade) process your brokerage data for us.\n• With Apple, if you make in-app purchases (when available).\n• When required by law, or to protect the rights, safety and property of our users, Arkad or others.\n• As part of a merger, acquisition or sale of assets, in which case this policy will continue to apply to your information."
            ),
            LegalSection(
                heading: "Where data is stored and how it's protected",
                body: "Your data is stored by Google Firebase, which may process it in the United States and other countries. Data is encrypted in transit, and access is restricted to what's needed to run the Service. No system is perfectly secure, so we can't guarantee absolute security."
            ),
            LegalSection(
                heading: "How long we keep it",
                body: "We keep your information while your account is active. When you delete your account in Settings, your sign-in and profile are deleted straight away. Some content you created, such as trades, posts, comments, images and community messages, may remain until it is removed separately; you can delete individual trades and posts in the app, or email \(AppInfo.supportEmail) and we'll remove the rest. We may keep limited information when the law requires it or to resolve disputes and enforce our Terms."
            ),
            LegalSection(
                heading: "Your choices and rights",
                body: "• Access and export: Settings > Export Data creates CSV files of your trades and posts.\n• Correct: edit your profile at any time.\n• Control visibility: choose whether each trade is shown on your profile.\n• Delete: delete posts and trades in the app, or your whole account in Settings > Delete Account.\n• Block and report other users.\n\nDepending on where you live (for example California, the EU or the UK), you may have extra rights, such as asking what personal information we hold about you, asking us to correct or delete it, objecting to or restricting some uses, or complaining to a data protection authority. To make a request, email \(AppInfo.supportEmail). We'll respond within the time the law requires and won't treat you differently for using your rights."
            ),
            LegalSection(
                heading: "On your device",
                body: "If you turn on Remember me, your email address is saved on your device so it's filled in next time. Your appearance setting (light or dark) is saved on your device. Data exports are created on your device and only leave it if you share them."
            ),
            LegalSection(
                heading: "Children",
                body: "Arkad is for people 18 and older. We don't knowingly collect information from anyone under 18. If you think a minor has created an account, email \(AppInfo.supportEmail) and we'll delete it."
            ),
            LegalSection(
                heading: "Linked brokerages",
                body: "Linking a brokerage is optional. If you link one (such as Robinhood or Coinbase), you sign in on SnapTrade's page, not in Arkad, so Arkad never sees your brokerage password. The connection is read-only: Arkad can't place trades or move money. Arkad receives the brokerage's name, your holdings (symbols, quantities, prices and cost) and your buys and sells from the last 90 days, and saves them to your account as holdings and Verified trades. Imported trades stay private unless you choose to show them on your profile. You can disconnect in Settings > Linked brokerages: that brokerage's holdings are removed, and imported trades stay until you delete them. Deleting your account also removes your link with SnapTrade."
            ),
            LegalSection(
                heading: "New features",
                body: "If we add features that use new kinds of information, such as paying for a community, we'll update this policy and explain what's collected before you use them."
            ),
            LegalSection(
                heading: "Changes to this policy",
                body: "We may update this policy from time to time. When we make material changes we'll tell you in the app before they take effect. The effective date at the top shows when it last changed."
            ),
            LegalSection(
                heading: "Contact",
                body: "Questions or requests about your privacy? Email \(AppInfo.supportEmail)."
            )
        ]
    }
}

#Preview("Terms") {
    LegalDocumentView(documentType: .terms)
}

#Preview("Privacy") {
    LegalDocumentView(documentType: .privacy)
}
