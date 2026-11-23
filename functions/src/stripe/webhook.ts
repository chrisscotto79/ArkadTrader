// stripeWebhook: the HTTPS endpoint Stripe calls. The app never calls it.
//
// Two Stripe endpoints can point at this URL: one for platform events (checkout,
// subscriptions, invoices) and one for Connect events (account.updated). Each has
// its own signing secret; store both in STRIPE_WEBHOOK_SECRET separated by a comma.

import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import type Stripe from "stripe";
import { db, FieldValue } from "../lib/firebase.js";
import {
  stripe,
  applySubscription,
  saveAccount,
  notifySubscriptionChange,
  centsToDollars,
  platformFeeCents,
} from "../lib/stripe.js";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../secrets.js";
import { REGION } from "../config.js";

function verify(rawBody: Buffer, signature: string): Stripe.Event {
  const secrets = STRIPE_WEBHOOK_SECRET.value()
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  let lastError: unknown;
  for (const secret of secrets) {
    try {
      return stripe().webhooks.constructEvent(rawBody, signature, secret);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError ?? new Error("No webhook secret configured");
}

export const stripeWebhook = onRequest(
  { region: REGION, secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET], cors: false, invoker: "public" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }
    const signature = req.header("stripe-signature");
    if (!signature) {
      res.status(400).send("Missing signature");
      return;
    }

    let event: Stripe.Event;
    try {
      event = verify(req.rawBody, signature);
    } catch (error) {
      logger.warn("Stripe signature check failed", { error: String(error) });
      res.status(400).send("Bad signature");
      return;
    }

    try {
      await handle(event);
      res.json({ received: true });
    } catch (error) {
      // A 500 makes Stripe retry later, which is what we want for transient failures.
      logger.error("Stripe webhook failed", { type: event.type, id: event.id, error: String(error) });
      res.status(500).send("Webhook handler failed");
    }
  },
);

async function handle(event: Stripe.Event): Promise<void> {
  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object;
      if (session.mode !== "subscription" || !session.subscription) return;
      const subId = typeof session.subscription === "string" ? session.subscription : session.subscription.id;
      const sub = await stripe().subscriptions.retrieve(subId);
      const { row } = await applySubscription(sub);
      if (row) await notifySubscriptionChange(row, sub.status === "trialing" ? "trial" : "subscribed", `${sub.id}_new`);
      return;
    }

    case "customer.subscription.updated": {
      const sub = event.data.object;
      const previous = (event.data.previous_attributes ?? {}) as Partial<Stripe.Subscription>;
      const { row } = await applySubscription(sub);
      const nowCanceling = sub.cancel_at_period_end === true || sub.cancel_at != null;
      const wasCanceling = previous.cancel_at_period_end === true || (previous.cancel_at !== undefined && previous.cancel_at !== null);
      const cancelChanged = "cancel_at_period_end" in previous || "cancel_at" in previous;
      if (row && nowCanceling && cancelChanged && !wasCanceling) {
        await notifySubscriptionChange(row, "canceled", `${sub.id}_cancel`);
      }
      return;
    }

    case "customer.subscription.deleted": {
      const sub = event.data.object;
      const { row, left } = await applySubscription(sub);
      if (row && left) await notifySubscriptionChange(row, "ended", `${sub.id}_ended`);
      return;
    }

    case "invoice.paid": {
      await recordInvoice(event.id, event.data.object);
      return;
    }

    case "account.updated": {
      const account = event.data.object;
      let uid = account.metadata?.uid;
      if (!uid) {
        const match = await db.collection("stripeAccounts").where("accountId", "==", account.id).limit(1).get();
        uid = match.docs[0]?.id;
      }
      if (uid) await saveAccount(uid, account);
      return;
    }

    default:
      logger.debug("Unhandled Stripe event", { type: event.type });
  }
}

/** Lifetime totals in communities/{cid}/private/revenue. Idempotent per event. */
async function recordInvoice(eventId: string, invoice: Stripe.Invoice): Promise<void> {
  const amount = invoice.amount_paid ?? 0;
  if (amount <= 0) return; // trial and $0 invoices

  const details = invoice.parent?.subscription_details ?? null;
  let communityId = details?.metadata?.communityId;
  if (!communityId && details?.subscription) {
    const subId = typeof details.subscription === "string" ? details.subscription : details.subscription.id;
    communityId = (await db.collection("subscriptions").doc(subId).get()).get("communityId");
  }
  if (!communityId) {
    logger.info("Paid invoice without an Arkad community", { invoice: invoice.id });
    return;
  }

  const fee = platformFeeCents(amount);
  const marker = db.collection("stripeEvents").doc(eventId);
  const communityRef = db.collection("communities").doc(communityId);
  const revenue = communityRef.collection("private").doc("revenue");
  await db.runTransaction(async (tx) => {
    const [seen, community] = await Promise.all([tx.get(marker), tx.get(communityRef)]);
    if (seen.exists) return;
    tx.create(marker, { type: "invoice.paid", invoiceId: invoice.id, processedAt: FieldValue.serverTimestamp() });
    if (!community.exists) return;
    tx.set(
      revenue,
      {
        lifetimeGross: FieldValue.increment(centsToDollars(amount)),
        lifetimeArkadFees: FieldValue.increment(centsToDollars(fee)),
        lifetimeNet: FieldValue.increment(centsToDollars(amount - fee)),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}
