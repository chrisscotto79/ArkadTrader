// Auth onDelete (v1 API; v2 has no equivalent trigger): clean up everything that
// belongs to a deleted account (docs/backend-contracts.md, section 8).
// The app only calls Auth.currentUser.delete().

import * as functionsV1 from "firebase-functions/v1";
import { logger } from "firebase-functions";
import { db, FieldValue, Timestamp, tolerantBulkWriter, storage } from "../lib/firebase.js";
import { cancelSubscriptions } from "../lib/stripe.js";
import { snaptrade, getCredentials } from "../lib/snaptrade.js";
import { STRIPE_SECRET_KEY, SNAPTRADE_CLIENT_ID, SNAPTRADE_CONSUMER_KEY } from "../secrets.js";
import { REGION } from "../config.js";

export const onAccountDeleted = functionsV1
  .region(REGION)
  .runWith({
    secrets: [STRIPE_SECRET_KEY, SNAPTRADE_CLIENT_ID, SNAPTRADE_CONSUMER_KEY],
    timeoutSeconds: 540,
    memory: "1GB",
  })
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    logger.info("Cleaning up deleted account", { uid });
    await step("stripe", () => cleanupStripe(uid));
    await step("snaptrade", () => cleanupSnaptrade(uid));
    await step("owned communities", () => deleteOwnedCommunities(uid));
    await step("memberships", () => removeMemberships(uid));
    await step("chat messages", () => softDeleteMessages(uid));
    await step("social", () => deleteSocial(uid));
    await step("content", () => deleteContent(uid));
    await step("track record", () => deleteTrackRecord(uid));
    await step("storage", () => deleteFiles(uid));
    await step("user doc", () => db.recursiveDelete(db.collection("users").doc(uid)));
    logger.info("Account cleanup finished", { uid });
  });

/** Run one cleanup step; a failure is logged and the rest still run. */
async function step(name: string, fn: () => Promise<unknown>): Promise<void> {
  try {
    await fn();
  } catch (error) {
    logger.error(`Account cleanup step failed: ${name}`, { error: String(error) });
  }
}

async function cleanupStripe(uid: string) {
  // Their own subscriptions end now.
  const canceled = await cancelSubscriptions({ uid }, { reason: "account_deleted" });
  logger.info("Canceled subscriptions", { uid, canceled });
  // The Connect account itself stays in Stripe (it may still hold a balance to pay out).
  await db.collection("stripeAccounts").doc(uid).delete();
  await db.collection("stripeCustomers").doc(uid).delete();
}

async function cleanupSnaptrade(uid: string) {
  const creds = await getCredentials(uid);
  if (creds) {
    try {
      await snaptrade().authentication.deleteSnapTradeUser({ userId: creds.userId });
    } catch (error) {
      logger.warn("SnapTrade user delete failed", { uid, error: String(error) });
    }
  }
  await db.recursiveDelete(db.collection("snaptradeUsers").doc(uid));
}

/** Deleting the community doc runs onCommunityDeleted, which cancels subscriptions and deletes everything under it. */
async function deleteOwnedCommunities(uid: string) {
  const owned = await db.collection("communities").where("createdBy", "==", uid).get();
  for (const doc of owned.docs) await doc.ref.delete();
}

async function removeMemberships(uid: string) {
  const memberships = await db.collectionGroup("members").where("userId", "==", uid).get();
  const writer = tolerantBulkWriter();
  for (const m of memberships.docs) {
    const community = m.ref.parent.parent;
    if (!community) continue;
    writer.delete(m.ref);
    writer.update(community, { memberCount: FieldValue.increment(-1) });
  }
  const reactions = await db.collectionGroup("reactions").where("userId", "==", uid).get();
  for (const r of reactions.docs) writer.delete(r.ref);
  await writer.close();
}

async function softDeleteMessages(uid: string) {
  const messages = await db.collectionGroup("messages").where("authorId", "==", uid).get();
  const writer = tolerantBulkWriter();
  for (const m of messages.docs) {
    // Community chat messages only; direct messages (top-level `messages`) are deleted below.
    if (!m.ref.parent.parent || m.get("isDeleted") === true) continue;
    writer.update(m.ref, {
      isDeleted: true,
      content: "",
      deletedBy: uid,
      deletedAt: Timestamp.now(),
      callout: FieldValue.delete(),
      authorAvatarURL: FieldValue.delete(),
    });
  }
  const direct = await db.collection("messages").where("senderId", "==", uid).get();
  for (const m of direct.docs) writer.delete(m.ref);
  await writer.close();
}

async function deleteSocial(uid: string) {
  const userRef = db.collection("users").doc(uid);
  const [following, followers, blockedBy] = await Promise.all([
    userRef.collection("following").get(),
    userRef.collection("followers").get(),
    db.collectionGroup("blockedUsers").where("userId", "==", uid).get(),
  ]);
  const writer = tolerantBulkWriter();
  for (const f of following.docs) {
    const other = db.collection("users").doc(f.id);
    writer.delete(other.collection("followers").doc(uid));
    writer.update(other, { followersCount: FieldValue.increment(-1) });
  }
  for (const f of followers.docs) {
    const other = db.collection("users").doc(f.id);
    writer.delete(other.collection("following").doc(uid));
    writer.update(other, { followingCount: FieldValue.increment(-1) });
  }
  for (const b of blockedBy.docs) writer.delete(b.ref);
  await writer.close();
}

async function deleteContent(uid: string) {
  // Likes and comments on other people's posts, with their counters.
  const [likes, comments] = await Promise.all([
    db.collectionGroup("likes").where("userId", "==", uid).get(),
    db.collectionGroup("comments").where("authorId", "==", uid).get(),
  ]);
  const writer = tolerantBulkWriter();
  for (const l of likes.docs) {
    const post = l.ref.parent.parent;
    if (!post || post.parent.id !== "posts") continue;
    writer.delete(l.ref);
    writer.update(post, { likesCount: FieldValue.increment(-1) });
  }
  for (const c of comments.docs) {
    const post = c.ref.parent.parent;
    writer.delete(c.ref);
    if (post && post.parent.id === "posts" && !c.get("parentCommentId")) {
      writer.update(post, { commentsCount: FieldValue.increment(-1) });
    }
  }
  await writer.flush();

  // Their own posts (with comments and likes), trades, activity and notifications.
  const posts = await db.collection("posts").where("authorId", "==", uid).get();
  for (const p of posts.docs) await db.recursiveDelete(p.ref);
  for (const [collection, field] of [
    ["trades", "userId"],
    ["activity", "userId"],
    ["userActivity", "userId"],
    ["notifications", "userId"],
  ] as const) {
    const snap = await db.collection(collection).where(field, "==", uid).get();
    for (const d of snap.docs) writer.delete(d.ref);
  }
  await writer.close();
}

async function deleteTrackRecord(uid: string) {
  const writer = tolerantBulkWriter();
  const [ledger, stats] = await Promise.all([
    db.collection("calloutLedger").where("authorId", "==", uid).get(),
    db.collectionGroup("traderStats").where("userId", "==", uid).get(),
  ]);
  for (const d of ledger.docs) writer.delete(d.ref);
  for (const d of stats.docs) writer.delete(d.ref);
  writer.delete(db.collection("traderStats").doc(uid));
  await writer.close();
}

async function deleteFiles(uid: string) {
  const bucket = storage().bucket();
  await bucket.file(`profile_images/${uid}.jpg`).delete({ ignoreNotFound: true });
}
