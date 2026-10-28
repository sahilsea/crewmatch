import User from '../models/User.js';
import Crew from '../models/Crew.js';
import { crewChecklist } from '../utils/matching.js';
import { MAX_CREW_SIZE } from '../config/options.js';
import { HttpError } from '../middleware/error.js';
import { rankCrews } from '../utils/leaderboard.js';
import { leaveCrewById } from './userController.js';

async function crewResponse(crewId) {
  const [crew, ranking] = await Promise.all([Crew.findById(crewId).populate('members'), rankCrews()]);
  if (!crew) return null;
  // Same numbers as the leaderboard.
  const standing = ranking.find((c) => c.id === crew.id);
  return {
    id: crew.id,
    name: crew.name,
    createdBy: crew.createdBy.toString(),
    members: crew.members.map((m) => ({ ...m.toPublic(), email: m.email })),
    checklist: crewChecklist(crew.members),
    ideas: crew.ideas,
    spotsLeft: MAX_CREW_SIZE - crew.members.length,
    points: standing?.points ?? 0,
    rank: standing?.rank ?? null,
  };
}

// New members must be your matches and not already in a crew.
async function checkJoinable(me, ids) {
  for (const id of ids) {
    if (!me.matches.some((m) => m.equals(id))) throw new HttpError(400, 'You can only add your matches');
  }
  const taken = await User.find({ _id: { $in: ids }, crew: { $ne: null } }, 'name');
  if (taken.length) {
    throw new HttpError(409, `Already in a crew: ${taken.map((u) => u.name).join(', ')}`);
  }
}

// POST /api/crews  { name, memberIds }
export async function createCrew(req, res) {
  const me = req.user;
  if (me.crew) throw new HttpError(409, 'You are already in a crew');

  const memberIds = [...new Set(req.body.memberIds)];
  await checkJoinable(me, memberIds);

  const crew = await Crew.create({ name: req.body.name, createdBy: me._id, members: [me._id, ...memberIds] });
  await User.updateMany({ _id: { $in: crew.members } }, { crew: crew._id });
  res.status(201).json({ crew: await crewResponse(crew._id) });
}

// GET /api/crews/mine
export async function getMyCrew(req, res) {
  if (!req.user.crew) return res.json({ crew: null });
  res.json({ crew: await crewResponse(req.user.crew) });
}

// POST /api/crews/mine/members  { userId }
export async function addMember(req, res) {
  const me = req.user;
  if (!me.crew) throw new HttpError(404, 'You are not in a crew');
  const crew = await Crew.findById(me.crew);
  if (crew.members.length >= MAX_CREW_SIZE) throw new HttpError(409, `Crews are capped at ${MAX_CREW_SIZE}`);

  await checkJoinable(me, [req.body.userId]);
  crew.members.addToSet(req.body.userId);
  await crew.save();
  await User.updateOne({ _id: req.body.userId }, { crew: crew._id });
  res.json({ crew: await crewResponse(crew._id) });
}

// PATCH /api/crews/mine  { name }
export async function renameCrew(req, res) {
  if (!req.user.crew) throw new HttpError(404, 'You are not in a crew');
  await Crew.updateOne({ _id: req.user.crew }, { name: req.body.name }, { runValidators: true });
  res.json({ crew: await crewResponse(req.user.crew) });
}

// DELETE /api/crews/mine — leave your crew. A crew left with one person is dissolved.
export async function leaveCrew(req, res) {
  if (!req.user.crew) throw new HttpError(404, 'You are not in a crew');
  await leaveCrewById(req.user.crew, req.user._id);
  res.status(204).end();
}
