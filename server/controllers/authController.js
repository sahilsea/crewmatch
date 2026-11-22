import { randomBytes } from 'node:crypto';
import User from '../models/User.js';
import { signToken } from '../middleware/auth.js';
import { HttpError } from '../middleware/error.js';
import {
  issueCode, checkCode, emailCodesRequired, resendWait, checkLock, recordFailure, clearFailures,
} from '../utils/verification.js';
import { verifyGoogleToken } from '../utils/google.js';

const avatarFor = (name) => `https://api.dicebear.com/9.x/notionists/png?seed=${encodeURIComponent(name)}`;

// POST /api/auth/register
export async function register(req, res) {
  const { name, email, password } = req.body;
  if (await User.exists({ email })) throw new HttpError(409, 'An account with that email already exists');

  const required = emailCodesRequired();
  const user = await User.create({ name, email, password, avatar: avatarFor(name), emailVerified: !required });
  // devCode is only there when no email is set up (development, demos).
  const devCode = required ? await issueCode(user) : null;
  res.status(201).json({ token: signToken(user), user: user.toSelf(), ...(devCode && { devCode }) });
}

// POST /api/auth/login
export async function login(req, res) {
  const { email, password } = req.body;
  checkLock(email);
  const user = await User.findOne({ email }).select('+password');
  if (!user || !(await user.checkPassword(password))) {
    const left = recordFailure(email);
    throw new HttpError(401, left > 0 && left <= 2 ? `Wrong email or password. ${left} ${left === 1 ? 'try' : 'tries'} left before a 10-minute lock` : 'Wrong email or password');
  }
  clearFailures(email);
  res.json({ token: signToken(user), user: user.toSelf() });
}

// POST /api/auth/google  { idToken } — "Continue with Google". Signs in, links
// Google to an existing account with the same email, or creates a new one.
// Google has already checked the email, so it counts as verified.
export async function googleSignIn(req, res) {
  let profile;
  try {
    profile = await verifyGoogleToken(req.body.idToken);
  } catch {
    throw new HttpError(401, 'Google sign-in failed. Please try again.');
  }
  if (!profile?.sub || !profile.email || profile.email_verified !== true) {
    throw new HttpError(401, "Your Google account's email isn't verified");
  }
  const email = profile.email.toLowerCase();
  let user = await User.findOne({ $or: [{ googleId: profile.sub }, { email }] });
  const created = !user;
  if (created) {
    const name = (profile.name || email.split('@')[0]).trim().slice(0, 60);
    user = await User.create({
      name,
      email,
      // Never used: these accounts sign in with Google.
      password: randomBytes(24).toString('hex'),
      googleId: profile.sub,
      emailVerified: true,
      avatar: profile.picture || avatarFor(name),
    });
  } else {
    if (!user.googleId) user.googleId = profile.sub;
    user.emailVerified = true;
    await user.save();
  }
  clearFailures(email);
  res.status(created ? 201 : 200).json({ token: signToken(user), user: user.toSelf(), created });
}

const withCode = (id) => User.findById(id).select('+verifyCodeHash +verifyCodeExpires +verifyCodeSentAt +verifyAttempts');

// POST /api/auth/verify  { code }
export async function verifyEmail(req, res) {
  const user = await withCode(req.user._id);
  await checkCode(user, req.body.code);
  res.json({ user: user.toSelf() });
}

// POST /api/auth/resend — a new code, at most every 30 seconds.
export async function resendCode(req, res) {
  const user = await withCode(req.user._id);
  if (user.emailVerified) return res.json({ user: user.toSelf() });
  const wait = resendWait(user);
  if (wait > 0) throw new HttpError(429, `Wait ${wait} seconds before asking for another code`);
  const devCode = await issueCode(user);
  res.json({ sent: true, ...(devCode && { devCode }) });
}

// GET /api/auth/me
export function me(req, res) {
  res.json({ user: req.user.toSelf() });
}
