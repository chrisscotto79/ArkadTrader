// Checks the Firebase ID token the app sends as `Authorization: Bearer <token>`, the same way
// the Firebase Admin SDK does: RS256, signed by Google's securetoken keys, for this project.

import { createRemoteJWKSet, jwtVerify } from "jose";
import { ApiError } from "./errors";

const GOOGLE_KEYS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);

/** Returns the signed-in user's uid, or throws 401. */
export async function verifyIdToken(authorization: string | null, projectId: string): Promise<string> {
  const token = authorization?.match(/^Bearer\s+(\S+)$/i)?.[1];
  if (!token) throw new ApiError(401, "Sign in again to continue.");
  try {
    const { payload } = await jwtVerify(token, GOOGLE_KEYS, {
      issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId,
      algorithms: ["RS256"],
    });
    const uid = payload.sub;
    if (typeof uid !== "string" || uid.length === 0 || uid.length > 128) throw new Error("bad subject");
    return uid;
  } catch {
    throw new ApiError(401, "Sign in again to continue.");
  }
}
