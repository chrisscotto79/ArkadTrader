// Finnhub quotes for the callout tracker and price alerts.
//
// Symbol mapping (the iOS app sends plain tickers):
//   stock   AAPL, BRK.B           -> AAPL, BRK.B
//   crypto  BTC, BTC-USD, BTC/USD -> BINANCE:BTCUSDT   (USD pairs are priced in USDT on Binance)
//           ETHBTC                -> BINANCE:ETHBTC
//   forex   EUR/USD, EURUSD       -> OANDA:EUR_USD
//   option  (anything)            -> not quotable; options are not tracked
// A ticker that already contains ":" (e.g. "COINBASE:BTC-USD") is passed through unchanged.
//
// Quotes are cached in `quoteCache/{finnhubSymbol}` (server only) so the 5-minute
// alert job and the 15-minute callout job share calls and stay inside the free tier
// (60 calls/minute).

import { logger } from "firebase-functions";
import { db, Timestamp, sleep } from "./firebase.js";
import { FINNHUB_MIN_INTERVAL_MS } from "../config.js";

export type AssetType = "stock" | "option" | "crypto" | "forex";

const CRYPTO_QUOTES = ["USDT", "USDC", "USD", "BTC", "ETH", "EUR"];

export function finnhubSymbol(rawTicker: string, assetType: string | undefined): string | null {
  const ticker = (rawTicker || "").trim().toUpperCase().replace(/^\$/, "");
  if (!ticker) return null;
  if (ticker.includes(":")) return ticker;

  switch (assetType) {
    case "option":
      return null;
    case "crypto": {
      const compact = ticker.replace(/[-/_ ]/g, "");
      let base = compact;
      let quote = "USD";
      for (const q of CRYPTO_QUOTES) {
        if (compact.length > q.length && compact.endsWith(q)) {
          base = compact.slice(0, -q.length);
          quote = q;
          break;
        }
      }
      if (quote === "USD" || quote === "USDC") quote = "USDT";
      return `BINANCE:${base}${quote}`;
    }
    case "forex": {
      const letters = ticker.replace(/[^A-Z]/g, "");
      if (letters.length !== 6) return null;
      return `OANDA:${letters.slice(0, 3)}_${letters.slice(3)}`;
    }
    default:
      // Stocks and ETFs. Finnhub's free /quote covers US listings.
      if (!/^[A-Z0-9.\-]{1,12}$/.test(ticker)) return null;
      return ticker;
  }
}

// MARK: - Market hours

function newYorkParts(now: Date): { weekday: number; minutes: number } {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  const parts = Object.fromEntries(fmt.formatToParts(now).map((p) => [p.type, p.value]));
  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const hour = Number(parts.hour) % 24;
  return { weekday: days.indexOf(parts.weekday), minutes: hour * 60 + Number(parts.minute) };
}

/**
 * Whether prices for this asset type can move right now (US exchange holidays are
 * ignored; a quote on a holiday simply doesn't change).
 * - stocks/options: Mon–Fri 9:30–16:15 New York (the extra 15 minutes catches the close)
 * - crypto: always
 * - forex: Sunday 17:00 to Friday 17:00 New York
 */
export function isMarketOpen(assetType: string | undefined, now = new Date()): boolean {
  const { weekday, minutes } = newYorkParts(now);
  if (assetType === "crypto") return true;
  if (assetType === "forex") {
    if (weekday === 6) return false;
    if (weekday === 0) return minutes >= 17 * 60;
    if (weekday === 5) return minutes < 17 * 60;
    return true;
  }
  if (weekday === 0 || weekday === 6) return false;
  return minutes >= 9 * 60 + 30 && minutes <= 16 * 60 + 15;
}

// MARK: - Fetching

interface FinnhubQuote {
  c?: number; // current
  t?: number; // unix seconds of the quote
}

export interface Quote {
  price: number;
  at: Date;
}

export class QuoteFetcher {
  private lastCall = 0;
  private readonly deadline: number;

  /**
   * @param apiKey Finnhub key (FINNHUB_API_KEY secret)
   * @param budgetMs stop calling Finnhub after this long so the function finishes before its timeout
   * @param maxCacheAgeMs reuse cached quotes newer than this
   */
  constructor(
    private readonly apiKey: string,
    budgetMs: number,
    private readonly maxCacheAgeMs: number,
  ) {
    this.deadline = Date.now() + budgetMs;
  }

  /** Quotes keyed by Finnhub symbol. Symbols that fail or time out are left out. */
  async fetchAll(symbols: Iterable<string>): Promise<Map<string, Quote>> {
    const unique = [...new Set(symbols)];
    const result = new Map<string, Quote>();
    if (unique.length === 0) return result;

    // 1. Cached quotes
    const refs = unique.map((s) => db.collection("quoteCache").doc(cacheId(s)));
    const cached = await db.getAll(...refs);
    const stale: string[] = [];
    cached.forEach((snap, i) => {
      const data = snap.data();
      const fetchedAt = data?.fetchedAt instanceof Timestamp ? data.fetchedAt.toDate() : undefined;
      if (data && typeof data.price === "number" && fetchedAt && Date.now() - fetchedAt.getTime() < this.maxCacheAgeMs) {
        result.set(unique[i], { price: data.price, at: fetchedAt });
      } else {
        stale.push(unique[i]);
      }
    });

    // 2. Finnhub, one symbol at a time under the rate limit
    const writes = db.batch();
    let pending = 0;
    for (const symbol of stale) {
      if (Date.now() > this.deadline) {
        logger.warn("Quote budget exhausted", { remaining: stale.length - pending });
        break;
      }
      const quote = await this.fetchOne(symbol);
      if (!quote) continue;
      result.set(symbol, quote);
      writes.set(db.collection("quoteCache").doc(cacheId(symbol)), {
        symbol,
        price: quote.price,
        fetchedAt: Timestamp.fromDate(new Date()),
      });
      pending += 1;
      if (pending % 400 === 0) {
        await writes.commit();
      }
    }
    if (pending % 400 !== 0) await writes.commit();
    return result;
  }

  private async fetchOne(symbol: string, attempt = 0): Promise<Quote | null> {
    const wait = this.lastCall + FINNHUB_MIN_INTERVAL_MS - Date.now();
    if (wait > 0) await sleep(wait);
    this.lastCall = Date.now();

    const url = `https://finnhub.io/api/v1/quote?symbol=${encodeURIComponent(symbol)}`;
    try {
      const res = await fetch(url, {
        headers: { "X-Finnhub-Token": this.apiKey },
        signal: AbortSignal.timeout(10_000),
      });
      if (res.status === 429) {
        if (attempt >= 2) return null;
        await sleep(5_000 * (attempt + 1));
        return this.fetchOne(symbol, attempt + 1);
      }
      if (!res.ok) {
        logger.warn("Finnhub quote failed", { symbol, status: res.status });
        return null;
      }
      const body = (await res.json()) as FinnhubQuote;
      if (typeof body.c !== "number" || !(body.c > 0)) return null; // unknown symbols return c = 0
      const at = typeof body.t === "number" && body.t > 0 ? new Date(body.t * 1000) : new Date();
      return { price: body.c, at };
    } catch (error) {
      logger.warn("Finnhub quote error", { symbol, error: String(error) });
      return null;
    }
  }
}

function cacheId(symbol: string): string {
  return symbol.replace(/\//g, "_");
}
