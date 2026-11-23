// Every 15 minutes: price every open callout, close the ones that hit their target
// or stop, and auto-close callouts with neither after 30 days.

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { db, Timestamp, tolerantBulkWriter } from "../lib/firebase.js";
import { finnhubSymbol, isMarketOpen, QuoteFetcher, Quote } from "../lib/quotes.js";
import { CalloutMap, percentMove } from "../lib/callouts.js";
import { FINNHUB_API_KEY } from "../secrets.js";
import { REGION, CALLOUT_AUTO_CLOSE_DAYS } from "../config.js";

const TIMEOUT_SECONDS = 540;

export const trackOpenCallouts = onSchedule(
  {
    // Every 15 minutes, offset two minutes from the price-alert job so they rarely overlap.
    schedule: "2,17,32,47 * * * *",
    timeZone: "America/New_York",
    region: REGION,
    secrets: [FINNHUB_API_KEY],
    timeoutSeconds: TIMEOUT_SECONDS,
    memory: "512MiB",
    retryCount: 0,
  },
  async () => {
    const snap = await db.collectionGroup("messages").where("callout.status", "==", "open").get();
    if (snap.empty) return;

    const now = new Date();
    const items = snap.docs.map((doc) => {
      const c = doc.get("callout") as CalloutMap;
      return { doc, c, symbol: finnhubSymbol(c.ticker ?? "", c.assetType) };
    });

    const wanted = items
      .filter((i) => i.symbol && isMarketOpen(i.c.assetType, now))
      .map((i) => i.symbol as string);
    const fetcher = new QuoteFetcher(FINNHUB_API_KEY.value(), (TIMEOUT_SECONDS - 90) * 1000, 4 * 60 * 1000);
    const quotes = await fetcher.fetchAll(wanted);

    const writer = tolerantBulkWriter();
    let priced = 0;
    let closed = 0;
    for (const { doc, c, symbol } of items) {
      const quote: Quote | undefined = symbol ? quotes.get(symbol) : undefined;
      const update = evaluate(c, quote, now, doc.get("createdAt"));
      if (!update) continue;
      if (update["callout.status"]) closed += 1;
      else priced += 1;
      // Precondition: skip if the author closed or edited it since we read it.
      writer.update(doc.ref, update, { lastUpdateTime: doc.updateTime });
    }
    await writer.close();
    logger.info("Callout tracker done", { open: items.length, quotes: quotes.size, priced, closed });
  },
);

/** The field updates for one callout, or null when nothing changed. */
export function evaluate(
  c: CalloutMap,
  quote: Quote | undefined,
  now: Date,
  messageCreatedAt: unknown,
): Record<string, unknown> | null {
  const entry = Number(c.entryPrice ?? 0);
  if (!(entry > 0)) return null;
  const isShort = c.direction === "short";
  const stop = typeof c.stopPrice === "number" ? c.stopPrice : undefined;
  const target = typeof c.targetPrice === "number" ? c.targetPrice : undefined;
  const nowTs = Timestamp.fromDate(now);

  const close = (status: string, exit: number): Record<string, unknown> => ({
    "callout.status": status,
    "callout.exitPrice": exit,
    "callout.closedAt": nowTs,
    "callout.resultPercent": percentMove(entry, exit, c.direction),
    "callout.closedBy": "server",
    ...(quote ? { "callout.lastPrice": quote.price, "callout.lastPriceAt": Timestamp.fromDate(quote.at) } : {}),
  });

  if (quote) {
    const p = quote.price;
    const stopHit = stop !== undefined && (isShort ? p >= stop : p <= stop);
    const targetHit = target !== undefined && (isShort ? p <= target : p >= target);
    // If both are crossed between checks, assume the stop came first (conservative).
    if (stopHit) {
      // A gap past the stop fills at the worse price.
      const exit = isShort ? Math.max(stop!, p) : Math.min(stop!, p);
      return close("stopped_out", exit);
    }
    if (targetHit) return close("target_hit", target!);
  }

  // Neither a stop nor a target: close after 30 days at the last price.
  if (stop === undefined && target === undefined) {
    const posted =
      c.postedAt instanceof Timestamp ? c.postedAt.toDate() : messageCreatedAt instanceof Timestamp ? messageCreatedAt.toDate() : undefined;
    if (posted && now.getTime() - posted.getTime() >= CALLOUT_AUTO_CLOSE_DAYS * 86_400_000) {
      const exit = quote?.price ?? (typeof c.lastPrice === "number" ? c.lastPrice : entry);
      return close("closed", exit);
    }
  }

  if (quote && quote.price !== c.lastPrice) {
    return { "callout.lastPrice": quote.price, "callout.lastPriceAt": Timestamp.fromDate(quote.at) };
  }
  return null;
}
