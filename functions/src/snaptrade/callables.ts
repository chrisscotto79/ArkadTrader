// Brokerage linking through SnapTrade, read-only (docs/backend-contracts.md, section 5).
//
// Imported trades are written to `trades` in the exact shape of the app's
// `Trade.toFirestore()`, plus source/isVerified/externalId/brokerageConnectionId
// (and brokerageAccountId, used to match sells to buys in the same account).
//
// Buys and sells are paired first-in, first-out per account and symbol:
// - BUY   -> an open trade (doc id `st_<activityId>`)
// - SELL  -> closes the oldest open imported lots; a partial close splits the lot,
//            leaving the remainder open and writing the sold part as a closed trade.
// - A sell with no imported buy (bought before the 90-day window) is skipped,
//   because its entry price is unknown.
// Every processed activity is recorded, so re-syncing never imports twice and a
// trade the user deleted stays deleted.

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import type { AccountUniversalActivity, AccountHoldingsAccount } from "snaptrade-typescript-sdk";
import { db, FieldValue, Timestamp, chunk } from "../lib/firebase.js";
import { snaptrade, getOrRegister, getCredentials, SnaptradeCredentials } from "../lib/snaptrade.js";
import { SNAPTRADE_CLIENT_ID, SNAPTRADE_CONSUMER_KEY } from "../secrets.js";
import { REGION, BROKERAGE_IMPORT_DAYS, appReturnUrl } from "../config.js";

const opts = { region: REGION, secrets: [SNAPTRADE_CLIENT_ID, SNAPTRADE_CONSUMER_KEY], timeoutSeconds: 300, memory: "512MiB" as const };

function requireAuth(request: CallableRequest): string {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  return request.auth.uid;
}

function failure(error: unknown, fallback: string): never {
  if (error instanceof HttpsError) throw error;
  const body = (error as { responseBody?: unknown })?.responseBody;
  logger.error(fallback, { error: String(error), body });
  throw new HttpsError("internal", fallback);
}

/** `{}` -> `{ url }`: SnapTrade's connection portal, read-only, returning to arkad://brokerage/connected. */
export const snaptradeConnectLink = onCall(opts, async (request) => {
  const uid = requireAuth(request);
  try {
    const creds = await getOrRegister(uid);
    const res = await snaptrade().authentication.loginSnapTradeUser({
      userId: creds.userId,
      userSecret: creds.userSecret,
      connectionType: "read",
      customRedirect: appReturnUrl("brokerage/connected"),
      immediateRedirect: true,
    });
    const url = "redirectURI" in res.data ? res.data.redirectURI : undefined;
    if (!url) throw new Error("SnapTrade returned no portal URL");
    return { url };
  } catch (error) {
    failure(error, "Couldn't open brokerage linking");
  }
});

type TradeType = "stock" | "option" | "crypto" | "forex";

function assetTypeFromCode(code: string | undefined): TradeType {
  const c = (code ?? "").toLowerCase();
  if (c.includes("crypto")) return "crypto";
  if (c.includes("forex") || c === "fx") return "forex";
  return "stock";
}

/** `{}` -> `{ importedTrades, holdings }` */
export const snaptradeSync = onCall(opts, async (request) => {
  const uid = requireAuth(request);
  const creds = await getCredentials(uid);
  if (!creds) throw new HttpsError("failed-precondition", "Link a brokerage first.");
  try {
    return await syncUser(uid, creds);
  } catch (error) {
    failure(error, "Couldn't sync your brokerage");
  }
});

