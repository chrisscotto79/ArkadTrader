// Connect, sync, disconnect and account deletion. A port of functions/src/snaptrade/callables.ts
// (docs/backend-contracts.md, section 5): same Firestore paths and document shapes, so the app
// reads Worker-written data exactly as it would read Cloud Functions data.
//
//   snaptradeUsers/{uid}                          { snaptradeUserId, userSecret, createdAt } (server only)
//   snaptradeUsers/{uid}/processedActivities/{id}  import dedupe
//   users/{uid}/brokerageConnections/{id}          read by the owner; includes cashBalance, holdingsValue, totalValue, valueHistory
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
  const connections = new Map<
    string,
    {
      name: string;
      data: Data;
      cash: number;
      holdingsValue: number;
      totalValue: number;
      syncing: boolean;
      /** SnapTrade's estimated history, summed across accounts, by date */
      estimated: Map<string, number>;
    }
  >();
  for (const a of auths) {
    if (!a.id) continue;
    const name = a.brokerage?.display_name || a.brokerage?.name || a.name || "Brokerage";
    const created = a.created_date ? new Date(a.created_date) : now;
    connections.set(a.id, {
      name,
      data: {
        brokerageName: name,
        status: a.disabled ? "broken" : "connected",
        createdAt: Number.isNaN(created.getTime()) ? now : created,
        lastSyncAt: now,
      },
      cash: 0,
      holdingsValue: 0,
      totalValue: 0,
      syncing: false,
      estimated: new Map(),
    });
  }

  // 2. Accounts, positions, cash and activities
  const accounts = await snaptrade.accounts(user);
  const holdingDocs = new Map<string, Data>();
  const activities: Array<{ a: Activity; accountId: string; connectionId: string }> = [];
  const start = new Date(Date.now() - ctx.importDays * 86_400_000).toISOString().slice(0, 10);
  const end = now.toISOString().slice(0, 10);
  const accountLog: Data[] = [];

  for (const account of accounts) {
    const connectionId = account.connection_id;
    const connection = connections.get(connectionId);
    if (!connection) continue;
    const brokerageName = connection.name;

    // SnapTrade pulls a new connection's data in the background; until then the account looks empty
    const syncing = !account.sync_status?.positions || account.sync_status?.transactions?.initial_sync_completed === false;
    if (syncing) connection.syncing = true;

    let accountHoldingsValue = 0;
    const positions = await snaptrade.positions(user, account.id);
    accountLog.push({
      type: account.raw_type ?? null,
      positions: positions.length,
      positionsSyncedAt: account.sync_status?.positions ?? null,
      transactionsReady: account.sync_status?.transactions?.initial_sync_completed ?? null,
    });
    for (const p of positions) {
      const inst = p.instrument;
      const kind = inst?.kind ?? "";
      // Cash and cash-equivalents (money market funds) are already in the cash balance
      if (!inst || kind === "cash" || p.cash_equivalent) continue;
      const quantity = num(p.units);
      const isOption = kind === "option" || kind === "future_option";
      const symbol = (isOption ? inst.symbol : inst.symbol || inst.raw_symbol)?.trim();
      if (!symbol || !quantity) continue;
      const price = num(p.price);
      const multiplier = isOption ? num(inst.multiplier) || 100 : 1;
      const marketValue = Math.round(price * quantity * multiplier * 100) / 100;
      accountHoldingsValue += marketValue;
      holdingDocs.set(docId(`${account.id}_${inst.id ?? symbol}`), {
        symbol,
        assetType: isOption ? "option" : kind === "crypto" ? "crypto" : "stock",
        quantity,
        averagePrice: num(p.cost_basis),
        currentPrice: price,
        marketValue,
        connectionId,
        brokerageName,
        updatedAt: now,
      });
    }

    let accountCash = 0;
    try {
      for (const b of await snaptrade.balances(user, account.id)) accountCash += num(b.cash);
    } catch (error) {
      // Cash is a nice-to-have; positions and trades still sync without it
      console.log(JSON.stringify({ event: "balances-failed", uid, error: String(error) }));
    }

    const netValue = account.net_value?.amount;
    connection.cash += accountCash;
    connection.holdingsValue += accountHoldingsValue;
    connection.totalValue += typeof netValue === "number" && Number.isFinite(netValue) ? netValue : accountCash + accountHoldingsValue;

    // Estimated past values, when the SnapTrade add-on is on. Only needed until Arkad has its own history.
    if (wantsEstimates(existingConnections.find((d) => d.id === connectionId)?.data)) {
      try {
        for (const h of await snaptrade.valueHistory(user, account.id)) {
          connection.estimated.set(h.date, (connection.estimated.get(h.date) ?? 0) + h.value);
        }
      } catch {
        // Add-on off: the chart fills in from daily syncs instead
      }
    }

    for (const a of await snaptrade.activities(user, account.id, start, end)) {
      activities.push({ a, accountId: account.id, connectionId });
    }
  }

  // Connections, with their cash and total value
  const connectionWrites: Write[] = [];
  const today = now.toISOString().slice(0, 10);
  for (const [id, c] of connections) {
    const previous = existingConnections.find((d) => d.id === id)?.data;
    connectionWrites.push(
      db.set(`users/${uid}/brokerageConnections/${id}`, {
        ...c.data,
        valueHistory: mergeHistory(previous?.valueHistory, c.estimated, today, money(c.totalValue)),
        cashBalance: money(c.cash),
        holdingsValue: money(c.holdingsValue),
        totalValue: money(c.totalValue),
        accountCount: accounts.filter((a) => a.connection_id === id).length,
        initialSyncPending: c.syncing,
      }),
    );
  }
  for (const doc of existingConnections) if (!connections.has(doc.id)) connectionWrites.push(db.delete(doc.path));
  await db.commit(connectionWrites);

  // Replace holdings
  const oldHoldings = await db.list(`users/${uid}/brokerageHoldings`);
  const holdingWrites: Write[] = [];
  for (const doc of oldHoldings) if (!holdingDocs.has(doc.id)) holdingWrites.push(db.delete(doc.path));
  for (const [id, data] of holdingDocs) holdingWrites.push(db.set(`users/${uid}/brokerageHoldings/${id}`, data));
  await db.commit(holdingWrites);

  const importedTrades = await importActivities(ctx, activities);
  console.log(JSON.stringify({ event: "sync", uid, connections: connections.size, accounts: accounts.length, holdings: holdingDocs.size, importedTrades, accountLog }));
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

