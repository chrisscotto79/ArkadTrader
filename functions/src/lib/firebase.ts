import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp, BulkWriter, Firestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";

if (getApps().length === 0) {
  initializeApp();
}

export const db: Firestore = getFirestore();
export const messaging = () => getMessaging();
export const storage = () => getStorage();
export { FieldValue, Timestamp };

/** gRPC status codes that mean "nothing to do" for idempotent writes. */
const ALREADY_EXISTS = 6;
const NOT_FOUND = 5;
const FAILED_PRECONDITION = 9;

/**
 * A BulkWriter that retries transient failures and quietly skips writes that
 * fail because the document already exists (create), is already gone (update),
 * or changed since it was read (update with a lastUpdateTime precondition).
 * That makes fan-outs and cleanups safe to re-run when a trigger is retried.
 */
export function tolerantBulkWriter(): BulkWriter {
  const writer = db.bulkWriter();
  writer.onWriteError((error) => {
    if (error.code === ALREADY_EXISTS || error.code === NOT_FOUND || error.code === FAILED_PRECONDITION) return false;
    return error.failedAttempts < 5;
  });
  return writer;
}

/** Read a Firestore number that might be stored as an integer or a double. */
export function num(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return undefined;
}

export function str(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

export function toDate(value: unknown): Date | undefined {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return undefined;
}

export function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Round to cents (or more decimals for sub-dollar prices) so stored numbers stay tidy. */
export function roundPrice(price: number): number {
  const digits = Math.abs(price) < 1 ? 6 : 4;
  const f = 10 ** digits;
  return Math.round(price * f) / f;
}

export function round2(value: number): number {
  return Math.round(value * 100) / 100;
}
