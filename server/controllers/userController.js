import User from '../models/User.js';
import Crew from '../models/Crew.js';
import Event from '../models/Event.js';
import { OPTIONS, MAX_SUPERPOWERS } from '../config/options.js';
import { HttpError } from '../middleware/error.js';

const REQUIRED = ['role', 'experienceLevel', 'schedule', 'commitment', 'communication'];

// The matching code assumes every chip question has an answer.
export const isProfileComplete = (u) =>
  REQUIRED.every((f) => u[f]) && u.interests?.length > 0 && u.skills?.length > 0;

// GET /api/options
export function getOptions(req, res) {
  res.json({ ...OPTIONS, maxSuperpowers: MAX_SUPERPOWERS });
}

// PUT /api/users/me
export async function updateProfile(req, res) {
  const user = req.user;
  Object.assign(user, req.body);
  user.profileComplete = isProfileComplete(user);
  await user.save();
  res.json({ user: user.toSelf() });
}

// GET /api/users/:id
export async function getUser(req, res) {
  const user = await User.findById(req.params.id);
  if (!user || user.isAdmin) throw new HttpError(404, 'User not found');
  res.json({ user: user.toPublic() });
}

// DELETE /api/users/me — removes the account and every trace of it in other users and crews.
export async function deleteAccount(req, res) {
  const id = req.user._id;
  await User.updateMany({}, { $pull: { swipedRight: id, swipedLeft: id, matches: id } });
  if (req.user.crew) await leaveCrewById(req.user.crew, id);
  await req.user.deleteOne();
  res.status(204).end();
}

// Shared with the crew controller: removes a member and dissolves crews of one.
export async function leaveCrewById(crewId, userId) {
  const crew = await Crew.findByIdAndUpdate(crewId, { $pull: { members: userId } }, { returnDocument: 'after' });
  await User.updateOne({ _id: userId }, { crew: null });
  if (crew && crew.members.length <= 1) {
    await User.updateMany({ _id: { $in: crew.members } }, { crew: null });
    await crew.deleteOne();
    // Its event and challenge entries go with it: they free a spot and leave the leaderboard.
    await Event.updateMany({ 'entries.crew': crew._id }, { $pull: { entries: { crew: crew._id } } });
  }
}
