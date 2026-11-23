// SnapTrade client and the server-only user record.
//   snaptradeUsers/{uid}: { snaptradeUserId, userSecret, createdAt }   (server only)
//   snaptradeUsers/{uid}/processedActivities/{activityId}             (import dedupe)

import { Snaptrade, SnaptradeAuth } from "snaptrade-typescript-sdk";
import { db, FieldValue } from "./firebase.js";
import { SNAPTRADE_CLIENT_ID, SNAPTRADE_CONSUMER_KEY } from "../secrets.js";

let client: ReturnType<typeof makeClient> | undefined;

function makeClient() {
  return new Snaptrade({
    auth: SnaptradeAuth.commercialApiKey({
      clientId: SNAPTRADE_CLIENT_ID.value(),
      consumerKey: SNAPTRADE_CONSUMER_KEY.value(),
    }),
  });
}

export function snaptrade() {
  if (!client) client = makeClient();
  return client;
}

export interface SnaptradeCredentials {
  userId: string;
  userSecret: string;
}

/** SnapTrade's user id for an Arkad user: stable and not an email address. */
export function snaptradeUserIdFor(uid: string): string {
  return `arkad-${uid}`;
}

export async function getCredentials(uid: string): Promise<SnaptradeCredentials | null> {
  const snap = await db.collection("snaptradeUsers").doc(uid).get();
  const userId = snap.get("snaptradeUserId");
  const userSecret = snap.get("userSecret");
  return typeof userId === "string" && typeof userSecret === "string" ? { userId, userSecret } : null;
}

export async function getOrRegister(uid: string): Promise<SnaptradeCredentials> {
  const existing = await getCredentials(uid);
  if (existing) return existing;
  const userId = snaptradeUserIdFor(uid);
  const res = await snaptrade().authentication.registerSnapTradeUser({ userId });
  const userSecret = res.data.userSecret;
  if (!userSecret) throw new Error("SnapTrade did not return a user secret");
  await db.collection("snaptradeUsers").doc(uid).set({
    snaptradeUserId: res.data.userId ?? userId,
    userSecret,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { userId: res.data.userId ?? userId, userSecret };
}
