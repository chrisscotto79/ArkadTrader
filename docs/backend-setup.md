# Arkad backend setup

This guide takes you from an empty Firebase project to a working backend: Cloud Functions, Firestore and Storage rules, Firestore indexes, push notifications, Stripe Connect, SnapTrade and the hosted legal pages.

Everything lives at the repo root:

| Path | What it is |
|---|---|
| `functions/` | Cloud Functions (TypeScript, Node 22) |
| `firestore.rules`, `firestore.indexes.json` | Firestore security rules and indexes |
| `storage.rules` | Cloud Storage security rules |
| `hosting/` | `arkad-ios-app.web.app`: landing page, `/terms`, `/privacy`, and the `/open/...` return page |
| `firebase.json`, `.firebaserc` | Firebase CLI config. The project is `arkad-ios-app`. |

The data contract both the app and the functions follow is `docs/backend-contracts.md`.

---

## 0. Right now: the free plan (no Blaze, no Stripe, no SnapTrade)

Arkad currently runs entirely on Firebase's free Spark plan. The switches in `Shared/Config/AppConfig.swift` (`serverFunctionsEnabled`, `paidCommunitiesEnabled`, `brokerageLinkingEnabled`, `mediaUploadsEnabled`) are all `false`, so the app does the server's work itself (see section 0 of `docs/backend-contracts.md`). Sections 2 onward of this guide are for later.

The only setup step is publishing the free-mode security rules and indexes. Without it, the new features (inbox, track records, photos, price checks, report counting) get "permission denied" or "needs an index".

```bash
npm install -g firebase-tools
firebase login
firebase deploy --only firestore,hosting
```

That publishes `firestore.rules`, `firestore.indexes.json` and the legal pages. All three are free. Don't deploy `functions` or `storage` on the free plan; both need Blaze.

No terminal? In the Firebase console, open Firestore Database → Rules, paste the contents of `firestore.rules`, and click Publish. Indexes can be created from the link in the app's error message the first time each query runs.

What's different in free mode:
- Checks such as price-checked trades, the 2% callout check and track-record stats run in the app, and the rules double-check what they can. That stops casual faking, but a determined person with a modified app could still write their own stats. The server version (functions plus `firestore.server.rules`) closes that gap.
- Price alerts only fire while Arkad is open. There's no remote push.
- Photos are small JPEGs stored in Firestore (`images/`), not Cloud Storage. Photos attached to posts and chat are off.

When you move to Blaze later: deploy the functions (section 8), copy `firestore.server.rules` over `firestore.rules`, and set the switches in `AppConfig.swift` to `true`.

---

## 1. Tools and login

1. Install Node.js 22 (the Cloud Functions runtime) from https://nodejs.org or with a version manager such as `nvm install 22`.
2. Install the Firebase CLI: `npm install -g firebase-tools`
3. Log in: `firebase login`
4. From the repo root, check that the CLI sees the project: `firebase projects:list`. `arkad-ios-app` should be listed. `.firebaserc` already selects it.
5. Install the function dependencies and build once:
   ```sh
   cd functions
   npm install
   npm run build
   cd ..
   ```

## 2. Upgrade to the Blaze plan

Scheduled functions (the callout tracker and price alerts), outbound network calls (Finnhub, Stripe, SnapTrade), and Secret Manager all need the pay-as-you-go **Blaze** plan.

Firebase console → ⚙ → **Usage and billing** → **Details & settings** → **Modify plan** → Blaze. Then set a budget alert under Google Cloud console → **Billing** → **Budgets & alerts**, for example at $10 a month, so you hear about surprises early.

## 3. Turn on the Firebase products

In the Firebase console for `arkad-ios-app`:

- **Authentication**: already in use by the app.
- **Firestore**: already in use.
- **Storage**: already in use. The first `firebase deploy --only storage` asks to let Storage rules read Firestore, because `community_images` checks the community's owner. Answer yes.
- **Cloud Messaging**: see section 7.
- **Hosting**: click **Get started** once if Hosting has never been used.

## 4. Secrets

The functions read five secrets from Google Secret Manager. Set each one from the repo root; the CLI prompts for the value, so it never ends up in your shell history:

```sh
firebase functions:secrets:set FINNHUB_API_KEY
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
firebase functions:secrets:set SNAPTRADE_CLIENT_ID
firebase functions:secrets:set SNAPTRADE_CONSUMER_KEY
```

