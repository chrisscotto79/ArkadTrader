// Server-side moderation and cleanup that the app can't (or shouldn't) do itself.

import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { db, FieldValue, tolerantBulkWriter } from "../lib/firebase.js";
import { cancelSubscriptions, hasAccess, stripe, recomputeRevenueCounts } from "../lib/stripe.js";
import { STRIPE_SECRET_KEY } from "../secrets.js";
import { REGION, POST_AUTO_HIDE_REPORTS } from "../config.js";

/**
 * reports/{id} created. Post reports count once per reporter; a post reported by
 * POST_AUTO_HIDE_REPORTS different people is hidden (`isHidden`). The rules don't
 * let clients write reportCount or isHidden on other people's posts.
 */
export const onReportCreated = onDocumentCreated({ document: "reports/{reportId}", region: REGION }, async (event) => {
  const report = event.data?.data();
  if (!report) return;
  const isPost = report.targetType === "post" || (!report.targetType && report.postId);
  const postId: string | undefined = report.targetType === "post" ? report.targetId : report.postId;
  const reporter: string | undefined = report.reportedBy;
  if (!isPost || !postId || !reporter) return;

  const postRef = db.collection("posts").doc(postId);
  const markerRef = postRef.collection("reporters").doc(reporter);
  await db.runTransaction(async (tx) => {
    const [post, marker] = await Promise.all([tx.get(postRef), tx.get(markerRef)]);
    if (!post.exists || marker.exists) return;
    const count = Number(post.get("reportCount") ?? 0) + 1;
    tx.create(markerRef, { reportedAt: FieldValue.serverTimestamp() });
    const update: Record<string, unknown> = { reportCount: count };
    if (count >= POST_AUTO_HIDE_REPORTS && post.get("isHidden") !== true) {
      update.isHidden = true;
      update.hiddenAt = FieldValue.serverTimestamp();
      update.hiddenReason = `Multiple reports (${count} reports)`;
    }
    tx.update(postRef, update);
  });
});

/**
 * communities/{cid}/bans/{uid} created. If the app didn't already remove the
 * membership in the same batch, do it here. Deleting the member doc then cancels
 * any paid subscription (onMemberRemoved).
 */
export const onBanCreated = onDocumentCreated({ document: "communities/{cid}/bans/{uid}", region: REGION }, async (event) => {
  const { cid, uid } = event.params;
  const communityRef = db.collection("communities").doc(cid);
  const memberRef = communityRef.collection("members").doc(uid);
  const userRef = db.collection("users").doc(uid);
  await db.runTransaction(async (tx) => {
    const [member, community, user] = await Promise.all([tx.get(memberRef), tx.get(communityRef), tx.get(userRef)]);
    if (!member.exists || !community.exists || community.get("createdBy") === uid) return;
    tx.delete(memberRef);
    tx.update(communityRef, { memberCount: FieldValue.increment(-1) });
    if (user.exists) tx.update(userRef, { communityIds: FieldValue.arrayRemove(cid) });
  });
});

/**
 * communities/{cid}/members/{uid} deleted. When the member had a live paid
 * subscription (removed, banned, or left), cancel it in Stripe right away so they
 * aren't charged for access they no longer have. When the webhook removed them
 * because the subscription already ended, there's nothing left to cancel.
 */
export const onMemberRemoved = onDocumentDeleted(
  { document: "communities/{cid}/members/{uid}", region: REGION, secrets: [STRIPE_SECRET_KEY] },
  async (event) => {
    const { cid, uid } = event.params;
    const status = event.data?.get("subscriptionStatus");
    if (!status || !hasAccess(String(status))) return;
    const subs = await db.collection("subscriptions").where("uid", "==", uid).where("communityId", "==", cid).get();
    for (const doc of subs.docs) {
      if (!hasAccess(String(doc.get("status")))) continue;
      try {
        await stripe().subscriptions.cancel(doc.id, { cancellation_details: { comment: "removed_from_community" } });
        logger.info("Canceled subscription of removed member", { cid, uid, subscription: doc.id });
      } catch (error) {
        logger.error("Cancel on member removal failed", { cid, uid, error: String(error) });
      }
    }
    await recomputeRevenueCounts(cid);
  },
);

/**
 * communities/{cid} deleted (by its owner, or by account deletion). Firestore
 * doesn't delete subcollections, so do it here; cancel paid subscriptions; drop the
 * id from every member's communityIds; archive the Stripe product.
 */
export const onCommunityDeleted = onDocumentDeleted(
  { document: "communities/{cid}", region: REGION, secrets: [STRIPE_SECRET_KEY], timeoutSeconds: 540, memory: "512MiB" },
  async (event) => {
    const { cid } = event.params;
    const data = event.data?.data() ?? {};
    const communityRef = db.collection("communities").doc(cid);

    if (data.isPaid || data.stripeProductId) {
      const canceled = await cancelSubscriptions({ communityId: cid }, { reason: "community_deleted" });
      logger.info("Community deleted; subscriptions canceled", { cid, canceled });
      try {
        if (data.stripePriceId) await stripe().prices.update(data.stripePriceId, { active: false });
        if (data.stripeProductId) await stripe().products.update(data.stripeProductId, { active: false });
      } catch (error) {
        logger.warn("Archiving Stripe product failed", { cid, error: String(error) });
      }
    }

    const members = await communityRef.collection("members").get();
    const writer = tolerantBulkWriter();
    for (const m of members.docs) {
      writer.update(db.collection("users").doc(m.id), { communityIds: FieldValue.arrayRemove(cid) });
    }
    await writer.close();
    await db.recursiveDelete(communityRef);
  },
);
