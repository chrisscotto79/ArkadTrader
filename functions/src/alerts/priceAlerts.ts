// users/{uid}/priceAlerts/{id}: checked every 5 minutes while the asset's market is
// open (crypto: always). A triggered alert is deactivated and produces a
// `price_alert` notification.

import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { db, Timestamp, tolerantBulkWriter } from "../lib/firebase.js";
import { finnhubSymbol, isMarketOpen, QuoteFetcher } from "../lib/quotes.js";
import { notifyUsers } from "../lib/notify.js";
import { formatPrice } from "../lib/callouts.js";
import { FINNHUB_API_KEY } from "../secrets.js";
import { REGION, MAX_ACTIVE_PRICE_ALERTS } from "../config.js";

const TIMEOUT_SECONDS = 300;

export const checkPriceAlerts = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "America/New_York",
    region: REGION,
    secrets: [FINNHUB_API_KEY],
    timeoutSeconds: TIMEOUT_SECONDS,
    memory: "512MiB",
    retryCount: 0,
  },
  async () => {
    const now = new Date();
    const snap = await db.collectionGroup("priceAlerts").where("isActive", "==", true).get();
    const alerts = snap.docs
      .map((doc) => ({
        doc,
        uid: doc.ref.parent.parent?.id,
        symbol: finnhubSymbol(doc.get("symbol") ?? "", doc.get("assetType")),
        assetType: doc.get("assetType") as string | undefined,
        condition: doc.get("condition") as string,
        target: Number(doc.get("targetPrice")),
      }))
      .filter((a) => a.uid && a.symbol && a.target > 0 && isMarketOpen(a.assetType, now));
    if (alerts.length === 0) return;

    // Leave a minute of headroom; quotes younger than 2 minutes are reused.
    const fetcher = new QuoteFetcher(FINNHUB_API_KEY.value(), (TIMEOUT_SECONDS - 60) * 1000, 2 * 60 * 1000);
    const quotes = await fetcher.fetchAll(alerts.map((a) => a.symbol as string));

    const writer = tolerantBulkWriter();
    const triggered: Array<(typeof alerts)[number] & { price: number }> = [];
    for (const a of alerts) {
      const quote = quotes.get(a.symbol as string);
      if (!quote) continue;
      const hit = a.condition === "below" ? quote.price <= a.target : quote.price >= a.target;
      if (!hit) continue;
      writer.update(
        a.doc.ref,
        { isActive: false, triggeredAt: Timestamp.now(), triggeredPrice: quote.price },
        { lastUpdateTime: a.doc.updateTime },
      );
      triggered.push({ ...a, price: quote.price });
    }
    await writer.close();

    for (const a of triggered) {
      const symbol = String(a.doc.get("symbol") ?? "").toUpperCase();
      await notifyUsers(
        [a.uid as string],
        {
          type: "price_alert",
          title: `${symbol} is ${a.condition === "below" ? "below" : "above"} ${formatPrice(a.target)}`,
          body: `${symbol} is trading at ${formatPrice(a.price)}.`,
          data: { route: "watchlist", symbol },
        },
        { dedupeKey: `${a.uid}_${a.doc.id}_${a.doc.updateTime.toMillis()}` },
      );
    }
    logger.info("Price alerts checked", { active: alerts.length, quotes: quotes.size, triggered: triggered.length });
  },
);

/** Enforce the 20-active-alert limit, which Firestore rules can't count. */
export const onPriceAlertCreated = onDocumentCreated(
  { document: "users/{uid}/priceAlerts/{alertId}", region: REGION },
  async (event) => {
    if (event.data?.get("isActive") !== true) return;
    const active = await db
      .collection("users")
      .doc(event.params.uid)
      .collection("priceAlerts")
      .where("isActive", "==", true)
      .count()
      .get();
    if (active.data().count > MAX_ACTIVE_PRICE_ALERTS) {
      await event.data.ref.update({ isActive: false, disabledReason: "limit" });
      logger.info("Price alert over limit deactivated", { uid: event.params.uid });
    }
  },
);