| Secret | Where to get it |
|---|---|
| `FINNHUB_API_KEY` | https://finnhub.io/dashboard, after you sign up. The free key works. You can use the same key as the app's `Secrets.plist`, but a separate key gives the server its own rate limit. |
| `STRIPE_SECRET_KEY` | Stripe Dashboard → Developers → API keys → **Secret key**. Use `sk_test_…` first. |
| `STRIPE_WEBHOOK_SECRET` | The signing secret of the webhook endpoint (section 5.4). If you create two endpoints, store both secrets separated by a comma: `whsec_aaa,whsec_bbb`. |
| `SNAPTRADE_CLIENT_ID`, `SNAPTRADE_CONSUMER_KEY` | SnapTrade dashboard (section 6). |

To change a secret later, run `secrets:set` again and redeploy the functions that use it (`firebase deploy --only functions`). `firebase functions:secrets:access NAME` shows the current value.

## 5. Stripe Connect (paid communities)

Arkad uses **Connect with Express accounts and destination charges**. A subscriber pays Arkad's platform account, Stripe takes its processing fee, and the community owner's Express account receives the payment minus Arkad's 10% application fee (`PLATFORM_FEE_PERCENT` in `functions/src/config.ts`).

> With destination charges, Stripe's processing fee is charged to the **platform** (Arkad), out of its 10%. Check Stripe's current pricing before you set prices so the 10% covers it.

### 5.1 Create the account and turn on Connect

1. Create an account at https://dashboard.stripe.com/register and verify your email.
2. Leave **Test mode** on (toggle at the top of the Dashboard) for everything below until you're ready to launch.
3. Go to **Connect** → **Get started**. Choose **Platform or marketplace**, and choose **Express** accounts when asked. Fill in the platform profile: business name "Arkad", and what owners sell, for example "monthly subscriptions to trading communities".
4. Under **Connect → Settings → Branding**, add Arkad's name, icon and colors. The onboarding and dashboard pages owners see use them.

### 5.2 Keys

Developers → **API keys**. Copy the **Secret key** (`sk_test_…`) into `STRIPE_SECRET_KEY`. The app never needs a Stripe key, because every Stripe call goes through the functions.

### 5.3 Customer portal

Settings → **Billing** → **Customer portal**. Turn on "Cancel subscriptions" (at the end of the billing period), "Update payment methods" and "Invoice history", then click **Save**. `createBillingPortalSession` fails until the portal is saved once, in test mode and again in live mode.

### 5.4 Webhook endpoints

Deploy the functions first (section 8) so the URL exists:

```
https://us-central1-arkad-ios-app.cloudfunctions.net/stripeWebhook
```

(`firebase deploy --only functions:stripeWebhook` prints the exact URL.)

Developers → **Webhooks** (also called Event destinations) → **Add endpoint**:

1. **Endpoint for your account** (platform events):
   - URL: the URL above
   - API version: the version the functions' Stripe SDK pins. Check `ApiVersion` in `functions/node_modules/stripe/cjs/apiVersion.js`; the SDK in this repo pins `2026-11-18.endive`.
   - Events: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.paid`
2. **Endpoint for connected accounts** (Connect events). It can use the same URL:
   - Events: `account.updated`

Each endpoint has its own **Signing secret** (`whsec_…`). Store them both, comma-separated, in `STRIPE_WEBHOOK_SECRET`, then redeploy `stripeWebhook`. If your Dashboard lets one endpoint receive both kinds of events, one secret is enough.

### 5.5 Return URLs

Stripe only accepts https return URLs, so every Stripe flow returns to a page on Firebase Hosting, which forwards to the app:

| Stripe returns to | The page opens |
|---|---|
| `https://arkad-ios-app.web.app/open/payouts/done` | `arkad://payouts/done` |
| `https://arkad-ios-app.web.app/open/checkout/success?communityId=…` | `arkad://checkout/success?communityId=…` |
| `https://arkad-ios-app.web.app/open/checkout/cancel` | `arkad://checkout/cancel` |
| `https://arkad-ios-app.web.app/open/billing/done` | `arkad://billing/done` |
| `https://arkad-ios-app.web.app/open/brokerage/connected` | `arkad://brokerage/connected` (SnapTrade) |

