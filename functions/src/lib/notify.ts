// Creates `notifications/{id}` documents (docs/backend-contracts.md, section 2).
// The push itself is sent by `onNotificationCreated` (notifications/push.ts).

import { logger } from "firebase-functions";
import { db, FieldValue, tolerantBulkWriter } from "./firebase.js";

export type NotificationType =
  | "callout"
  | "callout_result"
  | "mention"
  | "reply"
  | "like"
  | "follow"
  | "member_joined"
  | "subscription"
  | "price_alert";

export type Route = "community" | "channel" | "post" | "profile" | "portfolio" | "learn" | "watchlist";

export interface NotificationData {
  route: Route;
  communityId?: string;
  channelId?: string;
  messageId?: string;
  postId?: string;
  userId?: string;
  symbol?: string;
}

export interface NotificationContent {
  type: NotificationType;
  title: string;
  body: string;
  data: NotificationData;
}

/** Contract: type -> users/{uid}.notificationPrefs key */
export const PREF_KEY: Record<NotificationType, string> = {
  callout: "callouts",
  callout_result: "calloutResults",
  mention: "mentions",
  reply: "replies",
  like: "likes",
  follow: "follows",
  member_joined: "communityActivity",
  subscription: "communityActivity",
  price_alert: "priceAlerts",
};

/** Firestore document ids can't contain "/". Keep ids short and deterministic. */
function safeId(parts: string[]): string {
  return parts.map((p) => p.replace(/\//g, "_")).join("_").slice(0, 700);
}

/**
 * Everyone involved in a block with `actorId`, in either direction: people who
 * blocked the actor, and people the actor blocked. One collection-group query plus
 * one subcollection read, instead of a read per recipient.
 */
export async function blockedWith(actorId: string): Promise<Set<string>> {
  const out = new Set<string>();
  if (!actorId) return out;
  const [blockedActor, actorBlocked] = await Promise.all([
    db.collectionGroup("blockedUsers").where("userId", "==", actorId).get(),
    db.collection("users").doc(actorId).collection("blockedUsers").get(),
  ]);
  for (const doc of blockedActor.docs) {
    const blocker = doc.ref.parent.parent?.id;
    if (blocker) out.add(blocker);
  }
  for (const doc of actorBlocked.docs) out.add(doc.id);
  return out;
}

/**
 * Create one notification per recipient.
 *
 * - `actorId` never notifies themselves, and anyone in a block with the actor is skipped.
 * - `dedupeKey` makes the document id deterministic, so a retried trigger (or a
 *   like / unlike / like) never creates a second notification for the same event.
 * - Large fan-outs go through a BulkWriter, which batches and throttles writes.
 */
export async function notifyUsers(
  recipientIds: Iterable<string>,
  content: NotificationContent,
  opts: { actorId?: string; dedupeKey: string },
): Promise<number> {
  const blocked = opts.actorId ? await blockedWith(opts.actorId) : new Set<string>();
  const recipients = [...new Set(recipientIds)].filter(
    (uid) => uid && uid !== opts.actorId && !blocked.has(uid),
  );
  if (recipients.length === 0) return 0;

  const writer = tolerantBulkWriter();
  for (const uid of recipients) {
    const ref = db.collection("notifications").doc(safeId([content.type, opts.dedupeKey, uid]));
    writer.create(ref, {
      userId: uid,
      type: content.type,
      title: content.title,
      body: content.body,
      data: stripUndefined(content.data),
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  await writer.close();
  logger.info("Notifications created", { type: content.type, count: recipients.length });
  return recipients.length;
}

function stripUndefined(data: NotificationData): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value !== undefined && value !== null && value !== "") out[key] = String(value);
  }
  return out;
}

/** Truncate text for a notification body. */
export function snippet(text: string, max = 120): string {
  const clean = (text || "").replace(/\s+/g, " ").trim();
  return clean.length > max ? clean.slice(0, max - 1) + "…" : clean;
}

// MARK: - Mentions

const MENTION = /@([A-Za-z0-9_]+)/g;

/** Usernames mentioned in text, lowercased, the same pattern the app uses. */
export function extractMentions(text: string): string[] {
  const out = new Set<string>();
  for (const match of (text || "").matchAll(MENTION)) out.add(match[1].toLowerCase());
  return [...out];
}

/** username -> uid for the given usernames (usernames are stored lowercased). */
export async function resolveUsernames(usernames: string[]): Promise<Map<string, string>> {
  const out = new Map<string, string>();
  const unique = [...new Set(usernames.map((u) => u.toLowerCase()))].filter(Boolean);
  for (let i = 0; i < unique.length; i += 30) {
    const snap = await db.collection("users").where("username", "in", unique.slice(i, i + 30)).get();
    for (const doc of snap.docs) {
      const name = doc.get("username");
      if (typeof name === "string") out.set(name.toLowerCase(), doc.id);
    }
  }
  return out;
}

/** Display name for an actor: "@username", falling back to "Someone". */
export async function actorName(uid: string, fallback?: string): Promise<string> {
  if (fallback) return `@${fallback}`;
  const snap = await db.collection("users").doc(uid).get();
  const username = snap.get("username");
  return typeof username === "string" && username ? `@${username}` : "Someone";
}
