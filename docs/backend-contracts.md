# Arkad data and backend contracts

The iOS app and the Cloud Functions in `functions/` both follow this file. If code and this file disagree, fix one of them so they match.

- Firebase project: `arkad-ios-app`. Functions region: `us-central1`. Callable functions are invoked from the app with `Functions.functions().httpsCallable("<name>")`.
- In server mode, server-only fields are written by Cloud Functions, never by the app, and the Firestore rules enforce this. In free mode (section 0, the current setup) the app writes some of them itself.
- Every money amount is in US dollars as a `Double` (9.99). Stripe amounts in cents exist only inside `functions/`.
- Arkad's platform fee is **10%** of each paid community subscription. It is the constant `PLATFORM_FEE_PERCENT` in `functions/src/config.ts` and `AppConfig.platformFeePercent` in the app.
- Deep-link scheme: `arkad://`. Web flows (Stripe, SnapTrade) are opened with `ASWebAuthenticationSession`, using `callbackURLScheme: "arkad"`.

## 0. Free mode (current)

Arkad currently runs on Firebase's free Spark plan. Cloud Functions, Stripe and SnapTrade are **not deployed**. Four switches in `Shared/Config/AppConfig.swift` control this, and all four are `false` for now:

| Switch | What it controls |
|---|---|
| `paidCommunitiesEnabled` | paid communities, payouts, subscriptions, the revenue dashboard |
| `brokerageLinkingEnabled` | SnapTrade brokerage linking |
| `serverFunctionsEnabled` | whether the server does the work below |
| `mediaUploadsEnabled` | photos attached to posts and chat (needs Cloud Storage) |

While `serverFunctionsEnabled == false`, the app does that work itself:

**Paid communities and brokerage are hidden.**
- There are no price fields in create or settings, no Subscribe button, no Payouts row, and no Linked brokerages row or entry points.
- Every community is free to join. The dashboard shows members and activity only.
- The code stays in place; the switches only hide it.

**Track records are computed on the phone.**
- When a callout is posted, the author's app also writes the mirror doc `users/{uid}/callouts/{messageId}`:
  - `communityId`, `channelId`, `messageId`, `ticker`, `assetType`, `direction`
  - `entryPrice`, `stopPrice?`, `targetPrice?`
  - `status`, `postedAt`, `closedAt?`, `exitPrice?`, `resultPercent?`
- Whenever a callout closes, the author's app updates the mirror. It then recomputes `traderStats/{uid}` and `communities/{cid}/traderStats/{uid}` from the user's own mirror docs and writes them, in the same shape as section 3.
- Auto-close:
  - When the author's app opens or comes to the foreground, it checks the author's open callouts. It uses the Finnhub free tier, for stocks only (crypto and forex follow the existing app mapping if quotes work).
  - It updates `callout.lastPrice` and `callout.lastPriceAt`. It closes a callout when price crosses the target (`target_hit`, exit at the target) or the stop (`stopped_out`, exit at the stop).
  - Callouts with neither a stop nor a target close after 30 days at the last price.
  - Closing writes `status`, `exitPrice`, `closedAt` and `resultPercent` on the message, then updates the mirror and the stats.
- Viewers' apps may fetch a live quote just to display an open callout's move, but they never write.
- Stats are self-reported by the author's app in this mode. That's acceptable for now; the server version (section 3) makes them tamper-proof later.

**Notifications are created by the app; there is no remote push.**
- The acting user's app creates `notifications` docs for the recipient, with the same fields as section 2, plus `fromUserId` (the actor), for:
  - likes, comments (`reply`), follows and @mentions in posts and chat;
  - new callouts (fanned out to community members except the author, in batches of 450 or fewer);
  - member joins (to the owner).
- Never notify yourself, and skip anyone you have blocked.
- The inbox hides the types the user turned off in `notificationPrefs`.
- Remote push is off. Only ask for notification permission for local notifications (price alerts).

