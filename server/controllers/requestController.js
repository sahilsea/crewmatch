import mongoose from 'mongoose';
import User from '../models/User.js';
import Crew from '../models/Crew.js';
import Club from '../models/Club.js';
import TeamRequest from '../models/TeamRequest.js';
import { compatibility, reasonTags } from '../utils/matching.js';
import { HttpError } from '../middleware/error.js';
import { teamFor } from './deckController.js';

// Requests one person can send in a day, so nobody spams the whole campus.
export const DAILY_REQUEST_LIMIT = 20;

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Two people become a match: the same as two right swipes. Any request
// between them is settled as accepted.
export async function makeMatch(a, b) {
  await Promise.all([
    User.updateOne({ _id: a }, { $addToSet: { matches: b, swipedRight: b }, $pull: { swipedLeft: b } }),
    User.updateOne({ _id: b }, { $addToSet: { matches: a, swipedRight: a }, $pull: { swipedLeft: a } }),
    TeamRequest.updateMany(
      { status: 'pending', $or: [{ from: a, to: b }, { from: b, to: a }] },
      { $set: { status: 'accepted' } }
    ),
  ]);
}

// Crew names for a set of users, keyed by user id.
async function crewNames(users) {
  const ids = [...new Set(users.map((u) => u.crew?.toString()).filter(Boolean))];
  if (!ids.length) return {};
  const crews = await Crew.find({ _id: { $in: ids } }, 'name');
  const byCrew = Object.fromEntries(crews.map((c) => [c.id, c.name]));
  return Object.fromEntries(users.map((u) => [u.id, byCrew[u.crew?.toString()] ?? null]));
}

// Club badges for everyone's clubs, keyed by club id.
async function clubsOf(users) {
  const ids = [...new Set(users.flatMap((u) => (u.clubs ?? []).map(String)))];
  if (!ids.length) return {};
  const clubs = await Club.find({ _id: { $in: ids } });
  return Object.fromEntries(clubs.map((c) => [c.id, c.toTag()]));
}

// Where I stand with each of these people: matched, a request sent or received.
async function relations(me, users) {
  const ids = users.map((u) => u._id);
  const pending = await TeamRequest.find({
    status: 'pending',
    $or: [{ from: me._id, to: { $in: ids } }, { to: me._id, from: { $in: ids } }],
  });
  const out = {};
  for (const r of pending) {
    if (r.from.equals(me._id)) out[r.to.toString()] = { relation: 'sent', requestId: r.id };
    else out[r.from.toString()] = { relation: 'received', requestId: r.id };
  }
  for (const id of me.matches) out[id.toString()] = { relation: 'matched', requestId: null };
  return out;
}

// A person as the app shows them: public fields, fit with my team, crew, and where we stand.
export async function present(me, users) {
  const [team, crews, rel, clubTags] = await Promise.all([teamFor(me), crewNames(users), relations(me, users), clubsOf(users)]);
  return users.map((u) => ({
    ...u.toPublic(),
    score: compatibility(team, u),
    tags: reasonTags(team, u),
    crewName: crews[u.id] ?? null,
    clubs: (u.clubs ?? []).map((id) => clubTags[id.toString()]).filter(Boolean),
    relation: rel[u.id]?.relation ?? null,
    requestId: rel[u.id]?.requestId ?? null,
  }));
}

// GET /api/users/search?q=&free=1&role=backend
// Students with a finished profile, best fit first. q matches name, role, skills or headline.
export async function searchUsers(req, res) {
  const me = req.user;
  const q = String(req.query.q ?? '').trim().slice(0, 60);
  const filter = { _id: { $ne: me._id }, isAdmin: false, profileComplete: true };
  if (q) {
    const rx = new RegExp(escapeRegex(q), 'i');
    filter.$or = [{ name: rx }, { role: rx }, { skills: rx }, { headline: rx }, { handle: rx }];
  }
  if (req.query.free === '1') filter.crew = null;
  if (req.query.role) filter.role = String(req.query.role);
  if (req.query.club && mongoose.isValidObjectId(req.query.club)) filter.clubs = req.query.club;
  const users = await User.find(filter).limit(200);
  const results = (await present(me, users)).sort((a, b) => b.score - a.score).slice(0, 50);
  res.json({ count: results.length, results });
}

// GET /api/users/handle/:handle — someone's profile from their link (or their id,
// from a post or chat), for a signed-in student.
export async function getByHandle(req, res) {
  const key = String(req.params.handle);
  const found = mongoose.isValidObjectId(key) ? await User.findById(key) : await User.findOne({ handle: key.toLowerCase() });
  const user = found && !found.isAdmin ? found : null;
  if (!user) throw new HttpError(404, 'No one has that link');
  const [person] = await present(req.user, [user]);
  res.json({ user: person, isMe: user._id.equals(req.user._id) });
}

