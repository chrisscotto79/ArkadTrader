import { db } from "./firebase.js";

export interface CommunityDoc {
  name?: string;
  createdBy?: string;
  isPaid?: boolean;
  isPrivate?: boolean;
  priceMonthly?: number;
  trialDays?: number;
  stripeProductId?: string;
  stripePriceId?: string;
  memberCount?: number;
}

export async function getCommunity(cid: string): Promise<CommunityDoc | null> {
  const snap = await db.collection("communities").doc(cid).get();
  return snap.exists ? (snap.data() as CommunityDoc) : null;
}

/** Member ids that currently have access (paid members whose subscription ended are excluded). */
export async function activeMemberIds(cid: string): Promise<string[]> {
  const snap = await db.collection("communities").doc(cid).collection("members").select("subscriptionStatus").get();
  return snap.docs
    .filter((d) => d.get("subscriptionStatus") !== "canceled")
    .map((d) => d.id);
}

export async function isMember(cid: string, uid: string): Promise<boolean> {
  const snap = await db.collection("communities").doc(cid).collection("members").doc(uid).get();
  return snap.exists && snap.get("subscriptionStatus") !== "canceled";
}