// MARK: - Value history

/** Daily account values kept on the connection doc for the Portfolio chart (about two years) */
const HISTORY_DAYS = 730;

type HistoryPoint = { date: string; value: number };

function readHistory(raw: unknown): HistoryPoint[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((p) => {
    const point = p as { date?: unknown; value?: unknown };
    return typeof point?.date === "string" && typeof point.value === "number" ? [{ date: point.date, value: point.value }] : [];
  });
}

/** Ask SnapTrade for estimated history only while ours is short */
function wantsEstimates(previous: Data | undefined): boolean {
  return readHistory(previous?.valueHistory).length < 30;
}

/**
 * Today's value replaces any earlier value for today. SnapTrade's estimates fill only days we
 * have nothing for, so a recorded value always wins.
 */
function mergeHistory(raw: unknown, estimated: Map<string, number>, today: string, value: number): HistoryPoint[] {
  const byDate = new Map<string, number>();
  for (const [date, v] of estimated) if (date < today) byDate.set(date, money(v));
  for (const p of readHistory(raw)) byDate.set(p.date, p.value);
  byDate.set(today, value);
  return [...byDate.entries()]
    .sort(([a], [b]) => (a < b ? -1 : 1))
    .slice(-HISTORY_DAYS)
    .map(([date, v]) => ({ date, value: v }));
}

/** SnapTrade sends some numbers as strings */
function num(value: unknown): number {
  const n = typeof value === "number" ? value : Number(value ?? 0);
  return Number.isFinite(n) ? n : 0;
}

function money(value: number): number {
  return Math.round(value * 100) / 100;
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
