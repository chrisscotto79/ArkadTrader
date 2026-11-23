# Brokerage linking on the free plan (Cloudflare Worker)

This turns on **Settings → Linked brokerages** (Robinhood, Coinbase and the other brokerages SnapTrade supports) while Firebase stays on the free Spark plan.

## Why a Worker

SnapTrade signs every request with a secret consumer key. Anyone who has that key can act as your whole SnapTrade account, so it can't be shipped inside the app. Something on a server has to hold it, and Firebase only runs server code (Cloud Functions) on the paid Blaze plan. Instead, the small server in `brokerage-worker/` runs on Cloudflare Workers' free plan.

```
iPhone app ──(Firebase ID token)──▶ Worker ──(signed)──▶ SnapTrade ──▶ Robinhood / Coinbase / …
                                       │
                                       └──(service account)──▶ Firestore (holdings, Verified trades)
```

- The Worker checks the user's Firebase ID token on every request, so only signed-in users can use it, and only for their own account.
- It writes to Firestore with a Google service account. Service accounts bypass the security rules, which is what lets it write `users/{uid}/brokerageConnections`, `users/{uid}/brokerageHoldings`, `snaptradeUsers/{uid}` and Verified trades. The rules still stop the app from writing any of those itself.
- Connections are always requested read-only (`connectionType: "read"`). Arkad can't place trades or move money.
- The data shapes are the same as the Cloud Functions in `functions/src/snaptrade/` (docs/backend-contracts.md, section 5), so nothing else in the app changes.

## What it costs

- **Cloudflare Workers, free plan:** $0, no card. 100,000 requests a day, 10 ms of CPU time and 50 outbound requests per request. A sync makes about 10 outbound requests plus 2 per brokerage account, so it fits comfortably. A user with thousands of trades could hit the CPU limit on their first sync; if that ever happens, the Workers Paid plan ($5 a month) lifts it.
- **Firebase:** stays on Spark. The Worker's reads and writes count toward the free Firestore quota (50,000 reads and 20,000 writes a day).
- **SnapTrade:** check their pricing page. Their free tier limits the number of connected users.

## Setup

You need about 20 minutes. Steps 1 to 3 create accounts and keys, so you do them yourself.

### 1. SnapTrade

1. Sign up at https://snaptrade.com and open the dashboard.
2. Create API keys. You get a **Client ID** and a **Consumer Key**. Keep the dashboard tab open for step 4.
3. Check which brokerages are enabled for your keys. Some brokerages need SnapTrade's production approval before real users can connect.

### 2. A service account for Firestore

1. Open https://console.cloud.google.com/iam-admin/serviceaccounts and pick the project **arkad-ios-app**.
2. **Create service account.** Name: `arkad-brokerage-worker`.
3. Grant it one role: **Cloud Datastore User** (read and write Firestore, nothing else).
4. Open the new account → **Keys** → **Add key** → **Create new key** → **JSON**. A `.json` file downloads.

That file is a password for your database. Don't commit it, email it or paste it into chats. You'll load it into Cloudflare in step 4 and can delete the download afterwards.

### 3. Cloudflare

1. Sign up for free at https://dash.cloudflare.com/sign-up.
2. In Terminal:

```bash
cd ~/Arkad-IOS/ArkadTrader/brokerage-worker && npm install
```

```bash
npx wrangler login
```

`wrangler login` opens your browser to approve access to your Cloudflare account.

### 4. Deploy and add the secrets

```bash
npx wrangler deploy
```

It prints the Worker's address, like `https://arkad-brokerage.<your-subdomain>.workers.dev`. Then store the three secrets. Each command asks you to paste the value, so it never ends up in a file or your shell history:

```bash
npx wrangler secret put SNAPTRADE_CLIENT_ID
```

```bash
npx wrangler secret put SNAPTRADE_CONSUMER_KEY
```

The service account goes in as the whole file (use the real path of the file you downloaded):

```bash
npx wrangler secret put FIREBASE_SERVICE_ACCOUNT < ~/Downloads/arkad-ios-app-xxxxxxxx.json
```

Check it's running: opening the Worker's address in a browser shows `{"service":"arkad-brokerage","ok":true}`.

### 5. Turn it on in the app

Add the Worker's address to `App/Secrets.plist` (kept out of git), next to the Finnhub key:

```xml
<key>BrokerageWorkerURL</key>
<string>https://arkad-brokerage.your-subdomain.workers.dev</string>
```

Rebuild the app. **Settings → Linked brokerages** and the Portfolio holdings section appear as soon as the address is set; without it they stay hidden.

Once a linked brokerage has synced, the Portfolio's **Account value** is that brokerage's total (positions plus cash), not the manual starting balance. Each sync stores the totals on `users/{uid}/brokerageConnections/{id}` as `cashBalance`, `holdingsValue`, `totalValue` and `initialSyncPending` (true while SnapTrade is still pulling a new connection's data).

The Portfolio chart reads `valueHistory` on the same doc: one `{ date: "YYYY-MM-DD", value }` per day, oldest first, capped at 730 days. Each sync writes today's total. If SnapTrade's **balance history** add-on is turned on (SnapTrade dashboard → Add-ons), the Worker also backfills up to a year of estimated daily values on the first syncs; without it the chart starts on the day the brokerage was linked.

### 6. Try it

Settings → **Linked brokerages** → **Connect a brokerage** → pick Robinhood (or another) → sign in on SnapTrade's page. You come back to Arkad, it syncs, and your holdings show in Portfolio with buys and sells from the last 90 days as Verified trades.

## Day to day

- Logs: `npx wrangler tail` in `brokerage-worker/` streams the Worker's logs live. Failures are logged with SnapTrade's or Google's response; secrets never are.
- Update the code: edit `brokerage-worker/src/`, run `npm run typecheck`, then `npx wrangler deploy`.
- Rotate a key: run the same `wrangler secret put` again. For the service account, create a new key, load it, then delete the old key in Google Cloud.
- Import window: `IMPORT_DAYS` in `wrangler.toml` (default 90).
- SnapTrade endpoints: the Worker uses `/accounts/all`, `/accounts/{id}/positions/all`, `/accounts/{id}/balances` and `/accounts/{id}/activities`. The older `/accounts/{id}/holdings` returns **410 Gone** for SnapTrade customers who signed up after May 11, 2026, and `/accounts` is deprecated.

## Moving to Cloud Functions later

If you upgrade to Blaze, the Cloud Functions in `functions/src/snaptrade/` do the same job, but they still call the retired `getUserHoldings` and don't write the account totals. Port the Worker's `sync` (brokerage-worker/src/brokerage.ts) to them first. Deploy them, set `serverFunctionsEnabled`, and point `BrokerageService` back at `CloudFunctions` (see git history). The Firestore data is the same either way, so linked accounts carry over.
