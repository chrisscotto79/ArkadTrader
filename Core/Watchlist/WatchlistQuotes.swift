// File: Core/Watchlist/WatchlistQuotes.swift
// Finnhub stock quotes with the day's change, for the watchlist.
// GET /quote?symbol=AAPL returns { c: current, d: change, dp: percent change, ... }.
// Same endpoint and key as `MarketQuotes` in PortfolioViewModel.swift, which only exposes
// the current price.

import Foundation

enum WatchlistQuotes {
    private struct Response: Decodable {
        let c: Double?
        let d: Double?
        let dp: Double?
    }

    static var isConfigured: Bool { !AppConfig.finnhubAPIKey.isEmpty }

    /// Stock symbols only. Symbols without a quote are left out of the result.
    static func fetch(symbols: Set<String>) async -> [String: WatchlistQuote] {
        let key = AppConfig.finnhubAPIKey
        guard !key.isEmpty, !symbols.isEmpty else { return [:] }

        return await withTaskGroup(of: (String, WatchlistQuote?).self) { group in
            for symbol in symbols {
                group.addTask {
                    var components = URLComponents(string: "https://finnhub.io/api/v1/quote")
                    components?.queryItems = [
                        URLQueryItem(name: "symbol", value: symbol),
                        URLQueryItem(name: "token", value: key)
                    ]
                    guard let url = components?.url,
                          let (data, _) = try? await URLSession.shared.data(from: url),
                          let response = try? JSONDecoder().decode(Response.self, from: data),
                          let price = response.c, price > 0 else {
                        return (symbol, nil)
                    }
                    return (symbol, WatchlistQuote(price: price, change: response.d, changePercent: response.dp))
                }
            }

            var result: [String: WatchlistQuote] = [:]
            for await (symbol, quote) in group {
                if let quote { result[symbol] = quote }
            }
            return result
        }
    }
}