export async function syncUser(uid: string, creds: SnaptradeCredentials): Promise<{ importedTrades: number; holdings: number }> {
  const st = snaptrade();
  const userRef = db.collection("users").doc(uid);
  const now = Timestamp.now();

  // 1. Connections
  const auths = (await st.connections.listBrokerageAuthorizations({ userId: creds.userId, userSecret: creds.userSecret })).data;
  const connectionNames = new Map<string, string>();
  const connBatch = db.batch();
  const existingConns = await userRef.collection("brokerageConnections").get();
  const liveIds = new Set<string>();
  for (const a of auths) {
    if (!a.id) continue;
    liveIds.add(a.id);
    const name = a.brokerage?.display_name || a.brokerage?.name || a.name || "Brokerage";
    connectionNames.set(a.id, name);
    connBatch.set(
      userRef.collection("brokerageConnections").doc(a.id),
      {
        brokerageName: name,
        status: a.disabled ? "broken" : "connected",
        createdAt: a.created_date ? Timestamp.fromDate(new Date(a.created_date)) : now,
        lastSyncAt: now,
      },
      { merge: true },
    );
  }
  for (const doc of existingConns.docs) if (!liveIds.has(doc.id)) connBatch.delete(doc.ref);
  await connBatch.commit();

  // 2. Accounts, holdings and activities
  const accounts = (await st.accountInformation.listUserAccounts({ userId: creds.userId, userSecret: creds.userSecret })).data;
  const holdingDocs = new Map<string, Record<string, unknown>>();
  const activities: Array<{ a: AccountUniversalActivity; accountId: string; connectionId: string }> = [];
  const start = new Date(Date.now() - BROKERAGE_IMPORT_DAYS * 86_400_000).toISOString().slice(0, 10);
  const end = new Date().toISOString().slice(0, 10);

  for (const account of accounts) {
    const connectionId = account.brokerage_authorization;
    if (!liveIds.has(connectionId)) continue;
    const brokerageName = connectionNames.get(connectionId) ?? account.institution_name ?? "Brokerage";

    const holdings: AccountHoldingsAccount = (
      await st.accountInformation.getUserHoldings({ accountId: account.id, userId: creds.userId, userSecret: creds.userSecret })
    ).data;
    for (const p of holdings.positions ?? []) {
      const sym = p.symbol?.symbol;
      const symbol = sym?.symbol;
      const quantity = Number(p.units ?? p.fractional_units ?? 0);
      if (!symbol || !quantity || p.cash_equivalent) continue;
      const price = Number(p.price ?? 0);
      holdingDocs.set(`${account.id}_${sym?.id ?? symbol}`.replace(/\//g, "_"), {
        symbol,
        assetType: assetTypeFromCode(sym?.type?.code),
        quantity,
        averagePrice: Number(p.average_purchase_price ?? 0),
        currentPrice: price,
        marketValue: Math.round(price * quantity * 100) / 100,
        connectionId,
        brokerageName,
        updatedAt: now,
      });
    }
    for (const o of holdings.option_positions ?? []) {
      const opt = o.symbol?.option_symbol;
      if (!opt?.ticker || !o.units) continue;
      const price = Number(o.price ?? 0);
      holdingDocs.set(`${account.id}_${opt.id}`.replace(/\//g, "_"), {
        symbol: opt.ticker,
        assetType: "option",
        quantity: Number(o.units),
        averagePrice: Number(o.average_purchase_price ?? 0),
        currentPrice: price,
        marketValue: Math.round(price * Number(o.units) * 100 * 100) / 100, // 100 shares per contract
        connectionId,
        brokerageName,
        updatedAt: now,
      });
    }

    for (let offset = 0; ; offset += 1000) {
      const page = (
        await st.accountInformation.getAccountActivities({
          accountId: account.id,
          userId: creds.userId,
          userSecret: creds.userSecret,
          startDate: start,
          endDate: end,
          type: "BUY,SELL",
          offset,
          limit: 1000,
        })
      ).data;
      const rows = page.data ?? [];
      for (const a of rows) activities.push({ a, accountId: account.id, connectionId });
      const total = page.pagination?.total ?? rows.length;
      if (rows.length < 1000 || offset + rows.length >= total) break;
    }
  }

  // Replace holdings
  const oldHoldings = await userRef.collection("brokerageHoldings").get();
  const writer = db.bulkWriter();
  for (const doc of oldHoldings.docs) if (!holdingDocs.has(doc.id)) writer.delete(doc.ref);
  for (const [id, data] of holdingDocs) writer.set(userRef.collection("brokerageHoldings").doc(id), data);
  await writer.close();

  const importedTrades = await importActivities(uid, activities);
  logger.info("SnapTrade sync done", { uid, connections: liveIds.size, holdings: holdingDocs.size, importedTrades });
  return { importedTrades, holdings: holdingDocs.size };
}

