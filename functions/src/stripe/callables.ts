// Callable functions for paid communities (docs/backend-contracts.md, section 4).

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { db, FieldValue } from "../lib/firebase.js";
import { stripe, saveAccount, refreshAccount, getOrCreateCustomer, cancelSubscriptions, hasAccess } from "../lib/stripe.js";
import { STRIPE_SECRET_KEY } from "../secrets.js";
import {
  REGION,
  PLATFORM_FEE_PERCENT,
  MIN_PRICE_MONTHLY,
  MAX_PRICE_MONTHLY,
  ALLOWED_TRIAL_DAYS,
  CURRENCY,
  appReturnUrl,
} from "../config.js";

const opts = { region: REGION, secrets: [STRIPE_SECRET_KEY] };

function requireAuth(request: CallableRequest): { uid: string; email?: string } {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  return { uid: request.auth.uid, email: request.auth.token.email };
}

/** Turn Stripe errors into something the app can show. */
function stripeFailure(error: unknown, fallback: string): never {
  if (error instanceof HttpsError) throw error;
  logger.error(fallback, { error: String(error) });
  const message = (error as { message?: string })?.message;
  throw new HttpsError("internal", message ? `${fallback}: ${message}` : fallback);
}

/** `{}` -> `{ url }`: Stripe Express onboarding, returning to arkad://payouts/done. */
export const createConnectOnboardingLink = onCall(opts, async (request) => {
  const { uid, email } = requireAuth(request);
  try {
    const ref = db.collection("stripeAccounts").doc(uid);
    let accountId = (await ref.get()).get("accountId") as string | undefined;
    if (!accountId) {
      const account = await stripe().accounts.create(
        {
          type: "express",
          email,
          metadata: { uid },
          capabilities: { card_payments: { requested: true }, transfers: { requested: true } },
          business_profile: { product_description: "Paid trading community subscriptions on Arkad" },
        },
        { idempotencyKey: `arkad-connect-${uid}` },
      );
      await saveAccount(uid, account);
      accountId = account.id;
    }
    const link = await stripe().accountLinks.create({
      account: accountId,
      // An expired link sends them back to the app, which can simply ask for a new one.
      refresh_url: appReturnUrl("payouts/done"),
      return_url: appReturnUrl("payouts/done"),
      type: "account_onboarding",
    });
    return { url: link.url };
  } catch (error) {
    stripeFailure(error, "Couldn't start payout setup");
  }
});

/** `{}` -> `{ url }`: the Express dashboard (payouts, balance, tax forms). */
export const getConnectDashboardLink = onCall(opts, async (request) => {
  const { uid } = requireAuth(request);
  try {
    const account = await refreshAccount(uid);
    if (!account) throw new HttpsError("failed-precondition", "Set up payouts first.");
    if (!account.details_submitted) throw new HttpsError("failed-precondition", "Finish payout setup first.");
    const link = await stripe().accounts.createLoginLink(account.id);
    return { url: link.url };
  } catch (error) {
    stripeFailure(error, "Couldn't open the payouts dashboard");
  }
});

interface SetPriceInput {
  communityId?: unknown;
  isPaid?: unknown;
  priceMonthly?: unknown;
  trialDays?: unknown;
}

