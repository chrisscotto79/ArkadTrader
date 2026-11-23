// Sends an APNs push (through FCM) whenever a notification document is created.

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import type { MulticastMessage } from "firebase-admin/messaging";
import { db, messaging, chunk } from "../lib/firebase.js";
import { PREF_KEY, NotificationType } from "../lib/notify.js";
import { REGION } from "../config.js";

/** Tokens that will never work again; anything else (quota, unavailable) is kept. */
const DEAD_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

export const onNotificationCreated = onDocumentCreated(
  { document: "notifications/{notificationId}", region: REGION, retry: false },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const n = snap.data();
    const userId: string | undefined = n.userId;
    const type = n.type as NotificationType;
    if (!userId || !type) return;

    const userRef = db.collection("users").doc(userId);
    const [userSnap, tokensSnap] = await Promise.all([userRef.get(), userRef.collection("fcmTokens").get()]);
    if (!userSnap.exists || tokensSnap.empty) return;

    // Preferences default to on; only an explicit false turns a type off.
    const prefs = (userSnap.get("notificationPrefs") ?? {}) as Record<string, unknown>;
    const prefKey = PREF_KEY[type];
    if (prefKey && prefs[prefKey] === false) {
      logger.debug("Push skipped by preference", { userId, type });
      return;
    }

    const tokens = tokensSnap.docs.map((d) => (d.get("token") as string) || d.id).filter(Boolean);
    if (tokens.length === 0) return;

    // Badge = unread notifications (capped read cost: one aggregation query).
    let badge = 1;
    try {
      const unread = await db
        .collection("notifications")
        .where("userId", "==", userId)
        .where("isRead", "==", false)
        .count()
        .get();
      badge = Math.max(1, unread.data().count);
    } catch (error) {
      logger.warn("Unread count failed", { error: String(error) });
    }

    // FCM data values must be strings.
    const data: Record<string, string> = { type, notificationId: snap.id };
    for (const [key, value] of Object.entries((n.data ?? {}) as Record<string, unknown>)) {
      if (value !== undefined && value !== null) data[key] = String(value);
    }

    const dead: string[] = [];
    for (const group of chunk(tokens, 500)) {
      const message: MulticastMessage = {
        tokens: group,
        notification: { title: String(n.title ?? "Arkad"), body: String(n.body ?? "") },
        data,
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge,
              threadId: data.communityId ?? type,
            },
          },
        },
      };
      const res = await messaging().sendEachForMulticast(message);
      res.responses.forEach((r, i) => {
        if (!r.success && r.error && DEAD_TOKEN_CODES.has(r.error.code)) dead.push(group[i]);
      });
      logger.info("Push sent", { userId, type, success: res.successCount, failure: res.failureCount });
    }

    if (dead.length > 0) {
      const batch = db.batch();
      for (const doc of tokensSnap.docs) {
        const token = (doc.get("token") as string) || doc.id;
        if (dead.includes(token)) batch.delete(doc.ref);
      }
      await batch.commit();
      logger.info("Removed dead FCM tokens", { userId, count: dead.length });
    }
  },
);
