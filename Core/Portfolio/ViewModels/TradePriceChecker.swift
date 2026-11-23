// File: Core/Portfolio/ViewModels/TradePriceChecker.swift
// Decides a trade's proof label when it's logged or closed (docs/backend-contracts.md, section 0,
// "Proof labels"). A price is "price_checked" only when:
// - the fill is happening now (the user picked "Just now", not an earlier time or day),
// - the asset is a stock or ETF (Finnhub's /quote covers nothing else; "BTC" there is an ETF),
// - the price is within 1% of the live price from a fresh quote.
// Anything else is self-reported. A whole day's low–high range is not accepted: with hindsight,
// any price inside it could be claimed.
// Quotes come from QuoteClient (shared budget and cache). When quotes are unavailable (rate
// limited, offline) the outcome says so, and the screens let the user retry or explicitly save
// as self-reported instead of quietly downgrading.

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
        /// The fill wasn't just now (an earlier time today, or another day)
        case notNow
        /// Options, crypto and forex have no live quote source
        case unsupportedAsset
        /// No Finnhub key in this build
        case quotesNotConfigured
        /// Finnhub has no price for the symbol (unknown symbol)
        case noQuote
        /// Rate limited or offline: may work on retry
        case quotesUnavailable
        /// The quote's last trade is more than a day old (market closed today)
        case marketClosed
        /// More than 1% away from the live price
        case awayFromLivePrice(live: Double)
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

    /// Live prices couldn't be fetched right now (not a property of the trade itself)
    var isQuotesUnavailable: Bool { self == .selfReported(.quotesUnavailable) }
}

enum TradePriceCheckRules {
    /// A checked price must be within this fraction of the live price.
    static let tolerance = 0.01
    /// A quote whose last trade is older than this isn't a live price.
    static let maxSessionAge: TimeInterval = 24 * 60 * 60
    /// The quote used when saving is at most this old.
    static let maxQuoteAgeAtSave: TimeInterval = QuoteClient.defaultMaxAge

    /// Stocks and ETFs only.
    static func canQuote(_ type: TradeType) -> Bool { type == .stock }