// GET /api/public/u/:handle — what anyone with the link sees, signed in or not.
export async function publicProfile(req, res) {
  const user = await User.findOne({ handle: String(req.params.handle).toLowerCase(), isAdmin: false });
  if (!user) throw new HttpError(404, 'No one has that link');
  const pub = user.toPublic();
  res.json({
    user: {
      handle: pub.handle, name: pub.name, avatar: pub.avatar, headline: pub.headline, bio: pub.bio,
      role: pub.role, experienceLevel: pub.experienceLevel, skills: pub.skills, interests: pub.interests,
      coverUrl: pub.coverUrl, cover: pub.cover, accent: pub.accent, inCrew: !!user.crew,
    },
  });
}

// POST /api/requests  { to, note?, source? }
export async function sendRequest(req, res) {
  const me = req.user;
  const { to, note = '', source = 'profile' } = req.body;
  if (!mongoose.isValidObjectId(to)) throw new HttpError(404, 'User not found');
  if (me._id.equals(to)) throw new HttpError(400, "You can't send yourself a request");
  const target = await User.findById(to);
  if (!target || target.isAdmin) throw new HttpError(404, 'User not found');
  if (me.matches.some((id) => id.equals(target._id))) throw new HttpError(409, "You're already matched");

  // They already asked me: sending one back is a yes.
  const theirs = await TeamRequest.findOne({ from: target._id, to: me._id, status: 'pending' });
  if (theirs) {
    await makeMatch(me._id, target._id);
    return res.json({ match: true, user: { ...target.toPublic(), email: target.email } });
  }
  if (await TeamRequest.exists({ from: me._id, to: target._id, status: 'pending' })) {
    throw new HttpError(409, 'Request already sent');
  }
  if (await TeamRequest.exists({ from: me._id, to: target._id, status: 'declined' })) {
    throw new HttpError(409, `${target.name.split(' ')[0]} passed on your last request`);
  }
  const today = await TeamRequest.countDocuments({ from: me._id, createdAt: { $gt: new Date(Date.now() - 864e5) } });
  if (today >= DAILY_REQUEST_LIMIT) throw new HttpError(429, `You can send ${DAILY_REQUEST_LIMIT} requests a day. Try again tomorrow.`);

  const request = await TeamRequest.create({ from: me._id, to: target._id, note, source });
  // They leave my Discover deck, as after a right swipe.
  await User.updateOne({ _id: me._id }, { $addToSet: { swipedRight: target._id }, $pull: { swipedLeft: target._id } });
  res.status(201).json({ match: false, request: { id: request.id, status: request.status } });
}

// GET /api/requests — pending requests to me (best fit first) and the ones I've sent.
export async function listRequests(req, res) {
  const me = req.user;
  const [incoming, sent] = await Promise.all([
    TeamRequest.find({ to: me._id, status: 'pending' }).sort({ createdAt: -1 }).populate('from'),
    TeamRequest.find({ from: me._id, status: 'pending' }).sort({ createdAt: -1 }).populate('to'),
  ]);
  const live = (list, key) => list.filter((r) => r[key] && !r[key].isAdmin);
  const inc = live(incoming, 'from');
  const out = live(sent, 'to');
  const people = await present(me, [...inc.map((r) => r.from), ...out.map((r) => r.to)]);
  const byId = Object.fromEntries(people.map((p) => [p.id, p]));
  const shape = (r, who) => ({ id: r.id, note: r.note, source: r.source, createdAt: r.createdAt, user: byId[r[who].id] });
  res.json({ incoming: inc.map((r) => shape(r, 'from')), sent: out.map((r) => shape(r, 'to')) });
}

async function ownRequest(req, side) {
  const r = mongoose.isValidObjectId(req.params.id) ? await TeamRequest.findById(req.params.id) : null;
  if (!r || !r[side].equals(req.user._id)) throw new HttpError(404, 'Request not found');
  if (r.status !== 'pending') throw new HttpError(409, 'This request was already answered');
  return r;
}

// POST /api/requests/:id/accept — you're matched.
export async function acceptRequest(req, res) {
  const r = await ownRequest(req, 'to');
  await makeMatch(r.from, r.to);
  const from = await User.findById(r.from);
  res.json({ match: true, user: { ...from.toPublic(), email: from.email } });
}

// POST /api/requests/:id/decline — quietly; the sender just sees it stay unanswered.
export async function declineRequest(req, res) {
  const r = await ownRequest(req, 'to');
  r.status = 'declined';
  await r.save();
  await User.updateOne({ _id: req.user._id }, { $addToSet: { swipedLeft: r.from } });
  res.json({ ok: true });
}

// DELETE /api/requests/:id — the sender takes it back.
export async function withdrawRequest(req, res) {
  const r = await ownRequest(req, 'from');
  r.status = 'withdrawn';
  await r.save();
  await User.updateOne({ _id: req.user._id }, { $pull: { swipedRight: r.to } });
  res.status(204).end();
}
