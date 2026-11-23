// File: Core/Portfolio/ViewModels/TradePriceChecker.swift
// Decides a trade's proof label when it's logged or closed (docs/backend-contracts.md, section 0,
// "Proof labels"): a price is "price_checked" when its date is today and it sits inside today's
// low–high range from a Finnhub quote, widened by 0.5% for quote delay. Anything else is self-reported.
// Quotes come from MarketQuotes.dayRange (the Portfolio's Finnhub client, same key) and are cached
// for a minute so typing doesn't spend Finnhub's free-tier calls.

import Foundation
import SwiftUI

/// The label a price will get, and why.
enum PriceCheckOutcome: Equatable {
    /// Waiting for a quote
    case checking
    case priceChecked(TradePriceCheck)
    case selfReported(SelfReportedReason)

    enum SelfReportedReason: Equatable {
        /// No price typed yet
        case missingPrice
        /// The entry or exit date isn't today
        case notToday
        /// Options have no quote source (Finnhub /quote doesn't cover premiums)
        case unsupportedAsset
        /// No Finnhub key in this build
        case quotesNotConfigured
        /// No quote for the symbol (unknown symbol, network)
        case noQuote
        /// The quote's last trade is more than a day old (market closed today)
        case marketClosed
        /// The price is outside the widened day range
        case outsideRange(low: Double, high: Double)
    }

    var proof: TradeProof {
        if case .priceChecked = self { return .priceChecked }
        return .selfReported
    }

    var priceCheck: TradePriceCheck? {
        if case .priceChecked(let check) = self { return check }
        return nil
    }

    var isChecking: Bool { self == .checking }
}

enum TradePriceCheckRules {
    /// Quotes are delayed, so the day range is widened by this much on each side.
    static let rangeTolerance = 0.005
    /// A quote whose last trade is older than this isn't "today's" range.
    static let maxSessionAge: TimeInterval = 24 * 60 * 60

    static func canQuote(_ type: TradeType) -> Bool { type != .option }

