// One trigger for every community message write:
// - new callout:   ledger row + `callout` notifications to members
// - new message:   `mention` notifications
// - callout closes (server or author): normalize resultPercent, update the ledger,
//                  `callout_result` notifications to members
// - callout removed or message deleted: keep the record honest (see lib/callouts.ts)
// traderStats are recomputed by the ledger trigger in callouts/stats.ts.

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { db, Timestamp, FieldValue } from "../lib/firebase.js";
import {
  CalloutMap,
  LedgerRow,
  ledgerId,
  percentMove,
  directionLabel,
  formatPrice,
  formatPercent,
  statusLabel,
} from "../lib/callouts.js";
import { notifyUsers, extractMentions, resolveUsernames, snippet } from "../lib/notify.js";
import { activeMemberIds, getCommunity } from "../lib/community.js";
import { REGION, MAX_MENTIONS_PER_ITEM } from "../config.js";

export const onCommunityMessageWritten = onDocumentWritten(
  { document: "communities/{cid}/channels/{chid}/messages/{mid}", region: REGION },
  async (event) => {
    const { cid, chid, mid } = event.params;
    const before = event.data?.before.exists ? event.data.before.data() : undefined;
    const after = event.data?.after.exists ? event.data.after.data() : undefined;
    const beforeCallout = before?.callout as CalloutMap | undefined;
    const afterCallout = after?.callout as CalloutMap | undefined;

    // Created
    if (!before && after) {
      if (afterCallout && (afterCallout.status ?? "open") === "open") {
        await handleNewCallout(cid, chid, mid, after, afterCallout);
      }
      if (!after.isDeleted) await handleMentions(cid, chid, mid, after);
      return;
    }

    // Callout closed (open -> anything else)
    if (beforeCallout && afterCallout && (beforeCallout.status ?? "open") === "open" && afterCallout.status && afterCallout.status !== "open") {
      await handleClosed(cid, chid, mid, after!, afterCallout);
      return;
    }

    // Callout removed (soft delete) or message hard-deleted
    if (beforeCallout && !afterCallout) {
      await handleRemoved(cid, mid, beforeCallout);
    }
  },
);

async function handleNewCallout(cid: string, chid: string, mid: string, msg: FirebaseFirestore.DocumentData, c: CalloutMap) {
  const authorId: string = c.authorId || msg.authorId;
  const postedAt: Timestamp = c.postedAt instanceof Timestamp ? c.postedAt : msg.createdAt instanceof Timestamp ? msg.createdAt : Timestamp.now();

  const row: LedgerRow = {
    authorId,
    communityId: cid,
    channelId: chid,
    messageId: mid,
    ticker: String(c.ticker ?? "").toUpperCase(),
    assetType: c.assetType ?? "stock",
    direction: c.direction === "short" ? "short" : "long",
    entryPrice: Number(c.entryPrice ?? 0),
    status: "open",
    postedAt,
    excluded: false,
    updatedAt: Timestamp.now(),
  };
  try {
    await db.collection("calloutLedger").doc(ledgerId(cid, mid)).create(row);
  } catch (error: unknown) {
    if ((error as { code?: number }).code !== 6) throw error; // 6 = already exists (retried trigger)
  }

  // Backfill authorId / communityId / postedAt if an older app version left them out.
  if (!c.authorId || !c.communityId || !c.postedAt) {
    await db.doc(`communities/${cid}/channels/${chid}/messages/${mid}`).update({
      "callout.authorId": authorId,
      "callout.communityId": cid,
      "callout.postedAt": postedAt,
    });
  }

  const community = await getCommunity(cid);
  const members = await activeMemberIds(cid);
  const parts = [`${directionLabel(c.direction)} $${row.ticker} @ ${formatPrice(row.entryPrice)}`];
  if (typeof c.stopPrice === "number") parts.push(`Stop ${formatPrice(c.stopPrice)}`);
  if (typeof c.targetPrice === "number") parts.push(`Target ${formatPrice(c.targetPrice)}`);
  await notifyUsers(
    members,
    {
      type: "callout",
      title: `New callout in ${community?.name ?? "your community"}`,
      body: `@${msg.authorUsername ?? "trader"}: ${parts.join(" · ")}`,
      data: { route: "channel", communityId: cid, channelId: chid, messageId: mid, symbol: row.ticker },
    },
    { actorId: authorId, dedupeKey: `${cid}_${mid}` },
  );
}

