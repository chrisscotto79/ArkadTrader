// A small Firestore REST client, signed in as a Google service account. Service accounts
// bypass security rules, which is what lets this Worker write the server-only brokerage
// collections and Verified trades that the app itself can't.

import { importPKCS8, SignJWT } from "jose";
import { UpstreamError } from "./errors";

interface ServiceAccount {
  client_email: string;
  private_key: string;
}

let cachedToken: { token: string; expiresAt: number; email: string } | undefined;

async function accessToken(serviceAccountJson: string): Promise<string> {
  let account: ServiceAccount;
  try {
    account = JSON.parse(serviceAccountJson) as ServiceAccount;
  } catch {
    throw new Error("FIREBASE_SERVICE_ACCOUNT is not valid JSON");
  }
  if (!account.client_email || !account.private_key) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT is missing client_email or private_key");
  }
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.email === account.client_email && cachedToken.expiresAt - 120 > now) {
    return cachedToken.token;
  }

  const key = await importPKCS8(account.private_key, "RS256");
  const assertion = await new SignJWT({ scope: "https://www.googleapis.com/auth/datastore" })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(account.client_email)
    .setSubject(account.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  if (!res.ok) throw new UpstreamError("Google OAuth", res.status, await res.text());
  const data = (await res.json()) as { access_token: string; expires_in: number };
  cachedToken = { token: data.access_token, expiresAt: now + data.expires_in, email: account.client_email };
  return data.access_token;
}

// MARK: - Values

type Value =
  | { nullValue: null }
  | { booleanValue: boolean }
  | { integerValue: string }
  | { doubleValue: number }
  | { timestampValue: string }
  | { stringValue: string }
  | { arrayValue: { values?: Value[] } }
  | { mapValue: { fields?: Record<string, Value> } };

export type Data = Record<string, unknown>;

function encode(value: unknown): Value {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    // Same choice as the Admin SDK: whole numbers are integers.
    return Number.isSafeInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (typeof value === "string") return { stringValue: value };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  if (typeof value === "object") return { mapValue: { fields: encodeFields(value as Data) } };
  throw new Error(`Can't store a ${typeof value} in Firestore`);
}

function encodeFields(data: Data): Record<string, Value> {
  const fields: Record<string, Value> = {};
  for (const [key, value] of Object.entries(data)) if (value !== undefined) fields[key] = encode(value);
  return fields;
}

function decode(value: Record<string, unknown>): unknown {
  if ("nullValue" in value) return null;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("timestampValue" in value) return new Date(String(value.timestampValue));
  if ("stringValue" in value) return value.stringValue;
  if ("arrayValue" in value) {
    const values = (value.arrayValue as { values?: Record<string, unknown>[] }).values ?? [];
    return values.map(decode);
  }
  if ("mapValue" in value) return decodeFields((value.mapValue as { fields?: Record<string, Record<string, unknown>> }).fields);
  // referenceValue, geoPointValue, bytesValue: kept as they are, so a rewrite doesn't lose them
  return value;
}

function decodeFields(fields: Record<string, Record<string, unknown>> | undefined): Data {
  const data: Data = {};
  for (const [key, value] of Object.entries(fields ?? {})) data[key] = decode(value);
  return data;
}

// MARK: - Client

export interface Doc {
  /** Last path segment */
  id: string;
  /** Path below `documents/`, like `users/abc/brokerageHoldings/x` */
  path: string;
  data: Data;
}

export type Write = { update: { name: string; fields: Record<string, Value> }; updateMask?: { fieldPaths: string[] } } | { delete: string };

const API = "https://firestore.googleapis.com/v1";

export class Firestore {
  private readonly root: string;

  private constructor(
    projectId: string,
    private readonly token: string,
  ) {
    this.root = `projects/${projectId}/databases/(default)/documents`;
  }

  static async connect(projectId: string, serviceAccountJson: string): Promise<Firestore> {
    return new Firestore(projectId, await accessToken(serviceAccountJson));
  }

  private name(path: string): string {
    return path ? `${this.root}/${path}` : this.root;
  }

  private toDoc(raw: { name: string; fields?: Record<string, Record<string, unknown>> }): Doc {
    const path = raw.name.slice(this.root.length + 1);
    return { id: path.slice(path.lastIndexOf("/") + 1), path, data: decodeFields(raw.fields) };
  }

  private async call<T>(method: string, url: string, body?: unknown): Promise<T | null> {
    const res = await fetch(url, {
      method,
      headers: { Authorization: `Bearer ${this.token}`, "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (res.status === 404 && method === "GET") return null;
    if (!res.ok) throw new UpstreamError("Firestore", res.status, await res.text());
    return (await res.json()) as T;
  }

  async get(path: string): Promise<Doc | null> {
    const raw = await this.call<{ name: string; fields?: Record<string, Record<string, unknown>> }>("GET", `${API}/${this.name(path)}`);
    return raw ? this.toDoc(raw) : null;
  }

  /** Every document in a collection (or subcollection) */
  async list(collectionPath: string): Promise<Doc[]> {
    const docs: Doc[] = [];
    let pageToken = "";
    do {
      const params = new URLSearchParams({ pageSize: "300" });
      if (pageToken) params.set("pageToken", pageToken);
      const page = await this.call<{ documents?: { name: string; fields?: Record<string, Record<string, unknown>> }[]; nextPageToken?: string }>(
        "GET",
        `${API}/${this.name(collectionPath)}?${params}`,
      );
      for (const raw of page?.documents ?? []) docs.push(this.toDoc(raw));
      pageToken = page?.nextPageToken ?? "";
    } while (pageToken);
    return docs;
  }

  /** Documents in `parentPath/collectionId` whose fields equal every value in `equals` */
  async where(parentPath: string, collectionId: string, equals: Data): Promise<Doc[]> {
    const filters = Object.entries(equals).map(([field, value]) => ({
      fieldFilter: { field: { fieldPath: field }, op: "EQUAL", value: encode(value) },
    }));
    const where = filters.length === 1 ? filters[0] : { compositeFilter: { op: "AND", filters } };
    const rows = await this.call<{ document?: { name: string; fields?: Record<string, Record<string, unknown>> } }[]>(
      "POST",
      `${API}/${this.name(parentPath)}:runQuery`,
      { structuredQuery: { from: [{ collectionId }], where } },
    );
    return (rows ?? []).flatMap((row) => (row.document ? [this.toDoc(row.document)] : []));
  }

  /** Which of these paths exist */
  async existing(paths: string[]): Promise<Set<string>> {
    const found = new Set<string>();
    for (let i = 0; i < paths.length; i += 300) {
      const rows = await this.call<{ found?: { name: string } }[]>("POST", `${API}/${this.root}:batchGet`, {
        documents: paths.slice(i, i + 300).map((p) => this.name(p)),
      });
      for (const row of rows ?? []) if (row.found) found.add(row.found.name.slice(this.root.length + 1));
    }
    return found;
  }

  /** Replaces the document, or with `mergeFields` updates only those fields */
  set(path: string, data: Data, mergeFields?: string[]): Write {
    const update = { name: this.name(path), fields: encodeFields(data) };
    return mergeFields ? { update, updateMask: { fieldPaths: mergeFields } } : { update };
  }

  delete(path: string): Write {
    return { delete: this.name(path) };
  }

  /** Applies writes in atomic groups of up to 500 */
  async commit(writes: Write[]): Promise<void> {
    for (let i = 0; i < writes.length; i += 500) {
      await this.call("POST", `${API}/${this.root}:commit`, { writes: writes.slice(i, i + 500) });
    }
  }
}
