// Arkad brokerage Worker: read-only brokerage linking through SnapTrade, without Cloud Functions.
// Setup: docs/brokerage-worker-setup.md. API: docs/backend-contracts.md, section 5.
//
//   POST /connect       {}                 -> { url }       SnapTrade's read-only portal
//   POST /sync          {}                 -> { importedTrades, holdings }
//   POST /disconnect    { connectionId }   -> { ok }
//   POST /delete-user   {}                 -> { ok }        account deletion cleanup
//   GET  /open/brokerage/connected                         return page -> arkad://brokerage/connected
//
// Every POST needs `Authorization: Bearer <Firebase ID token>`. Errors are
// `{ error: { message } }` with an HTTP status; the message is safe to show.

import { verifyIdToken } from "./auth";
import { connect, deleteUser, disconnect, sync, type Context } from "./brokerage";
import { ApiError, UpstreamError } from "./errors";
import { Firestore } from "./firestore";
import { SnapTrade } from "./snaptrade";

export interface Env {
  SNAPTRADE_CLIENT_ID: string;
  SNAPTRADE_CONSUMER_KEY: string;
  FIREBASE_SERVICE_ACCOUNT: string;
  FIREBASE_PROJECT_ID: string;
  IMPORT_DAYS?: string;
}

const RETURN_PATH = "/open/brokerage/connected";

type Handler = (ctx: Context, body: Record<string, unknown>, origin: string) => Promise<unknown>;

const routes: Record<string, { handler: Handler; failure: string }> = {
  "/connect": { handler: (ctx, _body, origin) => connect(ctx, origin + RETURN_PATH), failure: "Couldn't open brokerage linking. Try again." },
  "/sync": { handler: (ctx) => sync(ctx), failure: "Couldn't sync your brokerage. Try again." },
  "/disconnect": { handler: (ctx, body) => disconnect(ctx, body.connectionId), failure: "Couldn't disconnect the brokerage. Try again." },
  "/delete-user": { handler: (ctx) => deleteUser(ctx), failure: "Couldn't remove your linked brokerages." },
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === RETURN_PATH) return returnPage(url.search);
    if (request.method === "GET" && url.pathname === "/") return json(200, { service: "arkad-brokerage", ok: true });

    const route = routes[url.pathname];
    if (!route) return json(404, { error: { message: "Not found." } });
    if (request.method !== "POST") return json(405, { error: { message: "Use POST." } });

    try {
      const uid = await verifyIdToken(request.headers.get("Authorization"), env.FIREBASE_PROJECT_ID);
      const body = await readBody(request);
      const ctx: Context = {
        uid,
        db: await Firestore.connect(env.FIREBASE_PROJECT_ID, env.FIREBASE_SERVICE_ACCOUNT),
        snaptrade: new SnapTrade(env.SNAPTRADE_CLIENT_ID, env.SNAPTRADE_CONSUMER_KEY),
        importDays: Math.min(Math.max(Number(env.IMPORT_DAYS) || 90, 1), 365),
      };
      return json(200, await route.handler(ctx, body, url.origin));
    } catch (error) {
      if (error instanceof ApiError) return json(error.status, { error: { message: error.message } });
      const detail = error instanceof UpstreamError ? { service: error.service, status: error.status, body: error.body } : { error: String(error) };
      console.error(JSON.stringify({ event: "failed", path: url.pathname, ...detail }));
      return json(500, { error: { message: route.failure } });
    }
  },
} satisfies ExportedHandler<Env>;

async function readBody(request: Request): Promise<Record<string, unknown>> {
  const text = await request.text();
  if (!text) return {};
  try {
    const value = JSON.parse(text);
    return value && typeof value === "object" && !Array.isArray(value) ? value : {};
  } catch {
    throw new ApiError(400, "Invalid request.");
  }
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

/**
 * SnapTrade sends the user here when they finish. The page forwards to arkad://brokerage/connected,
 * which closes the in-app browser (ASWebAuthenticationSession, callbackURLScheme "arkad").
 * It only ever forwards to that one path, so it can't be used as an open redirect.
 */
function returnPage(search: string): Response {
  const query = new URLSearchParams(search);
  const safe = new URLSearchParams();
  for (const key of ["status", "connection_id", "authorizationId"]) {
    const value = query.get(key);
    if (value && /^[\w-]{1,128}$/.test(value)) safe.set(key, value);
  }
  const qs = safe.toString();
  const target = "arkad://brokerage/connected" + (qs ? `?${qs}` : "");
  const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>Arkad</title>
<style>body{font:17px -apple-system,system-ui,sans-serif;margin:0;padding:48px 24px;text-align:center;color:#1c1c1e;background:#f5f5f2}
a{display:inline-block;margin-top:16px;padding:14px 28px;border-radius:999px;background:#f2c14e;color:#1c1c1e;text-decoration:none;font-weight:600}</style>
</head><body><h1>Returning to Arkad…</h1><p>If the app doesn't open by itself, tap the button.</p>
<a href="${target}">Open Arkad</a>
<script>location.replace(${JSON.stringify(target)});</script></body></html>`;
  return new Response(html, {
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store", "Referrer-Policy": "no-referrer" },
  });
}