/** `{ communityId, isPaid, priceMonthly?, trialDays? }` -> `{ ok }`. Owner only. */
export const setCommunityPrice = onCall(opts, async (request: CallableRequest<SetPriceInput>) => {
  const { uid } = requireAuth(request);
  const { communityId, isPaid } = request.data ?? {};
  if (typeof communityId !== "string" || !communityId) throw new HttpsError("invalid-argument", "communityId is required.");
  if (typeof isPaid !== "boolean") throw new HttpsError("invalid-argument", "isPaid must be true or false.");

  const communityRef = db.collection("communities").doc(communityId);
  const community = await communityRef.get();
  if (!community.exists) throw new HttpsError("not-found", "Community not found.");
  if (community.get("createdBy") !== uid) throw new HttpsError("permission-denied", "Only the owner can set the price.");

  try {
    if (!isPaid) {
      const oldPrice = community.get("stripePriceId") as string | undefined;
      await communityRef.update({ isPaid: false, updatedAt: FieldValue.serverTimestamp() });
      if (oldPrice) await stripe().prices.update(oldPrice, { active: false });
      // Current subscribers keep access until their period ends, then stay on as free members.
      const canceled = await cancelSubscriptions({ communityId }, { atPeriodEnd: true, reason: "community_made_free" });
      logger.info("Community made free", { communityId, canceled });
      return { ok: true };
    }

    const priceMonthly = Number(request.data.priceMonthly);
    const trialDays = request.data.trialDays === undefined ? 0 : Number(request.data.trialDays);
    if (!Number.isFinite(priceMonthly) || priceMonthly < MIN_PRICE_MONTHLY || priceMonthly > MAX_PRICE_MONTHLY) {
      throw new HttpsError("invalid-argument", `Price must be between $${MIN_PRICE_MONTHLY.toFixed(2)} and $${MAX_PRICE_MONTHLY.toFixed(2)}.`);
    }
    if (!ALLOWED_TRIAL_DAYS.includes(trialDays)) {
      throw new HttpsError("invalid-argument", `Trial must be ${ALLOWED_TRIAL_DAYS.join(", ")} days.`);
    }
    const account = await refreshAccount(uid);
    if (!account?.charges_enabled) {
      throw new HttpsError("failed-precondition", "Finish payout setup before charging for your community.");
    }

    const cents = Math.round(priceMonthly * 100);
    let productId = community.get("stripeProductId") as string | undefined;
    if (!productId) {
      const product = await stripe().products.create(
        { name: String(community.get("name") ?? "Arkad community"), metadata: { communityId, ownerId: uid } },
        { idempotencyKey: `arkad-product-${communityId}` },
      );
      productId = product.id;
    }

    let priceId = community.get("stripePriceId") as string | undefined;
    let reuse = false;
    if (priceId) {
      const current = await stripe().prices.retrieve(priceId);
      reuse = current.active && current.unit_amount === cents && current.recurring?.interval === "month";
    }
    if (!reuse) {
      const price = await stripe().prices.create({
        product: productId,
        currency: CURRENCY,
        unit_amount: cents,
        recurring: { interval: "month" },
        metadata: { communityId },
      });
      // Existing subscribers stay on their old (archived) price; new subscribers get this one.
      if (priceId) await stripe().prices.update(priceId, { active: false });
      priceId = price.id;
    }

    await communityRef.update({
      isPaid: true,
      priceMonthly: cents / 100,
      trialDays,
      stripeProductId: productId,
      stripePriceId: priceId,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { ok: true };
  } catch (error) {
    stripeFailure(error, "Couldn't update the price");
  }
});

/** `{ communityId }` -> `{ url }`: Stripe Checkout for a monthly subscription. */
export const createCheckoutSession = onCall(opts, async (request: CallableRequest<{ communityId?: unknown }>) => {
  const { uid, email } = requireAuth(request);
  const communityId = request.data?.communityId;
  if (typeof communityId !== "string" || !communityId) throw new HttpsError("invalid-argument", "communityId is required.");

  const communityRef = db.collection("communities").doc(communityId);
  const [community, ban, member] = await Promise.all([
    communityRef.get(),
    communityRef.collection("bans").doc(uid).get(),
    communityRef.collection("members").doc(uid).get(),
  ]);
  if (!community.exists) throw new HttpsError("not-found", "Community not found.");
  const ownerId = community.get("createdBy") as string;
  const priceId = community.get("stripePriceId") as string | undefined;
  if (community.get("isPaid") !== true || !priceId) throw new HttpsError("failed-precondition", "This community is free to join.");
  if (ownerId === uid) throw new HttpsError("failed-precondition", "You own this community.");
  if (ban.exists) throw new HttpsError("permission-denied", "You can't join this community.");
  if (member.exists && member.get("subscriptionStatus") !== "canceled") {
    throw new HttpsError("already-exists", "You're already a member.");
  }

  const ownerAccount = await db.collection("stripeAccounts").doc(ownerId).get();
  const destination = ownerAccount.get("accountId") as string | undefined;
  if (!destination || ownerAccount.get("chargesEnabled") !== true) {
    throw new HttpsError("failed-precondition", "This community isn't accepting subscriptions right now.");
  }

  const history = await db.collection("subscriptions").where("uid", "==", uid).where("communityId", "==", communityId).get();
  if (history.docs.some((d) => hasAccess(String(d.get("status"))))) {
    throw new HttpsError("already-exists", "You already have a subscription to this community.");
  }
  const trialDays = Number(community.get("trialDays") ?? 0);
  const trialEligible = history.empty && trialDays > 0; // one free trial per person per community

  try {
    const customer = await getOrCreateCustomer(uid, email);
    const metadata = { uid, communityId, ownerId };
    const session = await stripe().checkout.sessions.create({
      mode: "subscription",
      customer,
      client_reference_id: uid,
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: appReturnUrl("checkout/success", { communityId }),
      cancel_url: appReturnUrl("checkout/cancel"),
      metadata,
      subscription_data: {
        application_fee_percent: PLATFORM_FEE_PERCENT,
        transfer_data: { destination },
        metadata,
        ...(trialEligible ? { trial_period_days: trialDays } : {}),
      },
    });
    if (!session.url) throw new Error("Stripe returned no checkout URL");
    return { url: session.url };
  } catch (error) {
    stripeFailure(error, "Couldn't start checkout");
  }
});

/** `{}` -> `{ url }`: Stripe's customer portal (cancel, update card, invoices). */
export const createBillingPortalSession = onCall(opts, async (request) => {
  const { uid } = requireAuth(request);
  const customerId = (await db.collection("stripeCustomers").doc(uid).get()).get("customerId") as string | undefined;
  if (!customerId) throw new HttpsError("failed-precondition", "You don't have any subscriptions yet.");
  try {
    const session = await stripe().billingPortal.sessions.create({
      customer: customerId,
      return_url: appReturnUrl("billing/done"),
    });
    return { url: session.url };
  } catch (error) {
    stripeFailure(error, "Couldn't open billing");
  }
});
