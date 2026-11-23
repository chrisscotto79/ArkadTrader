// Shared constants for every Cloud Function. See docs/backend-contracts.md.

/** Arkad's cut of every paid community subscription, in percent. Matches `AppConfig.platformFeePercent` in the app. */
export const PLATFORM_FEE_PERCENT = 10;

/** Region for every function. The app calls `Functions.functions()` (us-central1). */
export const REGION = "us-central1";

/** Firebase Hosting site that serves the legal pages and the app-return pages. */
export const HOSTING_ORIGIN = "https://arkad-ios-app.web.app";

/** Custom URL scheme the iOS app registers (ASWebAuthenticationSession callbackURLScheme). */
export const APP_SCHEME = "arkad";

/**
 * Stripe and SnapTrade send the user back to an https page on Hosting
 * (`/open/<path>`), which immediately forwards to `arkad://<path>`.
 * Stripe rejects non-https return URLs in live mode, so every web flow goes
 * through this page. See hosting/open/index.html.
 */
export function appReturnUrl(path: string, query?: Record<string, string>): string {
  const clean = path.replace(/^\/+/, "");
  const qs = query ? "?" + new URLSearchParams(query).toString() : "";
  return `${HOSTING_ORIGIN}/open/${clean}${qs}`;
}

/** The deep link the Hosting page forwards to (used for logging and docs). */
export function appDeepLink(path: string): string {
  return `${APP_SCHEME}://${path.replace(/^\/+/, "")}`;
}

// Paid communities
export const MIN_PRICE_MONTHLY = 1.0;
export const MAX_PRICE_MONTHLY = 999.99;
export const ALLOWED_TRIAL_DAYS = [0, 3, 7];
export const CURRENCY = "usd";

// Callouts
export const CALLOUT_AUTO_CLOSE_DAYS = 30;
export const MIN_CLOSED_FOR_RANKING = 5; // the app enforces this; kept here for reference

// Price alerts
export const MAX_ACTIVE_PRICE_ALERTS = 20;

// SnapTrade
export const BROKERAGE_IMPORT_DAYS = 90;

// Notifications
/** At most this many @mentions per message, post or comment produce notifications. */
export const MAX_MENTIONS_PER_ITEM = 10;
/** Posts hide automatically after this many distinct reporters. */
export const POST_AUTO_HIDE_REPORTS = 3;

/** Finnhub free tier allows 60 calls a minute; stay a little under it. */
export const FINNHUB_MIN_INTERVAL_MS = 1100;