**Price alerts are checked on the phone.**
- While the app is open (on launch, on returning to the foreground, then every 5 minutes), it checks the user's active alerts against Finnhub quotes.
- When an alert triggers, the app sets `isActive = false`, `triggeredAt` and `triggeredPrice`, and creates a `price_alert` notification for the user (`userId == fromUserId` is allowed only for this type).
- It also posts a local notification with `UNUserNotificationCenter`.
- The UI says alerts are checked while Arkad is open.

**Account deletion cleans up from the phone.** Before `Auth.currentUser.delete()`, the app deletes:
- the user's posts (and their comments and likes subcollections, where readable), trades, follows in both directions (with count updates where the existing unfollow code does that), and memberships (through the leave batch);
- communities the user owns;
- `users/{uid}` subcollections (`watchlist`, `priceAlerts`, `learnProgress`, `callouts`, `fcmTokens`, `following`, `followers`, `blockedUsers`, `reportedPosts`, `communityLessonProgress`), `traderStats/{uid}`, the profile image (`images/avatar_{uid}` in Firestore, see "Photos without Cloud Storage" below), and finally `users/{uid}`.

It's best-effort: each step is wrapped so one failure doesn't stop the rest. Chat messages are left as they are.

**Proof labels (anti-fake trades).** Every trade, trade-result post and callout shows how much it can be trusted.

Each trade gets a `proof` field:

| `proof` | Label | Meaning |
|---|---|---|
| `"verified"` | Verified | Imported from a linked brokerage (later, when brokerage linking is on) |
| `"price_checked"` | Price checked | Logged as it happened, at a real price |
| `"self_reported"` | Self-reported | Anything else; a missing `proof` means this |

How `price_checked` is decided:
- **Entry.** The entry date is today, and when logged the entry price was inside today's low–high range from a Finnhub quote (`l`/`h`, widened by 0.5% for quote delay). The app stores `loggedAt` (server timestamp) and `priceCheck: { low, high, checkedAt }`.
- **Exit.** Closing a `price_checked` trade checks the exit the same way: the exit date is today and the price is inside today's range. The app stores `exitProof` (`"price_checked"` or `"self_reported"`) and `exitLoggedAt`.
- The trade stays `price_checked` overall only if its exit is also `price_checked`. Otherwise `proof` becomes `"self_reported"` when it's closed.
- When no quote is available (no key, unsupported asset, network), the trade is `self_reported`.
- Old trades without `proof` are self-reported.

Locked fields:
- After create, `ticker`, `tradeType`, `entryPrice`, `quantity`, `entryDate`, `proof`, `loggedAt` and `priceCheck` never change. Notes, strategy, tags and the stop or target may change.
- Once closed, `exitPrice`, `exitDate`, `exitProof` and `exitLoggedAt` never change.
- A `price_checked` trade can be deleted only within 15 minutes of `loggedAt`, so losers can't be removed later. Account deletion is the exception: the app deletes `users/{uid}` first, then its trades.

What counts:
- Win rate, P&L and performance shown on profiles and anywhere else count only `price_checked` and `verified` trades.
- The portfolio itself still shows everything, labelled. Self-reported totals may appear separately, clearly labelled "Self-reported".

Trade-result posts:
- A post of type trade result must have `tradeId`, pointing to the author's own closed trade, plus `tradeSnapshot: { ticker, tradeType, entryPrice, exitPrice, quantity, entryDate, exitDate, proof }`, copied from the trade.
- The card shows the snapshot's numbers (P&L computed from them) and its label. There is no free-typed P&L.
- The rules check that the snapshot matches the trade doc.

Callouts:
- On the message's `callout` map: `priceCheck: "live"` (entry within 2% of a live quote) or `"unchecked"`, and `quoteAtPost` (the quote the app saw). The rules re-check the 2% for `"live"`.
- Manual close: the exit must be within 2% of a live quote. With no quote the author can still close at any price, but the mirror gets `exitCheck: "unchecked"`. Live closes and the tracker's auto-closes write `exitCheck: "live"`.
- Mirror doc `users/{uid}/callouts/{messageId}` adds `priceCheck`, `quoteAtPost`, `exitCheck` and `closedBy` (`"target"`, `"stop"`, `"expired"`, `"author"` or `"deleted"`).
- Deleting an open callout closes its mirror with `closedBy: "deleted"` at the last price, and it still counts, so deleting can't hide a losing call.
- Callouts with `priceCheck` or `exitCheck` of `"unchecked"` are labelled and excluded from `traderStats`.

