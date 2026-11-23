// traderStats/{uid} and communities/{cid}/traderStats/{uid}, recomputed from the
// callout ledger whenever a row is created, closed or excluded. Recomputing from
// all of a trader's rows is cheap at this scale and can never drift.

import { onDocumentWritten, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { getAuth } from "firebase-admin/auth";
import { db, Timestamp, FieldValue } from "../lib/firebase.js";
import { REGION } from "../config.js";

interface Row {
  communityId: string;
  status: string;
  resultPercent?: number | null;
  postedAt?: Timestamp;
  excluded?: boolean;
}

function summarize(rows: Row[]) {
  const counted = rows.filter((r) => !r.excluded);
  const closed = counted.filter((r) => r.status !== "open" && typeof r.resultPercent === "number");
  const results = closed.map((r) => r.resultPercent as number);
  const wins = results.filter((r) => r > 0).length;
  const total = results.reduce((a, b) => a + b, 0);
  const round = (v: number) => Math.round(v * 100) / 100;
  let last: Timestamp | null = null;
  for (const r of counted) {
    if (r.postedAt instanceof Timestamp && (!last || r.postedAt.toMillis() > last.toMillis())) last = r.postedAt;
  }
  return {
    calloutsTotal: counted.length,
    calloutsClosed: closed.length,
    openCallouts: counted.filter((r) => r.status === "open").length,
    wins,
    losses: closed.length - wins,
    winRate: closed.length > 0 ? Math.round((wins / closed.length) * 10000) / 10000 : 0,
    avgReturnPercent: closed.length > 0 ? round(total / closed.length) : 0,
    totalReturnPercent: round(total),
    bestCalloutPercent: results.length > 0 ? round(Math.max(...results)) : 0,
    worstCalloutPercent: results.length > 0 ? round(Math.min(...results)) : 0,
    lastCalloutAt: last,
  };
}

async function accountExists(uid: string): Promise<boolean> {
  try {
    await getAuth().getUser(uid);
    return true;
  } catch (error) {
    if ((error as { code?: string }).code === "auth/user-not-found") return false;
    throw error;
  }
}

export async function recomputeTraderStats(uid: string, communityIds: Iterable<string>): Promise<void> {
  // A deleted account's cleanup touches its ledger rows; don't bring its stats back.
  if (!(await accountExists(uid))) return;
  const [ledger, user] = await Promise.all([
    db.collection("calloutLedger").where("authorId", "==", uid).get(),
    db.collection("users").doc(uid).get(),
  ]);
  const rows = ledger.docs.map((d) => d.data() as Row);
  const identity = {
    userId: uid,
    username: (user.get("username") as string) ?? "",
    profileImageUrl: (user.get("profileImageUrl") as string) ?? null,
    updatedAt: FieldValue.serverTimestamp(),
  };

  const batch = db.batch();
  batch.set(db.collection("traderStats").doc(uid), { ...summarize(rows), ...identity });
  for (const cid of new Set(communityIds)) {
    const ref = db.collection("communities").doc(cid).collection("traderStats").doc(uid);
    const inCommunity = rows.filter((r) => r.communityId === cid);
    if (inCommunity.length === 0) batch.delete(ref);
    else batch.set(ref, { ...summarize(inCommunity), ...identity });
  }
  await batch.commit();
}

export const onCalloutLedgerWritten = onDocumentWritten(
  { document: "calloutLedger/{id}", region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return; // ledger rows are only deleted by account cleanup
    const row = after;
    if (!row.authorId) return;
    if (
      before &&
      after &&
      before.status === after.status &&
      before.excluded === after.excluded &&
      before.resultPercent === after.resultPercent
    ) {
      return; // nothing that affects the record changed
    }
    const communities = new Set<string>();
    if (before?.communityId) communities.add(before.communityId);
    if (after?.communityId) communities.add(after.communityId);
    // Skip communities that no longer exist (their traderStats were deleted with them).
    const existing: string[] = [];
    for (const cid of communities) {
      if ((await db.collection("communities").doc(cid).get()).exists) existing.push(cid);
    }
    await recomputeTraderStats(row.authorId, existing);
  },
);

/** Keep the denormalized username / avatar on stats docs current. */
export const onUserProfileUpdated = onDocumentUpdated(
  { document: "users/{uid}", region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.username === after.username && before.profileImageUrl === after.profileImageUrl) return;

    const uid = event.params.uid;
    const global = db.collection("traderStats").doc(uid);
    if (!(await global.get()).exists) return;
    const patch = { username: after.username ?? "", profileImageUrl: after.profileImageUrl ?? null };
    const batch = db.batch();
    batch.update(global, patch);
    const perCommunity = await db.collectionGroup("traderStats").where("userId", "==", uid).get();
    for (const doc of perCommunity.docs) if (doc.ref.path !== global.path) batch.update(doc.ref, patch);
    await batch.commit();
  },
);
