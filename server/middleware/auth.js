import jwt from 'jsonwebtoken';
import User from '../models/User.js';
import { HttpError } from './error.js';

export function signToken(user) {
  return jwt.sign({ sub: user._id.toString() }, process.env.JWT_SECRET, { expiresIn: '7d' });
}

// Requires "Authorization: Bearer <token>". Puts the signed-in user on req.user.
export async function protect(req, res, next) {
  const header = req.get('authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) throw new HttpError(401, 'Not signed in');

  let payload;
  try {
    payload = jwt.verify(token, process.env.JWT_SECRET);
  } catch {
    throw new HttpError(401, 'Session expired or invalid, please sign in again');
  }

  const user = await User.findById(payload.sub);
  if (!user) throw new HttpError(401, 'Account no longer exists');
  req.user = user;
  next();
}

export function adminOnly(req, res, next) {
  if (!req.user?.isAdmin) throw new HttpError(403, 'Admins only');
  next();
}

// Everything except signing in, verifying and leaving needs a verified email.
export function verifiedRequired(req, res, next) {
  if (!req.user.emailVerified && !req.user.isAdmin) throw new HttpError(403, 'Verify your email first');
  next();
}

// The swipe deck needs a finished profile to score against.
export function profileRequired(req, res, next) {
  if (!req.user.profileComplete) throw new HttpError(409, 'Finish your profile first');
  next();
}