The page is `hosting/open/index.html`. It only forwards those paths. `ASWebAuthenticationSession` with `callbackURLScheme: "arkad"` closes when the page opens the `arkad://` URL. Deploy Hosting (section 8) before testing any web flow.

### 5.6 Going live

When test mode works end to end:

1. Activate the account (Stripe asks for business and bank details).
2. Switch the Dashboard to live mode and redo 5.2 to 5.4 with live keys, the live portal and live webhook endpoints. Live mode has separate keys, endpoints and Connect settings.
3. `firebase functions:secrets:set STRIPE_SECRET_KEY` (the `sk_live_…` key) and `STRIPE_WEBHOOK_SECRET` (the live signing secrets), then `firebase deploy --only functions`.
4. Communities priced in test mode have test Product and Price ids. Owners must save their price again in the app (`setCommunityPrice`) to create live ones, after finishing live payout onboarding.

## 6. SnapTrade (brokerage linking, read-only)

1. Sign up at https://snaptrade.com and open the dashboard.
2. Create API keys. You get a **Client ID** and a **Consumer Key**. Store them in `SNAPTRADE_CLIENT_ID` and `SNAPTRADE_CONSUMER_KEY`.
3. SnapTrade's free tier limits the number of connected users; check their pricing page before launch.
4. The functions always ask for **read-only** connections (`connectionType: "read"`). No trading permissions are requested.
5. Each Arkad user is registered with SnapTrade as `arkad-<firebase uid>`. Their SnapTrade user secret is stored in `snaptradeUsers/{uid}`, which the rules keep server-only.

## 7. Push notifications (APNs → FCM)

1. Apple Developer portal → **Certificates, Identifiers & Profiles** → **Keys** → **+**.
2. Name it "Arkad APNs", tick **Apple Push Notifications service (APNs)**, then **Continue** → **Register**.
3. **Download** the `.p8` file. You can only download it once, so keep it somewhere safe. Note the **Key ID**, and your **Team ID** (top right of the portal, or Membership details).
4. Firebase console → ⚙ **Project settings** → **Cloud Messaging** → **Apple app configuration** → your iOS app → **APNs Authentication Key** → **Upload**. Choose the `.p8`, then enter the Key ID and Team ID.
5. In Xcode, the app target needs the **Push Notifications** capability and **Background Modes → Remote notifications**. The iOS work handles this.

One key works for both development (sandbox) and production builds.

## 8. Deploy

From the repo root:

```sh
# Everything
firebase deploy

# Or one piece at a time
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
firebase deploy --only hosting
firebase deploy --only functions
firebase deploy --only functions:stripeWebhook     # a single function
```

Notes:
- The first functions deploy enables a few Google Cloud APIs (Cloud Functions, Cloud Build, Artifact Registry, Eventarc, Cloud Scheduler, Secret Manager). Accept the prompts. If it fails right after enabling APIs, wait a minute and run it again.
- New indexes take a few minutes to build. Queries that need them fail with "The query requires an index" until they finish. Check progress in the Firestore console → **Indexes**.
- `firebase deploy --only firestore:indexes` asks whether to delete indexes in the console that aren't in `firestore.indexes.json`. Answer **No** the first time, then add any you still need to the file.
- Deploy the rules together with (or after) the app update that uses the new paths. The rules deny writes the old app makes; see "Rules and the app" below.

### Deploy order for a first launch

1. `firebase deploy --only firestore:indexes` (indexes take longest to build)
2. Set all five secrets (section 4)
3. `firebase deploy --only functions`
4. Create the Stripe webhook endpoints with the printed `stripeWebhook` URL, set `STRIPE_WEBHOOK_SECRET`, then `firebase deploy --only functions:stripeWebhook`
5. `firebase deploy --only hosting`
6. `firebase deploy --only firestore:rules,storage`
7. Check `https://arkad-ios-app.web.app/terms` and `https://arkad-ios-app.web.app/privacy`

## 9. What each function does

