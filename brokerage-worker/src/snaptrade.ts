// SnapTrade REST client. Requests are signed the same way as snaptrade-typescript-sdk:
// HMAC-SHA256, keyed with the consumer key, over the key-sorted JSON of
// { content, path, query }, sent in the `Signature` header.

import { UpstreamError } from "./errors";

const BASE = "https://api.snaptrade.com";

export interface SnapTradeUser {
  userId: string;
  userSecret: string;
}

// Only the fields Arkad reads.
export interface Authorization {
  id?: string;
  name?: string;
  disabled?: boolean;
  created_date?: string;
  brokerage?: { name?: string; display_name?: string };
}

/** An investment account from `GET /accounts/all` (other kinds, like bank accounts, are skipped) */
export interface Account {
  kind?: string;
  id: string;
  connection_id: string;
  display_name?: string | null;
  net_value?: { amount?: number | null; currency?: string | null } | null;
  raw_type?: string | null;
  sync_status?: {
    positions?: string | null;
    transactions?: { initial_sync_completed?: boolean } | null;
  } | null;
}

/** A position from `GET /accounts/{id}/positions/all`. Numbers arrive as strings. */
export interface Position {
  instrument?: {
    kind?: string;
    id?: string;
    symbol?: string;
    raw_symbol?: string;
    multiplier?: string | null;
    underlying?: { symbol?: string } | null;
  };
  units?: string | null;
  price?: string | null;
  cost_basis?: string | null;
  cash_equivalent?: boolean;
}

/** One currency's cash from `GET /accounts/{id}/balances` */
export interface Balance {
  currency?: { code?: string } | null;
  cash?: number | null;
}

interface SymbolType {
  code?: string;
}

export interface Activity {
  id?: string;
  type?: string;
  units?: number | null;
  price?: number | null;
  trade_date?: string | null;
  settlement_date?: string | null;
  symbol?: { symbol?: string; type?: SymbolType } | null;
  option_symbol?: { ticker?: string } | null;
}

interface ActivitiesPage {
  data?: Activity[];
  pagination?: { total?: number };
}

/** JSON with every object's keys sorted, as SnapTrade's signature expects */
function sortedJson(value: unknown): string {
  const keys = new Set<string>();
  JSON.stringify(value, (key, v) => {
    keys.add(key);
    return v;
  });
  return JSON.stringify(value, [...keys].sort());
}

async function hmacBase64(message: string, key: string): Promise<string> {
  const encoder = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey("raw", encoder.encode(key), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(message)));
  let binary = "";
  for (const byte of signature) binary += String.fromCharCode(byte);
  return btoa(binary);
}

export class SnapTrade {
  constructor(
    private readonly clientId: string,
    private readonly consumerKey: string,
  ) {
    if (!clientId || !consumerKey) throw new Error("SNAPTRADE_CLIENT_ID and SNAPTRADE_CONSUMER_KEY must be set");
  }

  private async request<T>(
    method: "GET" | "POST" | "DELETE",
    path: string,
    options: { user?: SnapTradeUser; userIdOnly?: string; query?: Record<string, string | number>; body?: Record<string, unknown> } = {},
  ): Promise<T> {
    const params = new URLSearchParams({ clientId: this.clientId });
    if (options.user) {
      params.set("userId", options.user.userId);
      params.set("userSecret", options.user.userSecret);
    } else if (options.userIdOnly) {
      params.set("userId", options.userIdOnly);
    }
    for (const [key, value] of Object.entries(options.query ?? {})) params.set(key, String(value));
    params.set("timestamp", String(Math.round(Date.now() / 1000)));
    const query = params.toString();

    const signature = await hmacBase64(
      sortedJson({ content: options.body ?? null, path, query }),
      encodeURI(this.consumerKey),
    );
    const res = await fetch(`${BASE}${path}?${query}`, {
      method,
      headers: { Accept: "application/json", "Content-Type": "application/json", Signature: signature },
      body: options.body ? JSON.stringify(options.body) : undefined,
    });
    const text = await res.text();
    if (!res.ok) throw new UpstreamError("SnapTrade", res.status, `${method} ${path}: ${text.slice(0, 500)}`);
    return (text ? JSON.parse(text) : undefined) as T;
  }