Reports (free mode): the reporter's app writes `posts/{pid}/reporters/{me}` and `reportCount + 1` in one batch, once per person, and sets `isHidden` once `reportCount` reaches 3.

**Photos without Cloud Storage.** The project's storage bucket needs the paid Blaze plan, so for now images live in Firestore.
- `images/{imageId}`: `{ ownerId, kind: "avatar"|"community_avatar"|"community_banner", data: Bytes (JPEG), width, height, updatedAt }`.
  - Ids: `avatar_{uid}`, `community_avatar_{cid}`, `community_banner_{cid}`.
  - Avatars are 256 px square at about JPEG 0.7, community avatars 256 px, banners at most 1200 px wide. Every image stays under 700 KB.
- Image fields (`profileImageUrl`, `avatarURL`, `bannerURL`, `authorAvatarURL`) hold `arkad-image://{imageId}?v={unix seconds}`. The `v` parameter changes on every upload, which busts caches.
- Every place that shows an image resolves both `https://` and `arkad-image://`, through one shared cached image view.
- Photos attached to posts and chat are switched off by `AppConfig.mediaUploadsEnabled = false` until Storage is available.

**Security rules.** The free-mode rules are in `firestore.rules`, and they allow exactly these client writes. The stricter server-mode rules are kept in `firestore.server.rules`, for when the functions are deployed.

**Security model in free mode.** With no server, every write comes from someone's phone, so there are two kinds of data:
- *Enforced by the rules.* Who may write what: you can only write your own profile, posts, trades, follows, memberships and mirror docs; field shapes, sizes and types; fields that are locked after create (trade entries, proof labels, timestamps that must be the server time); counters that may only move by one in a matching batch; and the evidence a notification must point to. Someone with a modified app still can't write as another user, edit someone else's data, or break these shapes.
- *Trusted from the app.* Anything the phone computes: price checks against a live quote, callout auto-closes, and the track-record numbers in `traderStats` (win rate, average result, counts). The rules check their shape and ranges, but not that the numbers are true, so a determined person with a modified app could inflate their own stats. Treat track records as app-computed until server mode, where Cloud Functions recompute them from the ledger (section 3) and `firestore.server.rules` makes them server-only.

`firestore.rules` is the source of truth for the exact checks.


## Existing collections (unchanged unless noted)

- `users/{uid}`
- `posts/{postId}`, plus its `comments` and `likes` subcollections
- `trades/{tradeId}`
- `communities/{cid}`, with subcollections:
  - `members/{uid}`
  - `channels/{chid}`, which holds `messages/{mid}`, each with its own `reactions` subcollection
  - `rules/{rid}`
- `users/{uid}/following`, `users/{uid}/followers` and `users/{uid}/blockedUsers/{blockedUid}`
- `notifications/{id}`
- `marketNews`

A trade callout is a message in a callouts channel that has a `callout` map (`TradeCallout.toFirestore()`).

## 1. Safety and moderation

### `reports/{id}`
The app creates these. Only admins read them, in the Firebase console.

Fields:
- `targetType`: `"post"`, `"comment"`, `"message"`, `"user"` or `"community"`
- `targetId`
- `targetOwnerId`
- `communityId?`
- `channelId?`
- `postId?`, for a comment
- `reason`: `"spam"`, `"harassment"`, `"fake_trade_or_result"`, `"scam_or_manipulation"`, `"hate"`, `"explicit"`, `"impersonation"` or `"other"`
- `details?`
- `reportedBy`
- `createdAt`
- `status`: `"pending"`

### `users/{uid}/blockedUsers/{blockedUid}`
- Fields: `{ userId, blockedAt }`. This collection already exists.
- Blocking hides the blocked person's posts, comments and messages from you, and removes any follow in either direction.

