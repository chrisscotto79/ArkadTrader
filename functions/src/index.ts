// Arkad Cloud Functions. Contract: docs/backend-contracts.md. Setup: docs/backend-setup.md.

// Notifications (contract section 2)
export { onNotificationCreated } from "./notifications/push.js";
export { onPostCreated, onCommentCreated, onPostLiked, onFollowerAdded, onMemberJoined } from "./notifications/social.js";

// Callout track records (section 3)
export { onCommunityMessageWritten } from "./callouts/messages.js";
export { onCalloutLedgerWritten, onUserProfileUpdated } from "./callouts/stats.js";
export { trackOpenCallouts } from "./callouts/tracker.js";

// Paid communities (section 4)
export {
  createConnectOnboardingLink,
  getConnectDashboardLink,
  setCommunityPrice,
  createCheckoutSession,
  createBillingPortalSession,
} from "./stripe/callables.js";
export { stripeWebhook } from "./stripe/webhook.js";

// Brokerage linking (section 5)
export { snaptradeConnectLink, snaptradeSync, snaptradeDisconnect } from "./snaptrade/callables.js";

// Price alerts (section 6)
export { checkPriceAlerts, onPriceAlertCreated } from "./alerts/priceAlerts.js";

// Moderation and cleanup (sections 1 and 8)
export { onReportCreated, onBanCreated, onMemberRemoved, onCommunityDeleted } from "./moderation/triggers.js";
export { onAccountDeleted } from "./account/onDelete.js";