    /// Finnhub symbol for a ticker, the same way callouts and the watchlist ask for it.
    static func symbol(for ticker: String) -> String {
        WatchlistSymbol.normalize(ticker.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// - Parameters:
    ///   - isNow: the fill is being logged as it happens ("Just now")
    ///   - result: the last quote answer, for telling "unknown symbol" from "unavailable"
    static func evaluate(price: Double?, isNow: Bool, type: TradeType, quote: MarketQuote?,
                         result: QuoteResult?, isLoading: Bool, now: Date = Date()) -> PriceCheckOutcome {
        guard let price, price > 0, price.isFinite else { return .selfReported(.missingPrice) }
        guard isNow else { return .selfReported(.notNow) }
        guard canQuote(type) else { return .selfReported(.unsupportedAsset) }
        guard QuoteClient.isConfigured else { return .selfReported(.quotesNotConfigured) }
        guard let quote else {
            if isLoading { return .checking }
            switch result {
            case .noQuote: return .selfReported(.noQuote)
            case .notConfigured: return .selfReported(.quotesNotConfigured)
            case .none: return .checking
            default: return .selfReported(.quotesUnavailable)
            }
        }
        if let time = quote.time, now.timeIntervalSince(time) > maxSessionAge {
            return .selfReported(.marketClosed)
        }
        let low = quote.current * (1 - tolerance)
        let high = quote.current * (1 + tolerance)
        guard price >= low && price <= high else {
            return .selfReported(.awayFromLivePrice(live: quote.current))
        }
        return .priceChecked(TradePriceCheck(low: low, high: high, checkedAt: quote.fetchedAt, price: quote.current))
    }

    /// "Price checked: $187.20 is within 1% of the live price $187.05." and friends.
    /// `side` is "entry" or "exit".
    static func message(for outcome: PriceCheckOutcome, price: Double?, side: String, ticker: String,
                        type: TradeType) -> String {
        let terms = AssetTerms(type)
        let symbol = ticker.isEmpty ? "this symbol" : ticker.uppercased()
        switch outcome {
        case .checking:
            return "Checking \(symbol) against the live price…"
        case .priceChecked(let check):
            let value = price.map { terms.price($0) } ?? "Your price"
            let live = check.price.map { " \(terms.price($0))" } ?? ""
            return "Price checked: \(value) is within 1% of the live price\(live)."
        case .selfReported(let reason):
            switch reason {
            case .missingPrice:
                return "Self-reported until you enter the \(side) price."
            case .notNow:
                return "Self-reported: the \(side) wasn't just now. Only trades logged as they happen can be price-checked."
            case .unsupportedAsset:
                return "Self-reported: live prices cover stocks and ETFs only, so \(type.displayName.lowercased()) trades can't be price-checked."
            case .quotesNotConfigured:
                return "Self-reported: live prices aren't available in this version of the app."
            case .noQuote:
                return "Self-reported: there's no live price for \(symbol). Check the symbol."
            case .quotesUnavailable:
                return "Live prices are unavailable right now. Try again in a minute, or save it as self-reported."
            case .marketClosed:
                return "Self-reported: \(symbol) hasn't traded today, so there's no live price to check against."
            case .awayFromLivePrice(let live):
                let value = price.map { terms.price($0) } ?? "Your price"
                return "Self-reported: \(value) is more than 1% away from the live price \(terms.price(live))."
            }
        }
    }
}

/// Loads the live quote for one symbol at a time, for the add-trade and close screens.
@MainActor
final class TradePriceChecker: ObservableObject {
    @Published private(set) var quote: MarketQuote?
    /// The last answer from QuoteClient (nil before the first request)
    @Published private(set) var lastResult: QuoteResult?
    @Published private(set) var isLoading = false

    private var symbol = ""
    private var task: Task<Void, Never>?

    /// Starts loading `ticker`'s quote after a short pause (typing). Nothing for non-stocks.
    func load(ticker: String, type: TradeType, debounce: Bool = true, force: Bool = false) {
        let newSymbol = TradePriceCheckRules.symbol(for: ticker)
        guard TradePriceCheckRules.canQuote(type), QuoteClient.isConfigured, !newSymbol.isEmpty else {
            task?.cancel()
            symbol = newSymbol
            quote = nil
            lastResult = nil
            isLoading = false
            return
        }
        if newSymbol == symbol, !force {
            if isLoading { return }
            if let quote, quote.age < QuoteClient.defaultMaxAge { return }
        }
        if newSymbol != symbol {
            quote = nil
            lastResult = nil
        }
        symbol = newSymbol
        task?.cancel()
        isLoading = true
        task = Task { [weak self] in
            if debounce {
                try? await Task.sleep(for: .milliseconds(600))
                if Task.isCancelled { return }
            }
            let result = await QuoteClient.shared.quote(for: newSymbol)
            guard let self, !Task.isCancelled, self.symbol == newSymbol else { return }
            self.apply(result)
        }
    }

    /// Fetches again now (the "Try again" button).
    func retry(ticker: String, type: TradeType) {
        load(ticker: ticker, type: type, debounce: false, force: true)
    }

    func outcome(price: Double?, isNow: Bool, type: TradeType) -> PriceCheckOutcome {
        TradePriceCheckRules.evaluate(price: price, isNow: isNow, type: type, quote: quote,
                                      result: lastResult, isLoading: isLoading)
    }

    /// The outcome to save with, from a quote at most 30 seconds old (fetched again if needed).
    func outcomeForSaving(ticker: String, price: Double?, isNow: Bool, type: TradeType) async -> PriceCheckOutcome {
        let newSymbol = TradePriceCheckRules.symbol(for: ticker)
        let needsQuote = TradePriceCheckRules.canQuote(type) && QuoteClient.isConfigured
            && isNow && (price ?? 0) > 0 && !newSymbol.isEmpty
        if needsQuote {
            let isStale = quote.map { $0.age > TradePriceCheckRules.maxQuoteAgeAtSave } ?? true
            if newSymbol != symbol || isStale {
                task?.cancel()
                symbol = newSymbol
                isLoading = true
                let result = await QuoteClient.shared.quote(for: newSymbol,
                                                            maxAge: TradePriceCheckRules.maxQuoteAgeAtSave)
                if symbol == newSymbol { apply(result) }
            }
        }
        return TradePriceCheckRules.evaluate(price: price, isNow: isNow, type: type, quote: quote,
                                             result: lastResult, isLoading: false)
    }

    private func apply(_ result: QuoteResult) {
        lastResult = result
        if let fresh = result.quote {
            quote = fresh
        } else if !result.isTemporarilyUnavailable || (quote?.age ?? .infinity) > TradePriceCheckRules.maxQuoteAgeAtSave {
            // Keep a still-fresh quote through a brief rate limit; otherwise there's no price
            quote = nil
        }
        isLoading = false
    }
}