### Message fields added on `communities/{cid}/channels/{chid}/messages/{mid}`
- `authorAvatarURL?`
- `editedAt?`
- `isDeleted` (Bool). Deleting a message sets `isDeleted: true`, `content: ""`, `deletedBy` and `deletedAt`, and removes `callout`. It is a soft delete, so every listener sees the change.
- `isPinned` (Bool), `pinnedBy?` and `pinnedAt?`. Owners and moderators can pin.
- Deleting or pinning any message is allowed for the community owner and for moderators. Authors can delete or edit their own messages.

### Members and bans
- `communities/{cid}/members/{uid}` gains `mutedUntil?` (Timestamp). A muted member can read but not post.
- `communities/{cid}/bans/{uid}`: `{ bannedBy, reason?, createdAt }`. A banned user is removed from `members` and can't rejoin.
- App helper, `FirebaseServices.shared.isUserBanned(communityId:userId:) async throws -> Bool`, lives in `FirebaseServices+Moderation.swift`.

### Post author fields
`posts/{postId}` stores `authorUsername`, `authorFullName` and `authorAvatarURL?` when it is created, so feeds don't need to look up each author.

## 2. Notifications

### Device tokens and preferences
- `users/{uid}/fcmTokens/{token}`: `{ token, platform: "ios", updatedAt }`. The app writes it after sign-in and deletes it on sign-out.
- `users/{uid}.notificationPrefs` is a map of Bools, all `true` by default: `callouts`, `mentions`, `replies`, `follows`, `likes`, `communityActivity`, `priceAlerts`, `calloutResults`.

### `notifications/{id}`
- Fields: `{ userId, type, title, body, data, isRead, createdAt }`.
- Cloud Function triggers create these. The app only reads them and sets `isRead`.
- When a notification is created, a trigger sends a push to the user's tokens, unless the matching preference is off.

| type | created when | pref key |
|---|---|---|
| `callout` | a new callout is posted, sent to every community member except the author | callouts |
| `callout_result` | a callout hits its target or stop, or is closed; sent to members | calloutResults |
| `mention` | a message or post contains `@username` | mentions |
| `reply` | someone comments on your post | replies |
| `like` | someone likes your post | likes |
| `follow` | someone follows you | follows |
| `member_joined` | someone joins your community (owner only) | communityActivity |
| `subscription` | a paid member subscribes or cancels (owner only) | communityActivity |
| `price_alert` | a price alert triggers | priceAlerts |

### `data` keys for deep links
- `route`: `"community"`, `"channel"`, `"post"`, `"profile"`, `"portfolio"`, `"learn"` or `"watchlist"`
- Optional: `communityId`, `channelId`, `messageId`, `postId`, `userId`, `symbol`

The same `data` map is copied into the push payload.

## 3. Callout track records

The server tracks open callouts using live prices. A scheduled function runs every 15 minutes:
- It reads open callouts with `collectionGroup("messages").where("callout.status", "==", "open")`.
- It updates `callout.lastPrice` and `callout.lastPriceAt`.
- A callout closes when price crosses `targetPrice` (`target_hit`) or `stopPrice` (`stopped_out`). Prices come from Finnhub; crypto and forex tickers are mapped as in the app.
- A callout with neither a stop nor a target closes automatically after 30 days, as `closed` at the last price.

Fields added to the `callout` map:
- `authorId`, `communityId` and `postedAt`. The app sets these when it creates the callout.
- `lastPrice?` and `lastPriceAt?`
- `exitPrice?`
- `closedAt?`
- `resultPercent?`: the signed percent move for the callout's direction, set when it closes.

The author can close a callout manually. The app sets these fields directly on the message:
- `callout.status = "closed"`
- `callout.exitPrice` (entered or live)
- `callout.closedAt`
- `callout.resultPercent`

### `traderStats/{uid}` (server only, anyone signed in can read)

| field | meaning |
|---|---|
| `calloutsTotal` | all callouts posted |
| `calloutsClosed` | callouts that have closed |
| `openCallouts` | callouts still open |
| `wins` | closed with `resultPercent > 0` |
| `losses` | closed with `resultPercent <= 0` |
| `winRate` | 0–1, from `wins / calloutsClosed` |
| `avgReturnPercent` | average result of closed callouts |
| `totalReturnPercent` | summed result of closed callouts |
| `bestCalloutPercent` | best single result |
| `worstCalloutPercent` | worst single result |
| `lastCalloutAt` | when the latest callout was posted |
| `updatedAt` | when the server last wrote this doc |
| `username` | denormalized for the leaderboard |
| `profileImageUrl?` | denormalized for the leaderboard |