    /// Finnhub symbol for a ticker, the same way callouts and the watchlist ask for it.
    static func symbol(for ticker: String) -> String {
        WatchlistSymbol.normalize(ticker.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func evaluate(price: Double?, date: Date, type: TradeType, quote: DayRangeQuote?,
                         isLoading: Bool, now: Date = Date()) -> PriceCheckOutcome {
        guard let price, price > 0 else { return .selfReported(.missingPrice) }
        guard Calendar.current.isDate(date, inSameDayAs: now) else { return .selfReported(.notToday) }
        guard canQuote(type) else { return .selfReported(.unsupportedAsset) }
        guard !AppConfig.finnhubAPIKey.isEmpty else { return .selfReported(.quotesNotConfigured) }
        guard let quote else { return isLoading ? .checking : .selfReported(.noQuote) }
        if let session = quote.sessionTime, now.timeIntervalSince(session) > maxSessionAge {
            return .selfReported(.marketClosed)
        }
        let low = quote.low * (1 - rangeTolerance)
        let high = quote.high * (1 + rangeTolerance)
        guard price >= low && price <= high else {
            return .selfReported(.outsideRange(low: quote.low, high: quote.high))
        }
        return .priceChecked(TradePriceCheck(low: quote.low, high: quote.high, checkedAt: quote.fetchedAt))
    }

    /// "Price checked: $187.20 is inside today's range $185.10–$189.90" and friends.
    /// `side` is "entry" or "exit".
    static func message(for outcome: PriceCheckOutcome, price: Double?, side: String, ticker: String,
                        type: TradeType) -> String {
        let terms = AssetTerms(type)
        let symbol = ticker.isEmpty ? "this symbol" : ticker.uppercased()
        switch outcome {
        case .checking:
            return "Checking \(symbol) against today's market range…"
        case .priceChecked(let check):
            let value = price.map { terms.price($0) } ?? "Your price"
            return "Price checked: \(value) is inside today's range \(terms.price(check.low))–\(terms.price(check.high))."
        case .selfReported(let reason):
            switch reason {
            case .missingPrice:
                return "Self-reported until you enter the \(side) price."
            case .notToday:
                return "Self-reported: the \(side) date isn't today. Only trades logged as they happen can be price-checked."
            case .unsupportedAsset:
                return "Self-reported: there are no live quotes for options, so this can't be price-checked."
            case .quotesNotConfigured:
                return "Self-reported: live quotes aren't available in this version of the app."
            case .noQuote:
                return "Self-reported: no live quote for \(symbol) right now."
            case .marketClosed:
                return "Self-reported: \(symbol) hasn't traded today, so there's no range to check against."
            case .outsideRange(let low, let high):
                let value = price.map { terms.price($0) } ?? "Your price"
                return "Self-reported: \(value) is outside today's range \(terms.price(low))–\(terms.price(high))."
            }
        }
    }
}

/// Fetches and caches today's range for one symbol at a time, for the add-trade and close screens.
@MainActor
final class TradePriceChecker: ObservableObject {
    @Published private(set) var quote: DayRangeQuote?
    @Published private(set) var isLoading = false

    /// Shared by every checker so going back and forth doesn't refetch
    private static var cache: [String: DayRangeQuote] = [:]
    private static let freshFor: TimeInterval = 60
    /// Before saving, a quote older than this is fetched again
    static let maxAgeAtSave: TimeInterval = 120

    private var symbol = ""
    private var task: Task<Void, Never>?

    /// Starts loading `ticker`'s range after a short pause (typing), unless options or no key.
    func load(ticker: String, type: TradeType, debounce: Bool = true) {
        let newSymbol = TradePriceCheckRules.symbol(for: ticker)
        guard TradePriceCheckRules.canQuote(type), !AppConfig.finnhubAPIKey.isEmpty, !newSymbol.isEmpty else {
            task?.cancel()
            symbol = newSymbol
            quote = nil
            isLoading = false
            return
        }
        if newSymbol == symbol {
            if isLoading { return }
            if let quote, Date().timeIntervalSince(quote.fetchedAt) < Self.freshFor { return }
        }
        symbol = newSymbol
        if let cached = Self.cache[newSymbol], Date().timeIntervalSince(cached.fetchedAt) < Self.freshFor {
            task?.cancel()
            quote = cached
            isLoading = false
            return
        }

        task?.cancel()
        quote = nil
        isLoading = true
        task = Task { [weak self] in
            if debounce {
                try? await Task.sleep(for: .milliseconds(700))
                if Task.isCancelled { return }
            }
            let result = await MarketQuotes.dayRange(symbol: newSymbol)
            guard let self, !Task.isCancelled, self.symbol == newSymbol else { return }
            if let result { Self.cache[newSymbol] = result }
            self.quote = result
            self.isLoading = false
        }
    }

    func outcome(price: Double?, date: Date, type: TradeType) -> PriceCheckOutcome {
        TradePriceCheckRules.evaluate(price: price, date: date, type: type, quote: quote, isLoading: isLoading)
    }

    /// The outcome to save with: refetches the quote first when it's more than two minutes old.
    func outcomeForSaving(ticker: String, price: Double?, date: Date, type: TradeType) async -> PriceCheckOutcome {
        let newSymbol = TradePriceCheckRules.symbol(for: ticker)
        let needsQuote = TradePriceCheckRules.canQuote(type)
            && !AppConfig.finnhubAPIKey.isEmpty
            && Calendar.current.isDateInToday(date)
            && (price ?? 0) > 0
        if needsQuote {
            let isStale = quote.map { Date().timeIntervalSince($0.fetchedAt) > Self.maxAgeAtSave } ?? true
            if newSymbol != symbol || isStale {
                task?.cancel()
                symbol = newSymbol
                isLoading = true
                let result = await MarketQuotes.dayRange(symbol: newSymbol)
                if let result { Self.cache[newSymbol] = result }
                quote = result
                isLoading = false
            }
        }
        return TradePriceCheckRules.evaluate(price: price, date: date, type: type, quote: quote, isLoading: false)
    }
}
