import { OAuth2Client } from 'google-auth-library';

// The web client ID from Google Cloud (Google Auth Platform → Clients). It is
// public: every app that uses Google sign-in ships it. The Android app asks
// Google for tokens addressed to this same ID, so one ID covers both.
const DEFAULT_CLIENT_ID = '856800606024-ncuqqanrfl35dhhmr3dn6c331s2atct8.apps.googleusercontent.com';

export const googleClientId = () => process.env.GOOGLE_CLIENT_ID || DEFAULT_CLIENT_ID;

const client = new OAuth2Client();

// Checks a Google ID token's signature, expiry and audience, and returns its
// claims: sub (Google's user id), email, email_verified, name, picture.
let verify = async (idToken) => {
  const ticket = await client.verifyIdToken({ idToken, audience: googleClientId() });
  return ticket.getPayload();
};

export const verifyGoogleToken = (idToken) => verify(idToken);

// Tests swap in a fake so they don't need real Google tokens.
export function setGoogleVerifier(fn) {
  verify = fn;
}