- `communities/{cid}/traderStats/{uid}` has the same shape, for callouts in that community only.
- Leaderboards read these docs. A trader is ranked only after `calloutsClosed >= 5`; below that the app shows "Not enough closed callouts yet".
- Sort keys: `winRate`, `avgReturnPercent`, `totalReturnPercent`, `calloutsClosed`.

## 4. Paid communities (Stripe Connect)

### Fields on `communities/{cid}`
- The owner sets `isPaid` (Bool), `priceMonthly?` (Double, US$, minimum 1.00) and `trialDays` (0, 3 or 7), through the `setCommunityPrice` function.
- The server sets `stripeProductId?` and `stripePriceId?`.

### Members of paid communities
- `communities/{cid}/members/{uid}` gains `subscriptionStatus`: `"active"`, `"trialing"`, `"past_due"` or `"canceled"`, plus `currentPeriodEnd?`. The server writes both. The owner has no subscription.
- Joining a paid community only happens through Stripe Checkout. The webhook creates the member doc and adds the id to `users/{uid}.communityIds`.
- When a subscription ends, the webhook removes the membership.
- Non-members of a paid community see the preview only: name, description, rules, member count, the owner's track record and the price. They can't read channels.

### `stripeAccounts/{uid}`
Server writes; only the owner reads. Fields:
- `accountId`
- `chargesEnabled`
- `payoutsEnabled`
- `detailsSubmitted`
- `updatedAt`

### `communities/{cid}/private/revenue`
Server writes; only the owner reads. Fields:
- `activeSubscribers`
- `trialingSubscribers`
- `mrr`: monthly recurring revenue, gross US$
- `lifetimeGross`
- `lifetimeArkadFees`
- `lifetimeNet`
- `updatedAt`

### Callable functions

| name | input | output |
|---|---|---|
| `createConnectOnboardingLink` | `{}` | `{ url }`, which returns to `arkad://payouts/done` |
| `getConnectDashboardLink` | `{}` | `{ url }` |
| `setCommunityPrice` | `{ communityId, isPaid, priceMonthly?, trialDays? }` | `{ ok }`. The caller must own the community, and `chargesEnabled` must be true when making it paid. |
| `createCheckoutSession` | `{ communityId }` | `{ url }`. Success returns to `arkad://checkout/success?communityId=…`, cancel to `arkad://checkout/cancel`. |
| `createBillingPortalSession` | `{}` | `{ url }`, which returns to `arkad://billing/done` |

`stripeWebhook` is an HTTPS function that Stripe calls; the app never calls it. It handles:
- `checkout.session.completed`
- `customer.subscription.updated` and `customer.subscription.deleted`
- `invoice.paid`
- `account.updated`

Subscriptions use `application_fee_percent: PLATFORM_FEE_PERCENT` and `transfer_data.destination` set to the owner's account.

## 5. Brokerage linking (SnapTrade, read-only)

**Free mode:** this runs on the Cloudflare Worker in `brokerage-worker/` instead of Cloud Functions, so Firebase can stay on Spark. The app POSTs to `<BrokerageWorkerURL>/connect`, `/sync`, `/disconnect` and `/delete-user` with `Authorization: Bearer <Firebase ID token>`; inputs and outputs are the same as the callables below, and errors are `{ error: { message } }` with an HTTP status. The Worker writes the same documents, signed in as a service account. It also serves the return page at `/open/brokerage/connected`. Setup: `docs/brokerage-worker-setup.md`. Brokerage linking is on when `BrokerageWorkerURL` is set in `App/Secrets.plist`.

### Callable functions (Blaze plan only, not used in free mode)

| name | input | output |
|---|---|---|
| `snaptradeConnectLink` | `{}` | `{ url }`. Registers the SnapTrade user if needed and returns the connection portal URL, which redirects to `arkad://brokerage/connected`. |
| `snaptradeSync` | `{}` | `{ importedTrades, holdings }` |
| `snaptradeDisconnect` | `{ connectionId }` | `{ ok }` |