interface Lot {
  ref: FirebaseFirestore.DocumentReference;
  data: Record<string, unknown>;
  quantity: number;
  entryMs: number;
  dirty: boolean;
}

async function importActivities(
  uid: string,
  items: Array<{ a: AccountUniversalActivity; accountId: string; connectionId: string }>,
): Promise<number> {
  const valid = items.filter(({ a }) => a.id && (a.type === "BUY" || a.type === "SELL") && Number(a.units) && Number(a.price) > 0);
  if (valid.length === 0) return 0;

  // Skip anything already processed.
  const processedRef = db.collection("snaptradeUsers").doc(uid).collection("processedActivities");
  const seen = new Set<string>();
  for (const group of chunk(valid, 300)) {
    const snaps = await db.getAll(...group.map(({ a }) => processedRef.doc(String(a.id))));
    snaps.forEach((s) => s.exists && seen.add(s.id));
  }
  const fresh = valid
    .filter(({ a }) => !seen.has(String(a.id)))
    .sort((x, y) => dateMs(x.a) - dateMs(y.a) || (x.a.type === "BUY" ? -1 : 1));
  if (fresh.length === 0) return 0;

  // Open imported lots, keyed by account + ticker.
  const lots = new Map<string, Lot[]>();
  const openSnap = await db.collection("trades").where("userId", "==", uid).where("source", "==", "brokerage").where("isOpen", "==", true).get();
  for (const doc of openSnap.docs) {
    const data = doc.data();
    const key = `${data.brokerageAccountId}|${data.ticker}`;
    const list = lots.get(key) ?? [];
    list.push({ ref: doc.ref, data, quantity: Number(data.quantity), entryMs: (data.entryDate as Timestamp).toMillis(), dirty: false });
    lots.set(key, list);
  }
  for (const list of lots.values()) list.sort((a, b) => a.entryMs - b.entryMs);

  const creates: Array<{ id: string; data: Record<string, unknown> }> = [];
  let imported = 0;

  for (const { a, accountId, connectionId } of fresh) {
    const isOption = !!a.option_symbol;
    const ticker = String(isOption ? a.option_symbol?.ticker : a.symbol?.symbol ?? "").toUpperCase();
    if (!ticker) continue;
    const tradeType: TradeType = isOption ? "option" : assetTypeFromCode(a.symbol?.type?.code);
    const units = Math.abs(Number(a.units));
    const price = Number(a.price);
    const when = Timestamp.fromMillis(dateMs(a));
    const key = `${accountId}|${ticker}`;

    if (a.type === "BUY") {
      const id = `st_${a.id}`;
      const data = tradeDoc(uid, { ticker, tradeType, entryPrice: price, quantity: units, entryDate: when }, a, connectionId, accountId);
      creates.push({ id, data });
      const list = lots.get(key) ?? [];
      list.push({ ref: db.collection("trades").doc(id), data, quantity: units, entryMs: when.toMillis(), dirty: false });
      lots.set(key, list);
      imported += 1;
      continue;
    }

    // SELL: close lots FIFO
    let remaining = units;
    const list = lots.get(key) ?? [];
    while (remaining > 1e-9 && list.length > 0) {
      const lot = list[0];
      if (lot.quantity <= remaining + 1e-9) {
        remaining -= lot.quantity;
        lot.data = { ...lot.data, isOpen: false, exitPrice: price, exitDate: when };
        delete lot.data.currentPrice;
        lot.dirty = true;
        list.shift();
        flush(lot, creates);
      } else {
        // Split: the sold part becomes its own closed trade, the rest stays open.
        lot.quantity -= remaining;
        lot.data = { ...lot.data, quantity: round(lot.quantity) };
        lot.dirty = true;
        const soldId = `st_${a.id}_${lot.ref.id}`;
        const sold: Record<string, unknown> = {
          ...lot.data,
          quantity: round(remaining),
          isOpen: false,
          exitPrice: price,
          exitDate: when,
          externalId: `${a.id}:${lot.data.externalId}`,
        };
        delete sold.currentPrice;
        creates.push({ id: soldId, data: sold });
        remaining = 0;
        imported += 1;
      }
    }
    if (remaining > 1e-9) logger.info("Sell without an imported buy skipped", { uid, ticker, units: remaining });
  }
  for (const list of lots.values()) for (const lot of list) flush(lot, creates);

  // Write everything, then mark activities processed.
  const writer = db.bulkWriter();
  const byId = new Map<string, Record<string, unknown>>();
  for (const c of creates) byId.set(c.id, c.data); // later state of the same doc wins
  for (const [id, data] of byId) writer.set(db.collection("trades").doc(id), data);
  for (const { a } of fresh) writer.set(processedRef.doc(String(a.id)), { type: a.type, processedAt: FieldValue.serverTimestamp() });
  await writer.close();
  return imported;
}