  /** Creates a SnapTrade user for `userId` and returns its secret */
  async registerUser(userId: string): Promise<SnapTradeUser> {
    const res = await this.request<{ userId?: string; userSecret?: string }>("POST", "/snapTrade/registerUser", { body: { userId } });
    if (!res?.userSecret) throw new Error("SnapTrade did not return a user secret");
    return { userId: res.userId ?? userId, userSecret: res.userSecret };
  }

  async deleteUser(userId: string): Promise<void> {
    await this.request("DELETE", "/snapTrade/deleteUser", { userIdOnly: userId });
  }

  /** The connection portal URL, read-only, returning to `redirect` when done */
  async loginLink(user: SnapTradeUser, redirect: string): Promise<string> {
    const res = await this.request<{ redirectURI?: string }>("POST", "/snapTrade/login", {
      user,
      body: { connectionType: "read", customRedirect: redirect, immediateRedirect: true },
    });
    if (!res?.redirectURI) throw new Error("SnapTrade returned no portal URL");
    return res.redirectURI;
  }

  authorizations(user: SnapTradeUser): Promise<Authorization[]> {
    return this.request("GET", "/authorizations", { user });
  }

  /** Investment accounts across every connection. `/accounts` and `/accounts/{id}/holdings`
   *  return 410 for SnapTrade customers who signed up after May 11, 2026. */
  async accounts(user: SnapTradeUser): Promise<Account[]> {
    const res = await this.request<{ results?: Account[] }>("GET", "/accounts/all", { user });
    return (res?.results ?? []).filter((a) => a.id && a.connection_id && (a.kind ?? "investment") === "investment");
  }

  async positions(user: SnapTradeUser, accountId: string): Promise<Position[]> {
    const res = await this.request<{ results?: Position[] }>("GET", `/accounts/${encodeURIComponent(accountId)}/positions/all`, { user });
    return res?.results ?? [];
  }

  /** Estimated daily account values for up to a year. A free add-on that's off by default
   *  (SnapTrade dashboard -> Add-ons); fails when it isn't enabled. */
  async valueHistory(user: SnapTradeUser, accountId: string): Promise<Array<{ date: string; value: number }>> {
    const res = await this.request<{ history?: Array<{ date?: string; total_value?: string | number }> }>(
      "GET",
      `/accounts/${encodeURIComponent(accountId)}/balanceHistory`,
      { user },
    );
    const out: Array<{ date: string; value: number }> = [];
    for (const h of res?.history ?? []) {
      const date = (h.date ?? "").slice(0, 10);
      const value = Number(h.total_value);
      if (/^\d{4}-\d{2}-\d{2}$/.test(date) && Number.isFinite(value)) out.push({ date, value });
    }
    return out;
  }

  balances(user: SnapTradeUser, accountId: string): Promise<Balance[]> {
    return this.request("GET", `/accounts/${encodeURIComponent(accountId)}/balances`, { user });
  }

  /** Buys and sells between two dates (YYYY-MM-DD), every page */
  async activities(user: SnapTradeUser, accountId: string, startDate: string, endDate: string): Promise<Activity[]> {
    const all: Activity[] = [];
    for (let offset = 0; ; offset += 1000) {
      const page = await this.request<ActivitiesPage>("GET", `/accounts/${encodeURIComponent(accountId)}/activities`, {
        user,
        query: { startDate, endDate, offset, limit: 1000, type: "BUY,SELL" },
      });
      const rows = page?.data ?? [];
      all.push(...rows);
      const total = page?.pagination?.total ?? rows.length;
      if (rows.length < 1000 || offset + rows.length >= total) break;
    }
    return all;
  }

  async deleteConnection(user: SnapTradeUser, connectionId: string): Promise<void> {
    await this.request("DELETE", `/connection/${encodeURIComponent(connectionId)}`, { user });
  }
}