### Server-written data

`users/{uid}/brokerageConnections/{connectionId}`, readable by the owner. Fields:
- `brokerageName`
- `status`: `"connected"` or `"broken"`
- `createdAt`
- `lastSyncAt?`

`users/{uid}/brokerageHoldings/{id}`, readable by the owner. Fields:
- `symbol`
- `assetType`: a `TradeType` raw value
- `quantity`
- `averagePrice`
- `currentPrice`
- `marketValue`
- `connectionId`
- `brokerageName`
- `updatedAt`

Imported trades go into the existing `trades` collection, in the same shape as `Trade.toFirestore()`, plus:
- `source: "brokerage"`
- `brokerageConnectionId`
- `externalId`, which prevents importing the same trade twice
- `isVerified: true`

Trades the user enters themselves have no `source`, or `source: "manual"`.

## 6. Watchlists and price alerts

- `users/{uid}/watchlist/{symbol}`: `{ symbol, assetType, addedAt }`.
- `users/{uid}/priceAlerts/{id}`: `{ symbol, assetType, condition: "above"|"below", targetPrice, isActive, createdAt, triggeredAt? }`.
  - The app creates and deletes alerts.
  - A function runs every 5 minutes during market hours (crypto: always). When an alert triggers, it sets `isActive = false` and `triggeredAt`, and creates a `price_alert` notification.
  - Each user can have at most 20 active alerts.

## 7. Onboarding and Learn

- `users/{uid}` gains these fields, which the app writes:
  - `experienceLevel`: `"new"`, `"intermediate"` or `"experienced"`
  - `interests`: `[String]` of `CommunityType` raw values
  - `onboardingCompleted` (Bool)
- Existing users with no `onboardingCompleted` field are treated as completed, so they aren't sent through onboarding.
- `users/{uid}/learnProgress/{lessonId}`: `{ completedAt, quizScore?, quizTotal? }`.

## 8. Account deletion

An Auth `onDelete` trigger cleans up after the user's account is deleted:
- It deletes `users/{uid}` and all its subcollections.
- It deletes the user's posts, comments, likes, trades, follows in both directions, fcm tokens, watchlist, alerts, learn progress and `traderStats`.
- In chat, it soft-deletes the user's messages (`isDeleted`) and removes their memberships.
- It cancels Stripe subscriptions, and deletes the SnapTrade user.
- Communities the user owns are deleted along with their members.

The app only has to call `Auth.currentUser.delete()`, after re-authenticating if needed.

## 9. Secrets (Functions params, set with `firebase functions:secrets:set`)

