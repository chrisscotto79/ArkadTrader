// Stripe client plus the membership / revenue bookkeeping shared by the callables,
// the webhook, moderation triggers and account deletion.
//
// Server-only Firestore docs used here (never readable by the app unless noted):
//   stripeAccounts/{uid}          Connect account of a community owner (owner can read)
//   stripeCustomers/{uid}         Stripe customer of a subscriber
//   subscriptions/{subscriptionId} one row per Stripe subscription: uid, communityId, status, price
//   stripeEvents/{eventId}        webhook idempotency markers
//   communities/{cid}/private/revenue  revenue summary (owner can read)

import Stripe from "stripe";
import { logger } from "firebase-functions";
import { db, FieldValue, Timestamp } from "./firebase.js";
import { STRIPE_SECRET_KEY } from "../secrets.js";
import { PLATFORM_FEE_PERCENT } from "../config.js";
import { notifyUsers, actorName } from "./notify.js";

let client: Stripe | undefined;

/** Stripe client. The SDK pins its own API version; set the webhook endpoint to the same version. */
export function stripe(): Stripe {
  if (!client) {
    client = new Stripe(STRIPE_SECRET_KEY.value(), {
      appInfo: { name: "Arkad Cloud Functions" },
      maxNetworkRetries: 2,
    });
  }
  return client;
}

export type MemberStatus = "active" | "trialing" | "past_due" | "canceled";

const ACCESS_STATUSES = new Set(["active", "trialing", "past_due"]);
/** `incomplete` means the first payment hasn't gone through yet: no access, but not ended either. */
const PENDING_STATUSES = new Set(["incomplete"]);

export function hasAccess(status: string): boolean {
  return ACCESS_STATUSES.has(status);
}

export function centsToDollars(cents: number): number {
  return Math.round(cents) / 100;
}

export function platformFeeCents(amountCents: number): number {
  return Math.round((amountCents * PLATFORM_FEE_PERCENT) / 100);
}

/** End of the current billing period (the field lives on subscription items in current API versions). */
export function periodEnd(sub: Stripe.Subscription): Timestamp | null {
  if (sub.status === "trialing" && sub.trial_end) return Timestamp.fromMillis(sub.trial_end * 1000);
  const ends = sub.items.data.map((i) => i.current_period_end).filter((v): v is number => typeof v === "number");
  return ends.length > 0 ? Timestamp.fromMillis(Math.max(...ends) * 1000) : null;
}

export function monthlyPrice(sub: Stripe.Subscription): number {
  let cents = 0;
  for (const item of sub.items.data) {
    const price = item.price;
    const unit = price.unit_amount ?? 0;
    const qty = item.quantity ?? 1;
    const interval = price.recurring?.interval ?? "month";
    const count = price.recurring?.interval_count ?? 1;
    const perMonth = interval === "year" ? unit / (12 * count) : interval === "week" ? (unit * 52) / (12 * count) : unit / count;
    cents += perMonth * qty;
  }
  return centsToDollars(cents);
}

// MARK: - Customers and accounts

export async function getOrCreateCustomer(uid: string, email?: string): Promise<string> {
  const ref = db.collection("stripeCustomers").doc(uid);
  const snap = await ref.get();
  const existing = snap.get("customerId");
  if (typeof existing === "string" && existing) return existing;
  const customer = await stripe().customers.create(
    { email, metadata: { uid } },
    { idempotencyKey: `arkad-customer-${uid}` },
  );
  await ref.set({ customerId: customer.id, createdAt: FieldValue.serverTimestamp() }, { merge: true });
  return customer.id;
}

