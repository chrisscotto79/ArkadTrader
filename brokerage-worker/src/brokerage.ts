// Connect, sync, disconnect and account deletion. A port of functions/src/snaptrade/callables.ts
// (docs/backend-contracts.md, section 5): same Firestore paths and document shapes, so the app
// reads Worker-written data exactly as it would read Cloud Functions data.
//
//   snaptradeUsers/{uid}                          { snaptradeUserId, userSecret, createdAt } (server only)
//   snaptradeUsers/{uid}/processedActivities/{id}  import dedupe
//   users/{uid}/brokerageConnections/{id}          read by the owner
//   users/{uid}/brokerageHoldings/{id}             read by the owner
//   trades/st_<activityId>                         imported, isVerified: true
//
// Buys and sells are paired first-in, first-out per account and symbol:
// - BUY   -> an open trade (doc id `st_<activityId>`)
// - SELL  -> closes the oldest open imported lots; a partial close splits the lot,
//            leaving the remainder open and writing the sold part as a closed trade.
// - A sell with no imported buy (bought before the import window) is skipped,
//   because its entry price is unknown.
// Every processed activity is recorded, so re-syncing never imports twice and a
// trade the user deleted stays deleted.

import { ApiError, UpstreamError } from "./errors";
import { Firestore, type Data, type Write } from "./firestore";
import { SnapTrade, type Activity, type SnapTradeUser } from "./snaptrade";

export interface Context {
  uid: string;
  db: Firestore;
  snaptrade: SnapTrade;
  importDays: number;
}

type TradeType = "stock" | "option" | "crypto" | "forex";

// MARK: - SnapTrade user

async function credentials(ctx: Context): Promise<SnapTradeUser | null> {
  const doc = await ctx.db.get(`snaptradeUsers/${ctx.uid}`);
  const userId = doc?.data.snaptradeUserId;
  const userSecret = doc?.data.userSecret;
  return typeof userId === "string" && typeof userSecret === "string" ? { userId, userSecret } : null;
}

async function credentialsOrRegister(ctx: Context): Promise<SnapTradeUser> {
  const existing = await credentials(ctx);
  if (existing) return existing;
  const user = await ctx.snaptrade.registerUser(`arkad-${ctx.uid}`);
  await ctx.db.commit([
    ctx.db.set(`snaptradeUsers/${ctx.uid}`, { snaptradeUserId: user.userId, userSecret: user.userSecret, createdAt: new Date() }),
  ]);
  return user;
}

// MARK: - Connect

/** `{}` -> `{ url }`: SnapTrade's read-only connection portal */
export async function connect(ctx: Context, returnUrl: string): Promise<{ url: string }> {
  const user = await credentialsOrRegister(ctx);
  return { url: await ctx.snaptrade.loginLink(user, returnUrl) };
}

// MARK: - Sync

function assetTypeFromCode(code: string | undefined): TradeType {
  const c = (code ?? "").toLowerCase();
  if (c.includes("crypto")) return "crypto";
  if (c.includes("forex") || c === "fx") return "forex";
  return "stock";
}

