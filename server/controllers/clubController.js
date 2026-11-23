import mongoose from 'mongoose';
import Club, { MAX_CLUBS } from '../models/Club.js';
import User from '../models/User.js';
import Event from '../models/Event.js';
import { HttpError } from '../middleware/error.js';
import { present } from './requestController.js';

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const WEEK = 7 * 24 * 60 * 60 * 1000;

async function findClub(id) {
  const club = mongoose.isValidObjectId(id) ? await Club.findById(id) : null;
  if (!club) throw new HttpError(404, 'Club not found');
  return club;
}

// Member counts and events in the coming week, for a set of clubs.
async function stats(clubs) {
  const ids = clubs.map((c) => c._id);
  const now = new Date();
  const [members, events] = await Promise.all([
    User.aggregate([{ $match: { clubs: { $in: ids } } }, { $unwind: '$clubs' }, { $match: { clubs: { $in: ids } } }, { $group: { _id: '$clubs', n: { $sum: 1 } } }]),
    Event.aggregate([
      { $match: { club: { $in: ids }, endsAt: { $gte: now }, startsAt: { $lte: new Date(now.getTime() + WEEK) } } },
      { $group: { _id: '$club', n: { $sum: 1 } } },
    ]),
  ]);
  const count = (rows) => Object.fromEntries(rows.map((r) => [r._id.toString(), r.n]));
  return { members: count(members), events: count(events) };
}

// A club as students see it: counts, and whether you're in it or lead it.
function shape(club, me, s) {
  return {
    ...club.toPublic(),
    memberCount: s.members[club.id] ?? 0,
    weekEvents: s.events[club.id] ?? 0,
    joined: (me.clubs ?? []).some((id) => id.equals(club._id)),
    isLead: club.leads.includes(me.email),
  };
}

// GET /api/clubs?q=&category=&lead=1
export async function listClubs(req, res) {
  const filter = {};
  const q = String(req.query.q ?? '').trim().slice(0, 40);
  if (q) filter.name = new RegExp(escapeRegex(q), 'i');
  if (req.query.category) filter.category = String(req.query.category);
  if (req.query.lead === '1') filter.leads = req.user.email;
  const clubs = await Club.find(filter).sort({ name: 1 });
  const s = await stats(clubs);
  res.json({ clubs: clubs.map((c) => shape(c, req.user, s)) });
}

// GET /api/clubs/:id — with its upcoming events and members (best fit first).
export async function getClub(req, res) {
  const club = await findClub(req.params.id);
  const [s, events, members] = await Promise.all([
    stats([club]),
    Event.find({ club: club._id, endsAt: { $gte: new Date() } }).sort({ startsAt: 1 }).limit(20)
      .populate([{ path: 'entries.crew', select: 'name members' }, { path: 'createdBy', select: 'name isAdmin' }, { path: 'club', select: 'name short tone verified' }]),
    User.find({ clubs: club._id, _id: { $ne: req.user._id }, isAdmin: false, profileComplete: true }).limit(100),
  ]);
  const people = (await present(req.user, members)).map((p) => ({ ...p, isLead: club.leads.includes(members.find((m) => m.id === p.id)?.email) }));
  people.sort((a, b) => Number(b.isLead) - Number(a.isLead) || b.score - a.score);
  res.json({
    club: shape(club, req.user, s),
    events: events.map((e) => e.toMember(req.user.crew, req.user._id)),
    members: people,
  });
}

// Sets your clubs and returns you.
async function saveClubs(user, ids) {
  if (ids.length > MAX_CLUBS) throw new HttpError(400, `You can be in up to ${MAX_CLUBS} clubs`);
  const found = await Club.countDocuments({ _id: { $in: ids } });
  if (found !== ids.length) throw new HttpError(404, 'Club not found');
  return User.findByIdAndUpdate(user._id, { $set: { clubs: ids } }, { new: true });
}

// POST /api/clubs/:id/join
export async function joinClub(req, res) {
  const club = await findClub(req.params.id);
  const ids = (req.user.clubs ?? []).map(String);
  if (!ids.includes(club.id)) ids.push(club.id);
  const user = await saveClubs(req.user, ids);
  res.json({ user: user.toSelf() });
}

// DELETE /api/clubs/:id/join
export async function leaveClub(req, res) {
  const user = await saveClubs(req.user, (req.user.clubs ?? []).map(String).filter((id) => id !== req.params.id));
  res.json({ user: user.toSelf() });
}

// PUT /api/users/me/clubs  { clubIds } — the club picker.
export async function setMyClubs(req, res) {
  const ids = [...new Set(req.body.clubIds.map(String))].filter((id) => mongoose.isValidObjectId(id));
  const user = await saveClubs(req.user, ids);
  res.json({ user: user.toSelf() });
}

// --- Admin ---

// GET /api/admin/clubs — with leads and member counts.
export async function adminListClubs(req, res) {
  const clubs = await Club.find().sort({ name: 1 });
  const s = await stats(clubs);
  res.json({ clubs: clubs.map((c) => ({ ...c.toPublic(), leads: c.leads, memberCount: s.members[c.id] ?? 0 })) });
}

const adminView = async (club) => {
  const s = await stats([club]);
  return { ...club.toPublic(), leads: club.leads, memberCount: s.members[club.id] ?? 0 };
};

// POST /api/admin/clubs
export async function createClub(req, res) {
  if (await Club.exists({ name: new RegExp(`^${escapeRegex(req.body.name.trim())}$`, 'i') })) {
    throw new HttpError(409, 'A club with that name already exists');
  }
  const club = await Club.create(req.body);
  res.status(201).json({ club: await adminView(club) });
}

// PATCH /api/admin/clubs/:id
export async function updateClub(req, res) {
  const club = await findClub(req.params.id);
  Object.assign(club, req.body);
  await club.save();
  res.json({ club: await adminView(club) });
}

// DELETE /api/admin/clubs/:id — members lose it; its events stay, without the club.
export async function deleteClub(req, res) {
  const club = await findClub(req.params.id);
  await Promise.all([
    User.updateMany({ clubs: club._id }, { $pull: { clubs: club._id } }),
    Event.updateMany({ club: club._id }, { $set: { club: null } }),
    club.deleteOne(),
  ]);
  res.status(204).end();
}