export async function saveAccount(uid: string, account: Stripe.Account): Promise<void> {
  await db.collection("stripeAccounts").doc(uid).set(
    {
      accountId: account.id,
      chargesEnabled: account.charges_enabled === true,
      payoutsEnabled: account.payouts_enabled === true,
      detailsSubmitted: account.details_submitted === true,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

/** Fetch the owner's Connect account from Stripe and refresh `stripeAccounts/{uid}`. */
export async function refreshAccount(uid: string): Promise<Stripe.Account | null> {
  const snap = await db.collection("stripeAccounts").doc(uid).get();
  const accountId = snap.get("accountId");
  if (typeof accountId !== "string" || !accountId) return null;
  const account = await stripe().accounts.retrieve(accountId);
  await saveAccount(uid, account);
  return account;
}

// MARK: - Subscriptions -> memberships

interface SubscriptionRow {
  uid: string;
  communityId: string;
  ownerId?: string;
  status: string;
  priceMonthly: number;
  currentPeriodEnd: Timestamp | null;
  cancelAtPeriodEnd: boolean;
  customerId: string;
}

function rowFrom(sub: Stripe.Subscription): SubscriptionRow | null {
  const uid = sub.metadata?.uid;
  const communityId = sub.metadata?.communityId;
  if (!uid || !communityId) return null;
  return {
    uid,
    communityId,
    ownerId: sub.metadata?.ownerId,
    status: sub.status,
    priceMonthly: monthlyPrice(sub),
    currentPeriodEnd: periodEnd(sub),
    cancelAtPeriodEnd: sub.cancel_at_period_end === true || sub.cancel_at != null,
    customerId: typeof sub.customer === "string" ? sub.customer : sub.customer.id,
  };
}

/**
 * Bring Firestore in line with one Stripe subscription: the `subscriptions` row,
 * the member doc (`subscriptionStatus`, `currentPeriodEnd`), `users/{uid}.communityIds`,
 * the community's `memberCount`, and the revenue summary.
 * Returns what changed so the webhook can notify the owner.
 */
export async function applySubscription(sub: Stripe.Subscription): Promise<{ joined: boolean; left: boolean; row: SubscriptionRow | null }> {
  const row = rowFrom(sub);
  if (!row) {
    logger.warn("Subscription without Arkad metadata", { id: sub.id });
    return { joined: false, left: false, row: null };
  }
  const { uid, communityId } = row;
  await db.collection("subscriptions").doc(sub.id).set(
    { ...row, updatedAt: FieldValue.serverTimestamp(), createdAt: Timestamp.fromMillis(sub.created * 1000) },
    { merge: true },
  );

  if (PENDING_STATUSES.has(row.status)) return { joined: false, left: false, row };

  const communityRef = db.collection("communities").doc(communityId);
  const memberRef = communityRef.collection("members").doc(uid);
  const userRef = db.collection("users").doc(uid);

  // A banned user never gets (or keeps) a paid membership.
  if (hasAccess(row.status) && (await communityRef.collection("bans").doc(uid).get()).exists) {
    logger.info("Canceling subscription of a banned user", { uid, communityId });
    await stripe().subscriptions.cancel(sub.id);
    return { joined: false, left: false, row };
  }

  let joined = false;
  let left = false;

  if (hasAccess(row.status)) {
    await db.runTransaction(async (tx) => {
      const [member, community, user] = await Promise.all([tx.get(memberRef), tx.get(communityRef), tx.get(userRef)]);
      if (!community.exists || !user.exists) return;
      const fields = {
        subscriptionStatus: row.status as MemberStatus,
        currentPeriodEnd: row.currentPeriodEnd,
      };
      if (member.exists) {
        tx.update(memberRef, fields);
      } else {
        tx.set(memberRef, { userId: uid, role: "member", joinedAt: FieldValue.serverTimestamp(), ...fields });
        tx.update(communityRef, { memberCount: FieldValue.increment(1) });
        tx.update(userRef, { communityIds: FieldValue.arrayUnion(communityId) });
        joined = true;
      }
    });
  } else {
    // Ended: canceled, unpaid, incomplete_expired or paused.
    const other = await db
      .collection("subscriptions")
      .where("uid", "==", uid)
      .where("communityId", "==", communityId)
      .get();
    const stillPaying = other.docs.some((d) => d.id !== sub.id && hasAccess(String(d.get("status"))));
    if (!stillPaying) {
      await db.runTransaction(async (tx) => {
        const [member, community, user] = await Promise.all([tx.get(memberRef), tx.get(communityRef), tx.get(userRef)]);
        if (!member.exists) return;
        const isOwner = community.get("createdBy") === uid;
        if (isOwner) return;
        if (community.exists && community.get("isPaid") === true) {
          tx.delete(memberRef);
          tx.update(communityRef, { memberCount: FieldValue.increment(-1) });
          if (user.exists) tx.update(userRef, { communityIds: FieldValue.arrayRemove(communityId) });
          left = true;
        } else {
          // The community went free: keep them as a free member.
          tx.update(memberRef, { subscriptionStatus: FieldValue.delete(), currentPeriodEnd: FieldValue.delete() });
        }
      });
    }
  }

  await recomputeRevenueCounts(communityId);
  return { joined, left, row };
}

/** activeSubscribers, trialingSubscribers and mrr from the `subscriptions` rows. */
export async function recomputeRevenueCounts(communityId: string): Promise<void> {
  const subs = await db.collection("subscriptions").where("communityId", "==", communityId).get();
  let active = 0;
  let trialing = 0;
  let mrr = 0;
  for (const doc of subs.docs) {
    const status = String(doc.get("status"));
    if (status === "trialing") trialing += 1;
    if (status === "active" || status === "past_due") {
      active += 1;
      mrr += Number(doc.get("priceMonthly") ?? 0);
    }
  }
  const ref = db.collection("communities").doc(communityId).collection("private").doc("revenue");
  if (!(await db.collection("communities").doc(communityId).get()).exists) return;
  await ref.set(
    {
      activeSubscribers: active,
      trialingSubscribers: trialing,
      mrr: Math.round(mrr * 100) / 100,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

/**
 * Cancel subscriptions matching a filter. `atPeriodEnd` lets people keep what they
 * paid for (used when a community goes free); otherwise they end now.
 */
export async function cancelSubscriptions(
  filter: { uid?: string; communityId?: string },
  opts: { atPeriodEnd?: boolean; reason: string },
): Promise<number> {
  let query: FirebaseFirestore.Query = db.collection("subscriptions");
  if (filter.uid) query = query.where("uid", "==", filter.uid);
  if (filter.communityId) query = query.where("communityId", "==", filter.communityId);
  const snap = await query.get();
  let count = 0;
  for (const doc of snap.docs) {
    const status = String(doc.get("status"));
    if (!hasAccess(status) && status !== "incomplete") continue;
    try {
      if (opts.atPeriodEnd) {
        await stripe().subscriptions.update(doc.id, { cancel_at_period_end: true, metadata: { arkadCancelReason: opts.reason } });
      } else {
        await stripe().subscriptions.cancel(doc.id, { cancellation_details: { comment: opts.reason } });
      }
      count += 1;
    } catch (error) {
      logger.error("Cancel subscription failed", { id: doc.id, error: String(error) });
    }
  }
  return count;
}

/** Owner notification for a paid member subscribing or canceling. */
export async function notifySubscriptionChange(
  row: SubscriptionRow,
  kind: "subscribed" | "trial" | "canceled" | "ended",
  dedupeKey: string,
): Promise<void> {
  const communitySnap = await db.collection("communities").doc(row.communityId).get();
  const owner = row.ownerId || communitySnap.get("createdBy");
  if (!owner) return;
  const name = communitySnap.get("name") ?? "your community";
  const who = await actorName(row.uid);
  const titles: Record<typeof kind, string> = {
    subscribed: `${who} subscribed to ${name}`,
    trial: `${who} started a free trial of ${name}`,
    canceled: `${who} canceled their ${name} subscription`,
    ended: `${who}'s ${name} subscription ended`,
  };
  const body =
    kind === "canceled" && row.currentPeriodEnd
      ? `They keep access until ${row.currentPeriodEnd.toDate().toLocaleDateString("en-US", { month: "short", day: "numeric" })}.`
      : kind === "ended"
        ? "They no longer have access."
        : `$${row.priceMonthly.toFixed(2)}/month`;
  await notifyUsers(
    [owner],
    { type: "subscription", title: titles[kind], body, data: { route: "community", communityId: row.communityId, userId: row.uid } },
    { actorId: row.uid, dedupeKey },
  );
}