| Function | Trigger | Job |
|---|---|---|
| `onNotificationCreated` | `notifications/{id}` created | Push through FCM, honoring `notificationPrefs`. Removes dead tokens. |
| `onPostCreated` | `posts/{id}` created | `mention` notifications |
| `onCommentCreated` | `posts/{id}/comments/{id}` created | `reply` to the post author, plus `mention` |
| `onPostLiked` | `posts/{id}/likes/{uid}` created | `like` to the post author |
| `onFollowerAdded` | `users/{uid}/followers/{id}` created | `follow` |
| `onMemberJoined` | `communities/{cid}/members/{uid}` created | `member_joined` to the owner (free joins) |
| `onCommunityMessageWritten` | any community message write | New callout: ledger row and `callout` notifications. Callout closed: `callout_result` notifications. Mentions. |
| `onCalloutLedgerWritten` | `calloutLedger/{id}` written | Recomputes `traderStats/{uid}` and `communities/{cid}/traderStats/{uid}` |
| `onUserProfileUpdated` | `users/{uid}` updated | Keeps username and avatar current on stats docs |
| `trackOpenCallouts` | every 15 minutes | Prices open callouts, closes them at target or stop, auto-closes after 30 days |
| `checkPriceAlerts` | every 5 minutes | Triggers price alerts while markets are open |
| `onPriceAlertCreated` | alert created | Enforces the 20 active alerts limit |
| `createConnectOnboardingLink`, `getConnectDashboardLink`, `setCommunityPrice`, `createCheckoutSession`, `createBillingPortalSession` | callable | Stripe Connect (contract section 4) |
| `stripeWebhook` | HTTPS | Memberships, `stripeAccounts`, revenue, `subscription` notifications |
| `snaptradeConnectLink`, `snaptradeSync`, `snaptradeDisconnect` | callable | Brokerage linking (contract section 5) |
| `onReportCreated` | `reports/{id}` created | Counts post reports once per reporter and hides a post at 3 |
| `onBanCreated` | `communities/{cid}/bans/{uid}` created | Removes the membership if the app didn't |
| `onMemberRemoved` | member doc deleted | Cancels the member's live Stripe subscription |
| `onCommunityDeleted` | community doc deleted | Cancels subscriptions, clears members' `communityIds`, deletes subcollections |
| `onAccountDeleted` | Auth user deleted (v1 API) | Deletes or anonymizes everything the user owned (contract section 8) |

## 10. Testing in test mode

### Locally with the emulators (optional)

The emulators need Java 11 or later (`brew install --cask temurin`).

```sh
firebase emulators:start
```

The Emulator UI runs at http://localhost:4000. To point the app at the emulators, call `Firestore.firestore().useEmulator(withHost:port:)`, `Auth.auth().useEmulator(...)` and `Functions.functions().useEmulator(...)` in a debug build. Scheduled functions don't run on a schedule in the emulator; trigger them from `firebase functions:shell`, for example `trackOpenCallouts()`.

For the rules, the Firestore emulator shows every allowed or denied request in the UI's **Firestore → Requests** tab. Running through the app's main flows against it is the quickest way to find a rule that's too strict.

### Notifications
1. Sign in on a real device (the simulator can receive pushes on recent Xcode versions, but a device is the reliable test). Allow notifications. Check that `users/{uid}/fcmTokens/{token}` appears.
2. From a second account, follow the first. A `notifications` doc appears and a push arrives.
3. In the first account, turn off "Follows" in Notification Settings and repeat with a third account: the doc is created but no push is sent.
4. Logs: `firebase functions:log --only onNotificationCreated`

### Callout tracking
1. In a community you own, post a callout on a liquid stock during US market hours, with a target just above the current price.
2. Wait for the next run (at :02, :17, :32 and :47 past the hour, New York time), or run it now from Google Cloud console → **Cloud Scheduler** → the `trackOpenCallouts` job → **Force run**.
3. `callout.lastPrice` updates. When the price crosses the target, `callout.status` becomes `target_hit` and `traderStats/{uid}` updates.
4. Close a callout manually in the app. `callout_result` notifications go out and the stats update.

