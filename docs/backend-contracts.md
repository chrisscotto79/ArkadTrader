# Arkad data and backend contracts

The iOS app and the Cloud Functions in `functions/` both follow this file. If code and this file disagree, fix one of them so they match.

- Firebase project: `arkad-ios-app`. Functions region: `us-central1`. Callable functions are invoked from the app with `Functions.functions().httpsCallable("<name>")`.
- Server-only fields are written by Cloud Functions, never by the app. The Firestore rules enforce this.
- Every money amount is in US dollars as a `Double` (9.99). Stripe amounts in cents exist only inside `functions/`.
- Arkad's platform fee is **10%** of each paid community subscription. It is the constant `PLATFORM_FEE_PERCENT` in `functions/src/config.ts` and `AppConfig.platformFeePercent` in the app.
- Deep-link scheme: `arkad://`. Web flows (Stripe, SnapTrade) are opened with `ASWebAuthenticationSession`, using `callbackURLScheme: "arkad"`.

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
- `reason`: `"spam"`, `"harassment"`, `"scam_or_manipulation"`, `"hate"`, `"explicit"`, `"impersonation"` or `"other"`
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

### Callable functions

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