/** Queue a changed lot for writing (it may be a lot created in this run or an existing doc). */
function flush(lot: Lot, creates: Array<{ id: string; data: Record<string, unknown> }>) {
  if (!lot.dirty) return;
  creates.push({ id: lot.ref.id, data: lot.data });
  lot.dirty = false;
}

/** Same keys as Trade.toFirestore() in the app, plus the brokerage fields. */
function tradeDoc(
  uid: string,
  t: { ticker: string; tradeType: TradeType; entryPrice: number; quantity: number; entryDate: Timestamp },
  a: AccountUniversalActivity,
  connectionId: string,
  accountId: string,
): Record<string, unknown> {
  return {
    userId: uid,
    ticker: t.ticker,
    tradeType: t.tradeType,
    entryPrice: t.entryPrice,
    quantity: round(t.quantity),
    entryDate: t.entryDate,
    notes: null,
    strategy: null,
    isOpen: true,
    sharedCommunityIds: [],
    isPublic: false,
    tags: [],
    currentPrice: t.entryPrice,
    source: "brokerage",
    isVerified: true,
    externalId: String(a.id),
    brokerageConnectionId: connectionId,
    brokerageAccountId: accountId,
  };
}

function dateMs(a: AccountUniversalActivity): number {
  const raw = a.trade_date ?? a.settlement_date;
  const ms = raw ? Date.parse(raw) : NaN;
  return Number.isFinite(ms) ? ms : Date.now();
}

function round(q: number): number {
  return Math.round(q * 1e8) / 1e8;
}

/** `{ connectionId }` -> `{ ok }`: removes the brokerage connection and its holdings. Imported trades stay. */
export const snaptradeDisconnect = onCall(opts, async (request: CallableRequest<{ connectionId?: unknown }>) => {
  const uid = requireAuth(request);
  const connectionId = request.data?.connectionId;
  if (typeof connectionId !== "string" || !connectionId) throw new HttpsError("invalid-argument", "connectionId is required.");
  const userRef = db.collection("users").doc(uid);
  const connRef = userRef.collection("brokerageConnections").doc(connectionId);
  if (!(await connRef.get()).exists) throw new HttpsError("not-found", "Connection not found.");
  const creds = await getCredentials(uid);
  try {
    if (creds) {
      await snaptrade().connections.deleteConnection({ connectionId, userId: creds.userId, userSecret: creds.userSecret });
    }
  } catch (error) {
    const status = (error as { status?: number }).status;
    if (status !== 404) failure(error, "Couldn't disconnect the brokerage");
  }
  const holdings = await userRef.collection("brokerageHoldings").where("connectionId", "==", connectionId).get();
  const batch = db.batch();
  batch.delete(connRef);
  for (const doc of holdings.docs) batch.delete(doc.ref);
  await batch.commit();
  return { ok: true };
});
