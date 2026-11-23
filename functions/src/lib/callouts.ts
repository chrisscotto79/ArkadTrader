// Shared callout math and the server-side callout ledger.
//
// `calloutLedger/{communityId}_{messageId}` (server only) keeps one row per callout,
// so a trader's record can't be improved by deleting a losing callout message:
// - a closed callout stays in the ledger even if its message is deleted later;
// - an open callout that is deleted is closed at its last tracked price, or left
//   out of the record if the server never priced it (e.g. deleted seconds after posting).
// `traderStats` are recomputed from the ledger (callouts/stats.ts).

import { Timestamp } from "./firebase.js";

export type CalloutStatus = "open" | "target_hit" | "stopped_out" | "closed";

export interface CalloutMap {
  ticker?: string;
  assetType?: string;
  direction?: "long" | "short";
  entryPrice?: number;
  stopPrice?: number;
  targetPrice?: number;
  note?: string;
  status?: CalloutStatus;
  authorId?: string;
  communityId?: string;
  postedAt?: Timestamp;
  lastPrice?: number;
  lastPriceAt?: Timestamp;
  exitPrice?: number;
  closedAt?: Timestamp;
  resultPercent?: number;
  closedBy?: string;
}

export interface LedgerRow {
  authorId: string;
  communityId: string;
  channelId: string;
  messageId: string;
  ticker: string;
  assetType: string;
  direction: "long" | "short";
  entryPrice: number;
  status: CalloutStatus;
  postedAt: Timestamp;
  closedAt?: Timestamp | null;
  exitPrice?: number | null;
  resultPercent?: number | null;
  /** Left out of the track record (open callout deleted before it was ever priced). */
  excluded: boolean;
  closedReason?: string | null;
  updatedAt: Timestamp;
}

/** Signed percent move from entry to price, positive when the trade made money. */
export function percentMove(entry: number, price: number, direction: string | undefined): number {
  if (!(entry > 0)) return 0;
  const raw = ((price - entry) / entry) * 100;
  const signed = direction === "short" ? -raw : raw;
  return Math.round(signed * 100) / 100;
}

export function ledgerId(communityId: string, messageId: string): string {
  return `${communityId}_${messageId}`;
}

export function directionLabel(direction: string | undefined): string {
  return direction === "short" ? "SHORT" : "LONG";
}

export function formatPrice(price: number | undefined): string {
  if (typeof price !== "number") return "";
  const digits = Math.abs(price) < 1 ? 4 : 2;
  return "$" + price.toLocaleString("en-US", { minimumFractionDigits: digits, maximumFractionDigits: digits });
}

export function formatPercent(value: number | undefined): string {
  if (typeof value !== "number") return "";
  return `${value > 0 ? "+" : ""}${value.toFixed(2)}%`;
}

export function statusLabel(status: string | undefined): string {
  switch (status) {
    case "target_hit":
      return "target hit";
    case "stopped_out":
      return "stopped out";
    case "closed":
      return "closed";
    default:
      return "open";
  }
}
