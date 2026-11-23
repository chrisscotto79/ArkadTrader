// Secrets live in Google Secret Manager. Set them with
//   firebase functions:secrets:set NAME
// See docs/backend-setup.md. Never hardcode values here.

import { defineSecret } from "firebase-functions/params";

export const FINNHUB_API_KEY = defineSecret("FINNHUB_API_KEY");
export const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
export const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
export const SNAPTRADE_CLIENT_ID = defineSecret("SNAPTRADE_CLIENT_ID");
export const SNAPTRADE_CONSUMER_KEY = defineSecret("SNAPTRADE_CONSUMER_KEY");