/** `{}` -> `{ importedTrades, holdings }` */
export async function sync(ctx: Context): Promise<{ importedTrades: number; holdings: number }> {
  const user = await credentials(ctx);
  if (!user) throw new ApiError(400, "Link a brokerage first.");
  const { db, snaptrade, uid } = ctx;
  const now = new Date();

  // 1. Connections
  const auths = await snaptrade.authorizations(user);
  const existingConnections = await db.list(`users/${uid}/brokerageConnections`);
  const connectionNames = new Map<string, string>();
  const liveIds = new Set<string>();
  const connectionWrites: Write[] = [];
  for (const a of auths) {
    if (!a.id) continue;
    liveIds.add(a.id);
    const name = a.brokerage?.display_name || a.brokerage?.name || a.name || "Brokerage";
    connectionNames.set(a.id, name);
    const created = a.created_date ? new Date(a.created_date) : now;
    connectionWrites.push(
      db.set(
        `users/${uid}/brokerageConnections/${a.id}`,
        {
          brokerageName: name,
          status: a.disabled ? "broken" : "connected",
          createdAt: Number.isNaN(created.getTime()) ? now : created,
          lastSyncAt: now,
        },
        ["brokerageName", "status", "createdAt", "lastSyncAt"],
      ),
    );
  }
  for (const doc of existingConnections) if (!liveIds.has(doc.id)) connectionWrites.push(db.delete(doc.path));
  await db.commit(connectionWrites);

  // 2. Accounts, holdings and activities
  const accounts = await snaptrade.accounts(user);
  const holdingDocs = new Map<string, Data>();
  const activities: Array<{ a: Activity; accountId: string; connectionId: string }> = [];
  const start = new Date(Date.now() - ctx.importDays * 86_400_000).toISOString().slice(0, 10);
  const end = now.toISOString().slice(0, 10);

  for (const account of accounts) {
    const connectionId = account.brokerage_authorization;
    if (!liveIds.has(connectionId)) continue;
    const brokerageName = connectionNames.get(connectionId) ?? account.institution_name ?? "Brokerage";

    const holdings = await snaptrade.holdings(user, account.id);
    for (const p of holdings.positions ?? []) {
      const sym = p.symbol?.symbol;
      const symbol = sym?.symbol;
      const quantity = Number(p.units ?? p.fractional_units ?? 0);
      if (!symbol || !quantity || p.cash_equivalent) continue;
      const price = Number(p.price ?? 0);
      holdingDocs.set(docId(`${account.id}_${sym?.id ?? symbol}`), {
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
      holdingDocs.set(docId(`${account.id}_${opt.id ?? opt.ticker}`), {
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

    for (const a of await snaptrade.activities(user, account.id, start, end)) {
      activities.push({ a, accountId: account.id, connectionId });
    }
  }

  // Replace holdings
  const oldHoldings = await db.list(`users/${uid}/brokerageHoldings`);
  const holdingWrites: Write[] = [];
  for (const doc of oldHoldings) if (!holdingDocs.has(doc.id)) holdingWrites.push(db.delete(doc.path));
  for (const [id, data] of holdingDocs) holdingWrites.push(db.set(`users/${uid}/brokerageHoldings/${id}`, data));
  await db.commit(holdingWrites);

  const importedTrades = await importActivities(ctx, activities);
  console.log(JSON.stringify({ event: "sync", uid, connections: liveIds.size, holdings: holdingDocs.size, importedTrades }));
  return { importedTrades, holdings: holdingDocs.size };
}

interface Lot {
  id: string;
  data: Data;
  quantity: number;
  entryMs: number;
  dirty: boolean;
}

async function importActivities(
  ctx: Context,
  items: Array<{ a: Activity; accountId: string; connectionId: string }>,
): Promise<number> {
  const { db, uid } = ctx;
  const valid = items.filter(({ a }) => a.id && (a.type === "BUY" || a.type === "SELL") && Number(a.units) && Number(a.price) > 0);
  if (valid.length === 0) return 0;

  // Skip anything already processed.
  const processedPath = (id: string) => `snaptradeUsers/${uid}/processedActivities/${docId(id)}`;
  const seen = await db.existing(valid.map(({ a }) => processedPath(String(a.id))));
  const fresh = valid
    .filter(({ a }) => !seen.has(processedPath(String(a.id))))
    .sort((x, y) => dateMs(x.a) - dateMs(y.a) || (x.a.type === "BUY" ? -1 : 1));
  if (fresh.length === 0) return 0;

  // Open imported lots, keyed by account + ticker.
  const lots = new Map<string, Lot[]>();
  const open = await db.where("", "trades", { userId: uid, source: "brokerage", isOpen: true });
  for (const doc of open) {
    const key = `${doc.data.brokerageAccountId}|${doc.data.ticker}`;
    const entry = doc.data.entryDate;
    const list = lots.get(key) ?? [];
    list.push({
      id: doc.id,
      data: doc.data,
      quantity: Number(doc.data.quantity),
      entryMs: entry instanceof Date ? entry.getTime() : 0,
      dirty: false,
    });
    lots.set(key, list);
  }
  for (const list of lots.values()) list.sort((a, b) => a.entryMs - b.entryMs);

  const creates: Array<{ id: string; data: Data }> = [];
  let imported = 0;

  for (const { a, accountId, connectionId } of fresh) {
    const isOption = !!a.option_symbol;
    const ticker = String((isOption ? a.option_symbol?.ticker : a.symbol?.symbol) ?? "").toUpperCase();
    if (!ticker) continue;
    const tradeType: TradeType = isOption ? "option" : assetTypeFromCode(a.symbol?.type?.code);
    const units = Math.abs(Number(a.units));
    const price = Number(a.price);
    const when = new Date(dateMs(a));
    const key = `${accountId}|${ticker}`;

    if (a.type === "BUY") {
      const id = docId(`st_${a.id}`);
      const data = tradeDoc(uid, { ticker, tradeType, entryPrice: price, quantity: units, entryDate: when }, String(a.id), connectionId, accountId);
      creates.push({ id, data });
      const list = lots.get(key) ?? [];
      list.push({ id, data, quantity: units, entryMs: when.getTime(), dirty: false });
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
        const sold: Data = {
          ...lot.data,
          quantity: round(remaining),
          isOpen: false,
          exitPrice: price,
          exitDate: when,
          externalId: `${a.id}:${lot.data.externalId}`,
        };
        delete sold.currentPrice;
        creates.push({ id: docId(`st_${a.id}_${lot.id}`), data: sold });
        remaining = 0;
        imported += 1;
      }
    }
    if (remaining > 1e-9) console.log(JSON.stringify({ event: "sell-without-buy-skipped", uid, ticker, units: remaining }));
  }
  for (const list of lots.values()) for (const lot of list) flush(lot, creates);

  // Write everything, then mark activities processed.
  const byId = new Map<string, Data>();
  for (const c of creates) byId.set(c.id, c.data); // later state of the same doc wins
  const writes: Write[] = [];
  for (const [id, data] of byId) writes.push(db.set(`trades/${id}`, data));
  await db.commit(writes);
  await db.commit(fresh.map(({ a }) => db.set(processedPath(String(a.id)), { type: a.type ?? "", processedAt: new Date() })));
  return imported;
}

/** Queue a changed lot for writing (it may be a lot created in this run or an existing doc). */
function flush(lot: Lot, creates: Array<{ id: string; data: Data }>) {
  if (!lot.dirty) return;
  creates.push({ id: lot.id, data: lot.data });
  lot.dirty = false;
}

/** Same keys as Trade.toFirestore() in the app, plus the brokerage fields. */
function tradeDoc(
  uid: string,
  t: { ticker: string; tradeType: TradeType; entryPrice: number; quantity: number; entryDate: Date },
  activityId: string,
  connectionId: string,
  accountId: string,
): Data {
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
    externalId: activityId,
    brokerageConnectionId: connectionId,
    brokerageAccountId: accountId,
  };
}

function dateMs(a: Activity): number {
  const raw = a.trade_date ?? a.settlement_date;
  const ms = raw ? Date.parse(raw) : NaN;
  return Number.isFinite(ms) ? ms : Date.now();
}

function round(q: number): number {
  return Math.round(q * 1e8) / 1e8;
}

/** Firestore document ids can't contain "/" */
function docId(raw: string): string {
  return raw.replace(/\//g, "_");
}

// MARK: - Disconnect

/** `{ connectionId }` -> `{ ok }`: removes the connection and its holdings. Imported trades stay. */
export async function disconnect(ctx: Context, connectionId: unknown): Promise<{ ok: true }> {
  if (typeof connectionId !== "string" || !connectionId || connectionId.includes("/")) {
    throw new ApiError(400, "connectionId is required.");
  }
  const { db, uid } = ctx;
  const connectionPath = `users/${uid}/brokerageConnections/${connectionId}`;
  if (!(await db.get(connectionPath))) throw new ApiError(404, "Connection not found.");
  const user = await credentials(ctx);
  if (user) {
    try {
      await ctx.snaptrade.deleteConnection(user, connectionId);
    } catch (error) {
      if (!(error instanceof UpstreamError && error.status === 404)) throw error;
    }
  }
  const holdings = await db.where(`users/${uid}`, "brokerageHoldings", { connectionId });
  await db.commit([db.delete(connectionPath), ...holdings.map((doc) => db.delete(doc.path))]);
  return { ok: true };
}

// MARK: - Account deletion

/**
 * `{}` -> `{ ok }`: called by the app while deleting an account. Deletes the SnapTrade user
 * (which removes every brokerage connection), the stored secret, the import log, and the
 * connection and holding docs the app can't delete itself. Imported trades are deleted by the
 * app with the rest of the user's trades.
 */
export async function deleteUser(ctx: Context): Promise<{ ok: true }> {
  const { db, uid } = ctx;
  const user = await credentials(ctx);
  if (user) {
    try {
      await ctx.snaptrade.deleteUser(user.userId);
    } catch (error) {
      if (!(error instanceof UpstreamError && error.status === 404)) throw error;
    }
  }
  const docs = [
    ...(await db.list(`snaptradeUsers/${uid}/processedActivities`)),
    ...(await db.list(`users/${uid}/brokerageConnections`)),
    ...(await db.list(`users/${uid}/brokerageHoldings`)),
  ];
  await db.commit([...docs.map((doc) => db.delete(doc.path)), db.delete(`snaptradeUsers/${uid}`)]);
  return { ok: true };
}