`FINNHUB_API_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `SNAPTRADE_CLIENT_ID`, `SNAPTRADE_CONSUMER_KEY`.

## 10. Shared view names (so separate work compiles together)

| View | Built by | Used by |
|---|---|---|
| `BlockedUsersView()` | safety work | Settings |
| `NotificationSettingsView()` | notifications work | Settings |
| `NotificationsInboxView()` | notifications work | Home header bell |
| `PayoutsView()` | paid communities work | Settings |
| `LinkedAccountsView()` | brokerage work | Settings, Portfolio |
| `TrackRecordCard(userId: String)` | track records work | ProfileView, OtherUserProfileView, CommunityPreviewSheet |
| `LearnHubView()` | Learn work | Discover, Home |
| `LearnPromoCard()` | Learn work | Home, for users whose `experienceLevel == "new"` or who haven't finished a lesson |
| `WatchlistView()` | watchlist work | Discover |
| `ReportSheet(target: ReportTarget)` | safety work | anywhere content can be reported |

`ReportTarget` is defined in the safety work with these cases:
- `.post(id:ownerId:)`
- `.comment(id:postId:ownerId:)`
- `.message(id:communityId:channelId:ownerId:)`
- `.user(id:)`
- `.community(id:ownerId:)`

## 11. Community expansion (Discord, Whop and Skool ideas)

Everything here works in free mode. The rules in `firestore.rules` check each write.

### Posting trades in a community
Every new kind is an optional map on a channel message, `communities/{cid}/channels/{chid}/messages/{mid}`. A message carries at most one of `callout`, `calloutUpdate`, `calloutResult`, `tradeShare` or `gamePlan`. `content` is always a plain-text summary, so old app versions still show something.

- **Reply:** `replyTo: { messageId, authorId, authorUsername, preview }`. `preview` is at most 200 characters. It can go on any message.
- **Callout update:** `calloutUpdate: { parentMessageId, kind, price?, percent?, note? }`.
  - `kind` is `"trim"`, `"add"`, `"move_stop"`, `"move_target"` or `"note"`. `percent` is the share of the position trimmed or added, 1–100.
  - Only the callout's author can post one, in the same channel, while the callout is open.
  - For `move_stop` / `move_target`, the app also updates `callout.stopPrice` / `callout.targetPrice` on the parent. The tracker then uses the new level.
  - The callout card shows "N updates" and a timeline. Members get a `callout_update` notification.
- **Callout result:** `calloutResult: { parentMessageId, ticker, direction, status, exitPrice, resultPercent, exitCheck }`.
  - The author's app posts it right after a callout closes, whether the author closed it or the tracker did.
  - `status`, `exitPrice` and `resultPercent` must equal the parent's closed callout.
  - It's shown as a result card, green or red, with the price-check label.
- **Trade share:** `tradeShare: { tradeId, ticker, tradeType, entryPrice, quantity, isOpen, exitPrice?, proof, note? }`.
  - It's copied from the author's own `trades/{tradeId}`, and the rules compare the fields. Open trades can be shared too.
  - You start one from Portfolio, with "Share to community" on a trade, then pick a community and channel. Members get a `trade_share` notification only when the channel is a callouts channel.
- **Game plan:** `gamePlan: { title, tickers: [{ symbol, bias: "bullish"|"bearish"|"neutral", levels?, note? }] }`, with 1–15 tickers. It's a daily watchlist template for leaders, posted from the composer's "+" menu.
- **Announcements:** use an `adminOnly` channel, which already exists. The create-channel sheet offers "Announcements" as a preset that sets `adminOnly: true`.

### Classroom (Skool-style)
- `communities/{cid}/courses/{courseId}`: `{ communityId, title, summary, order, lessonCount, createdBy, createdAt, updatedAt }`.
- `.../courses/{courseId}/lessons/{lessonId}`: `{ title, body (Markdown, at most 20,000 characters), videoURL? (https; YouTube or Vimeo links open in the browser), order, createdAt, updatedAt }`.
- Owners, admins and moderators write. Anyone who can read the community reads.
- Progress is private, in `users/{uid}/communityLessonProgress/{cid}_{courseId}_{lessonId}`: `{ communityId, courseId, lessonId, completedAt }`.
- The community gets a "Classroom" tab with courses, a progress percentage and a lesson reader.

### Events
- `communities/{cid}/events/{eventId}`: `{ communityId, title, details, startsAt (Timestamp), durationMinutes, link? (https), createdBy, rsvpCount, createdAt }`.
- `.../events/{eventId}/rsvps/{uid}`: `{ userId, createdAt }`. Creating or deleting it moves `rsvpCount` by 1 in the same batch.
- Staff create, edit and delete events; members RSVP.
- When you RSVP, the app schedules a local notification 15 minutes before the start, and cancels it when you un-RSVP.
- Creating an event notifies members (`community_event`, fanned out like callouts).
- The community gets an "Events" tab with upcoming and past events.

### Community landing page (Whop-style)
Before joining, the preview shows:
- name, banner and avatar;
- the leader's checked track record: win rate, average result and number of closed, price-checked callouts from `traderStats/{ownerId}`, or "No checked callouts yet";
- what's inside: channel names, course count, the next event, member count;
- recent callout results (the last 5 `calloutResult` messages from callouts channels, when readable);
- a big "Join free" button.

Joined members see the same "About" section in the community.

### New notification types
`callout_update`, `trade_share` and `community_event`, with data `{ route: "community", communityId, channelId?, messageId?, eventId? }`. They map to the "Your communities" preference.
