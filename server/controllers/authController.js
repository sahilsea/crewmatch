import User from '../models/User.js';
import { signToken } from '../middleware/auth.js';
import { HttpError } from '../middleware/error.js';
import {
  issueCode, checkCode, resendWait, checkLock, recordFailure, clearFailures,
} from '../utils/verification.js';

const avatarFor = (name) => `https://api.dicebear.com/9.x/notionists/png?seed=${encodeURIComponent(name)}`;

// POST /api/auth/register
export async function register(req, res) {
  const { name, email, password } = req.body;
  if (await User.exists({ email })) throw new HttpError(409, 'An account with that email already exists');

  const user = await User.create({ name, email, password, avatar: avatarFor(name) });
  // devCode is only there when no email is set up (development, demos).
  const devCode = await issueCode(user);
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
