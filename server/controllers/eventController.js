import mongoose from 'mongoose';
import Event from '../models/Event.js';
import { EVENT_KINDS, CHECKIN_GRACE_MINUTES } from '../config/options.js';
import { HttpError } from '../middleware/error.js';
import { rankCrews } from '../utils/leaderboard.js';

// Crew names and sizes for every entry. A crew that has since dissolved populates to null.
const withCrews = { path: 'entries.crew', select: 'name members' };

// Unknown and malformed ids are both "not found".
async function findEvent(id) {
  const event = mongoose.isValidObjectId(id) ? await Event.findById(id).populate(withCrews) : null;
  if (!event) throw new HttpError(404, 'Event not found');
  return event;
}

const STATE_ORDER = { live: 0, upcoming: 1, ended: 2 };

// Live first (ending soonest), then upcoming (starting soonest), then ended (most recent first).
function byListOrder(a, b) {
  if (a.state !== b.state) return STATE_ORDER[a.state] - STATE_ORDER[b.state];
  const byTime = a.state === 'live' ? a.endsAt - b.endsAt
    : a.state === 'upcoming' ? a.startsAt - b.startsAt
      : b.endsAt - a.endsAt;
  return byTime || a.title.localeCompare(b.title);
}

// Crews take part, not single users. Any member can act for the crew.
function crewOf(user) {
  if (!user.crew) throw new HttpError(409, 'Join or create a crew first');
  return user.crew;
}

const entryOf = (event, crewId) => event.crewEntries().find((e) => e.crew._id.equals(crewId));
const isFull = (event) => event.capacity != null && event.crewEntries().length >= event.capacity;

// Adds the crew's entry unless it already has one, in one atomic update,
// so two members tapping at the same moment can't add it twice.
function addEntry(eventId, crewId) {
  return Event.updateOne({ _id: eventId, 'entries.crew': { $ne: crewId } }, { $push: { entries: { crew: crewId } } });
}

// Changes one crew's entry in place. With `open`, only while it isn't completed,
// so points can't be awarded twice. Resolves to whether an entry matched.
async function setEntry(eventId, crewId, changes, { open = false } = {}) {
  const match = open ? { crew: crewId, status: { $ne: 'completed' } } : { crew: crewId };
  const $set = Object.fromEntries(Object.entries(changes).map(([k, v]) => [`entries.$.${k}`, v]));
  const { matchedCount } = await Event.updateOne({ _id: eventId, entries: { $elemMatch: match } }, { $set });
  return matchedCount > 0;
}

// The event as the signed-in user sees it, read again after a change.
async function memberView(id, user) {
  return (await findEvent(id)).toMember(user.crew);
}

// GET /api/events?kind=event|challenge
export async function listEvents(req, res) {
  const { kind } = req.query;
  if (kind && !EVENT_KINDS.includes(kind)) throw new HttpError(400, 'kind must be "event" or "challenge"');
  const events = await Event.find(kind ? { kind } : {}).populate(withCrews);
  res.json({ events: events.map((e) => e.toMember(req.user.crew)).sort(byListOrder) });
}

// GET /api/events/:id — with the crews taking part.
export async function getEvent(req, res) {
  const event = await findEvent(req.params.id);
  const crews = event.crewEntries().map((e) => ({
    id: e.crew.id,
    name: e.crew.name,
    memberCount: e.crew.members.length,
    status: e.status,
  }));
  res.json({ event: { ...event.toMember(req.user.crew), crews } });
}

// POST /api/events/:id/join — RSVP to an event or accept a challenge. Joining again is a no-op.
export async function joinEvent(req, res) {
  const event = await findEvent(req.params.id);
  const crewId = crewOf(req.user);
  if (!entryOf(event, crewId)) {
    if (event.state === 'ended') throw new HttpError(409, 'This has ended');
    if (isFull(event)) throw new HttpError(409, 'This is full');
    await addEntry(event._id, crewId);
  }
  res.json({ event: await memberView(event._id, req.user) });
}

// DELETE /api/events/:id/join — only while nothing has been submitted or awarded.
export async function leaveEvent(req, res) {
  const event = await findEvent(req.params.id);
  const entry = req.user.crew && entryOf(event, req.user.crew);
  if (entry) {
    if (entry.status !== 'joined') throw new HttpError(409, "You can't leave after submitting");
    await Event.updateOne({ _id: event._id }, { $pull: { entries: { crew: req.user.crew, status: 'joined' } } });
  }
  res.json({ event: await memberView(event._id, req.user) });
}