### Paid communities (Stripe test mode)
1. In the app, open Payouts and start onboarding. Stripe's test onboarding accepts test data: phone `000 000 0000`, SMS code `000000`, SSN `000-00-0000`, and routing `110000000` with account `000123456789`. Use "Test" options wherever offered.
2. Back in the app, `stripeAccounts/{uid}.chargesEnabled` should be true (the `account.updated` webhook sets it; check the endpoint's event log in the Stripe Dashboard if it doesn't).
3. Set a monthly price on a community you own. The community doc gets `isPaid`, `priceMonthly`, `stripeProductId` and `stripePriceId`.
4. From another account, subscribe with card `4242 4242 4242 4242`, any future date and any CVC. After the redirect, `communities/{cid}/members/{uid}` has `subscriptionStatus: "active"` (or `trialing`), the owner gets a `subscription` notification, and `communities/{cid}/private/revenue` updates.
5. Open billing and cancel. The owner gets a cancel notification; when the period ends (or when you cancel immediately in the Stripe Dashboard), the membership is removed.
6. To fast-forward renewals and trials, use **Test clocks** in the Stripe Dashboard (Billing → Test clocks).
7. Replay or inspect webhook deliveries in Developers → Webhooks → your endpoint. The Stripe CLI can also forward events to the emulator: `stripe listen --forward-to localhost:5001/arkad-ios-app/us-central1/stripeWebhook`.

### Brokerage (SnapTrade)
1. In the app, open Linked Accounts → connect. Pick a brokerage; SnapTrade's sandbox or a paper-trading account works for testing.
2. After returning to the app, run a sync. `users/{uid}/brokerageConnections` and `brokerageHoldings` fill in, and buys and sells from the last 90 days appear in `trades` with `source: "brokerage"` and `isVerified: true`.
3. Sync again: the count of imported trades is 0 (no duplicates).

### Price alerts
Create an alert just below a crypto's current price (crypto is checked around the clock). Within 5 minutes it turns inactive with `triggeredAt` set and a `price_alert` notification arrives.

### Account deletion
Delete a test account from the app (or from Authentication in the console). Within a minute, check that `users/{uid}` and its subcollections, its posts, trades and `traderStats` are gone, and its chat messages show as deleted.

## 11. Costs

Exact prices change, so check the pricing pages rather than numbers here:

- Firebase: https://firebase.google.com/pricing (Firestore reads, writes and storage; Cloud Functions invocations and compute; Hosting; Storage). Blaze includes a monthly no-cost tier for most of these.
- Cloud Scheduler: https://cloud.google.com/scheduler/pricing. The project uses 2 scheduled jobs; a few jobs per billing account are free.
- Secret Manager: https://cloud.google.com/secret-manager/pricing. 5 secrets, accessed when function instances start.
- Stripe: https://stripe.com/pricing and https://stripe.com/connect/pricing. Payment processing per charge, plus Connect fees for active accounts and payouts on some plans.
- SnapTrade: https://snaptrade.com/pricing
- Finnhub: https://finnhub.io/pricing. The free tier allows 60 API calls a minute.
- Apple Push Notification service and FCM have no usage fees.

What drives the bill at Arkad's scale:
- **The callout tracker** reads every open callout 96 times a day and writes those whose price moved. 200 open callouts is about 19,000 reads a day plus the writes, and each write also invokes `onCommunityMessageWritten` briefly.
- **Price alerts** read every active alert 288 times a day while markets are open.
- **Notification fan-out**: one write per member for each callout. A 1,000-member community posting 5 callouts a day is 5,000 writes and 5,000 push function runs.
- Scheduled functions take one Finnhub call per unique symbol per run, spaced about 1.1 seconds apart. Past roughly 400 unique open-callout symbols, or 250 alert symbols, a run hits its time budget, and some symbols wait for the next run. That's the point to move to a paid Finnhub plan or a streaming source.

## 12. Rules and the app

`firestore.rules` follows `docs/backend-contracts.md`. Writes it deliberately denies, which older app code made:

- Any client create of `notifications` (Cloud Functions create them; the app only sets `isRead`).
- Writing `reportCount` or `isHidden` on someone else's post (`onReportCreated` does it now).
- Hard-deleting a community message (messages are soft-deleted).
- Setting `callout.status` to anything other than `closed`, or editing any other callout field.
- A paying member deleting their own member doc (they cancel in the billing portal instead).
- Creating a member doc in a paid community (only the Stripe webhook does that).
- Writing `isPaid`, `priceMonthly`, `trialDays`, `stripeProductId` or `stripePriceId` on a community, or `source`, `isVerified`, `externalId` or `brokerageConnectionId` on a trade.
- Changing your own `isVerified` or `subscriptionTier`.
