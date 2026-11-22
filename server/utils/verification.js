import crypto from 'node:crypto';
import bcrypt from 'bcryptjs';
import { HttpError } from '../middleware/error.js';
import { sendMail, canSendEmail } from './mailer.js';

// Email codes are off unless REQUIRE_EMAIL_VERIFICATION=true (turn it on once
// an email service is connected). Google sign-in is verified by Google either way.
export const emailCodesRequired = () => process.env.REQUIRE_EMAIL_VERIFICATION === 'true';

export const CODE_TTL_MINUTES = 15;
export const RESEND_AFTER_SECONDS = 30;
export const MAX_CODE_ATTEMPTS = 5;

// A fresh 6-digit code for `user`: stored hashed, valid for 15 minutes, and
// emailed. Returns the code only when there's no email set up, so the app can
// show it during development and demos.
export async function issueCode(user) {
  const code = String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
  user.verifyCodeHash = await bcrypt.hash(code, 8);
  user.verifyCodeExpires = new Date(Date.now() + CODE_TTL_MINUTES * 60 * 1000);
  user.verifyCodeSentAt = new Date();
  user.verifyAttempts = 0;
  await user.save();
  await sendMail({
    to: user.email,
    subject: `${code} is your CrewMatch code`,
    text: `Hi ${user.name.split(' ')[0]},\n\nYour CrewMatch verification code is ${code}.\nIt expires in ${CODE_TTL_MINUTES} minutes.\n\nIf you didn't sign up, ignore this email.`,
  });
  return canSendEmail() || process.env.NODE_ENV === 'production' ? null : code;
}

// Checks a code the user typed; marks the email verified when it matches.
export async function checkCode(user, code) {
  if (user.emailVerified) return;
  if (!user.verifyCodeHash || !user.verifyCodeExpires) throw new HttpError(400, 'Ask for a new code');
  if (user.verifyCodeExpires < new Date()) throw new HttpError(400, 'That code has expired. Ask for a new one');
  if (user.verifyAttempts >= MAX_CODE_ATTEMPTS) throw new HttpError(429, 'Too many wrong codes. Ask for a new one');
  if (!(await bcrypt.compare(code, user.verifyCodeHash))) {
    user.verifyAttempts += 1;
    await user.save();
    const left = MAX_CODE_ATTEMPTS - user.verifyAttempts;
    throw new HttpError(400, left > 0 ? `Wrong code. ${left} ${left === 1 ? 'try' : 'tries'} left` : 'Too many wrong codes. Ask for a new one');
  }
  user.emailVerified = true;
  user.verifyCodeHash = null;
  user.verifyCodeExpires = null;
  user.verifyAttempts = 0;
  await user.save();
}

// Seconds until another code may be sent (0 when it's fine now).
export function resendWait(user) {
  if (!user.verifyCodeSentAt) return 0;
  const elapsed = (Date.now() - user.verifyCodeSentAt.getTime()) / 1000;
  return Math.max(0, Math.ceil(RESEND_AFTER_SECONDS - elapsed));
}

// Slows down password guessing: 5 wrong passwords for an email lock it for
// 10 minutes. Kept in memory — fine for one server.
const failures = new Map();
const LOCK_AFTER = 5;
const LOCK_MINUTES = 10;

export function checkLock(email) {
  const f = failures.get(email);
  if (f?.until && f.until > Date.now()) {
    const minutes = Math.ceil((f.until - Date.now()) / 60000);
    throw new HttpError(429, `Too many wrong passwords. Try again in ${minutes} minute${minutes === 1 ? '' : 's'}`);
  }
}

export function recordFailure(email) {
  const f = failures.get(email) ?? { count: 0, until: 0 };
  f.count += 1;
  if (f.count >= LOCK_AFTER) {
    f.until = Date.now() + LOCK_MINUTES * 60 * 1000;
    f.count = 0;
  }
  failures.set(email, f);
  return LOCK_AFTER - f.count;
}

export const clearFailures = (email) => failures.delete(email);