// POST /api/events/:id/checkin  { code } — at the venue. Works without an RSVP first.
export async function checkIn(req, res) {
  const event = await findEvent(req.params.id);
  if (event.kind !== 'event') throw new HttpError(400, 'Only events have a check-in');
  const crewId = crewOf(req.user);
  if (entryOf(event, crewId)?.status === 'completed') throw new HttpError(409, 'Your crew already checked in');
  if (Date.now() > event.endsAt.getTime() + CHECKIN_GRACE_MINUTES * 60 * 1000) {
    throw new HttpError(409, 'This has ended');
  }
  // Stored upper case; members may type it any way.
  if (req.body.code.toUpperCase() !== event.checkinCode) throw new HttpError(400, 'Wrong check-in code');

  await addEntry(event._id, crewId);
  const checkedIn = await setEntry(
    event._id, crewId, { status: 'completed', pointsAwarded: event.points, completedAt: new Date() }, { open: true }
  );
  if (!checkedIn) throw new HttpError(409, 'Your crew already checked in');
  res.json({ event: await memberView(event._id, req.user), pointsAwarded: event.points });
}

// POST /api/events/:id/submit  { url, note? } — sends the crew's link for review, or replaces it.
export async function submitEntry(req, res) {
  const event = await findEvent(req.params.id);
  if (event.kind !== 'challenge') throw new HttpError(400, 'Only challenges take submissions');
  const crewId = crewOf(req.user);
  const entry = entryOf(event, crewId);
  if (entry?.status === 'completed') throw new HttpError(409, 'Already completed');
  if (event.state === 'ended') throw new HttpError(409, 'This has ended');
  if (!entry) {
    // Submitting without accepting first takes a spot, the same as joining.
    if (isFull(event)) throw new HttpError(409, 'This is full');
    await addEntry(event._id, crewId);
  }

  const submitted = await setEntry(
    event._id, crewId, { status: 'submitted', submissionUrl: req.body.url, note: req.body.note || null }, { open: true }
  );
  if (!submitted) throw new HttpError(409, 'Already completed');
  res.json({ event: await memberView(event._id, req.user) });
}

// GET /api/leaderboard
export async function getLeaderboard(req, res) {
  res.json({
    title: process.env.HACKATHON_NAME || 'MERNOVA X 2026',
    updatedAt: new Date(),
    myCrewId: req.user.crew ? req.user.crew.toString() : null,
    crews: await rankCrews(),
  });
}

// --- Admin ---

// GET /api/admin/events — with check-in codes and every crew's entry.
export async function adminListEvents(req, res) {
  const events = await Event.find().populate(withCrews);
  res.json({ events: events.map((e) => e.toAdmin()).sort(byListOrder) });
}

// POST /api/admin/events — an event without a checkinCode gets a generated one.
export async function createEvent(req, res) {
  const event = await Event.create({ ...req.body, createdBy: req.user._id });
  res.status(201).json({ event: event.toAdmin() });
}

// PATCH /api/admin/events/:id — partial update. Points already awarded stay as they are.
export async function updateEvent(req, res) {
  const event = await findEvent(req.params.id);
  Object.assign(event, req.body);
  await event.save();
  res.json({ event: event.toAdmin() });
}

// DELETE /api/admin/events/:id
export async function deleteEvent(req, res) {
  const event = await findEvent(req.params.id);
  await event.deleteOne();
  res.status(204).end();
}

async function reviewEntry(req, res, changes) {
  const event = await findEvent(req.params.id);
  const { crewId } = req.params;
  const found = mongoose.isValidObjectId(crewId) && (await setEntry(event._id, crewId, changes(event)));
  if (!found) throw new HttpError(404, 'Entry not found');
  res.json({ event: (await findEvent(event._id)).toAdmin() });
}

// POST /api/admin/events/:id/entries/:crewId/approve  { points? } — works on any status.
// `points` overrides the event's points, e.g. for a podium bonus.
export function approveEntry(req, res) {
  return reviewEntry(req, res, (event) => ({
    status: 'completed',
    pointsAwarded: req.body.points ?? event.points,
    completedAt: new Date(),
  }));
}

// POST /api/admin/events/:id/entries/:crewId/reject  { note? } — back to joined, with the reason.
export function rejectEntry(req, res) {
  return reviewEntry(req, res, () => ({
    status: 'joined',
    pointsAwarded: 0,
    completedAt: null,
    note: req.body.note || null,
  }));
}