async function handleMentions(cid: string, chid: string, mid: string, msg: FirebaseFirestore.DocumentData) {
  const usernames = extractMentions(msg.content ?? "").slice(0, MAX_MENTIONS_PER_ITEM);
  if (usernames.length === 0) return;
  const ids = await resolveUsernames(usernames);
  if (ids.size === 0) return;

  // Only notify people who can read the channel.
  const community = await getCommunity(cid);
  let targets = [...ids.values()];
  if (community?.isPaid || community?.isPrivate) {
    const members = new Set(await activeMemberIds(cid));
    targets = targets.filter((uid) => members.has(uid));
  }
  await notifyUsers(
    targets,
    {
      type: "mention",
      title: `@${msg.authorUsername ?? "someone"} mentioned you in ${community?.name ?? "a community"}`,
      body: snippet(msg.content ?? ""),
      data: { route: "channel", communityId: cid, channelId: chid, messageId: mid },
    },
    { actorId: msg.authorId, dedupeKey: `${cid}_${mid}` },
  );
}

async function handleClosed(cid: string, chid: string, mid: string, msg: FirebaseFirestore.DocumentData, c: CalloutMap) {
  const entry = Number(c.entryPrice ?? 0);
  const exit = typeof c.exitPrice === "number" ? c.exitPrice : typeof c.lastPrice === "number" ? c.lastPrice : entry;
  const result = percentMove(entry, exit, c.direction);
  const closedAt = c.closedAt instanceof Timestamp ? c.closedAt : Timestamp.now();
  const messageRef = db.doc(`communities/${cid}/channels/${chid}/messages/${mid}`);

  // The server is the source of truth for the result: recompute it from the exit price.
  const fixes: Record<string, unknown> = {};
  if (typeof c.resultPercent !== "number" || Math.abs(c.resultPercent - result) > 0.01) fixes["callout.resultPercent"] = result;
  if (typeof c.exitPrice !== "number") fixes["callout.exitPrice"] = exit;
  if (!(c.closedAt instanceof Timestamp)) fixes["callout.closedAt"] = closedAt;
  if (Object.keys(fixes).length > 0) await messageRef.update(fixes);

  const ledgerRef = db.collection("calloutLedger").doc(ledgerId(cid, mid));
  await ledgerRef.set(
    {
      authorId: c.authorId || msg.authorId,
      communityId: cid,
      channelId: chid,
      messageId: mid,
      ticker: String(c.ticker ?? "").toUpperCase(),
      assetType: c.assetType ?? "stock",
      direction: c.direction === "short" ? "short" : "long",
      entryPrice: entry,
      postedAt: c.postedAt instanceof Timestamp ? c.postedAt : msg.createdAt ?? Timestamp.now(),
      status: c.status,
      exitPrice: exit,
      closedAt,
      resultPercent: result,
      excluded: false,
      closedReason: c.closedBy === "server" ? "server" : "author",
      updatedAt: Timestamp.now(),
    },
    { merge: true },
  );

  // Members hear about it; the author too when the server closed it.
  const authorId: string = c.authorId || msg.authorId;
  const community = await getCommunity(cid);
  const members = await activeMemberIds(cid);
  const ticker = String(c.ticker ?? "").toUpperCase();
  await notifyUsers(
    members,
    {
      type: "callout_result",
      title: `$${ticker} ${statusLabel(c.status)} (${formatPercent(result)})`,
      body: `@${msg.authorUsername ?? "trader"}'s ${c.direction === "short" ? "short" : "long"} callout in ${community?.name ?? "your community"} closed at ${formatPrice(exit)}`,
      data: { route: "channel", communityId: cid, channelId: chid, messageId: mid, symbol: ticker },
    },
    { actorId: c.closedBy === "server" ? undefined : authorId, dedupeKey: `${cid}_${mid}` },
  );
}

async function handleRemoved(cid: string, mid: string, c: CalloutMap) {
  const ref = db.collection("calloutLedger").doc(ledgerId(cid, mid));
  const snap = await ref.get();
  if (!snap.exists) return;
  if (snap.get("status") !== "open") return; // closed callouts stay on the record

  if (typeof c.lastPrice === "number" && c.lastPrice > 0) {
    const entry = Number(snap.get("entryPrice") ?? c.entryPrice ?? 0);
    await ref.update({
      status: "closed",
      exitPrice: c.lastPrice,
      closedAt: Timestamp.now(),
      resultPercent: percentMove(entry, c.lastPrice, snap.get("direction")),
      closedReason: "deleted_open",
      updatedAt: FieldValue.serverTimestamp(),
    });
  } else {
    await ref.update({ excluded: true, closedReason: "deleted_unpriced", updatedAt: FieldValue.serverTimestamp() });
  }
  logger.info("Open callout removed", { cid, mid });
}
