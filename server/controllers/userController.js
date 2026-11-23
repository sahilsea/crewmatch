import User from '../models/User.js';
import TeamRequest from '../models/TeamRequest.js';
import Crew from '../models/Crew.js';
import Event from '../models/Event.js';
import Post from '../models/Post.js';
import Photo from '../models/Photo.js';
import Message from '../models/Message.js';
import { decodeDataUrl, ownPhotoId, photoUrl } from '../utils/uploads.js';
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
  if (req.body.cover === 'photo' && !user.coverPhoto) throw new HttpError(400, 'Upload a cover photo first');
  Object.assign(user, req.body);
  user.profileComplete = isProfileComplete(user);
  await user.save();
  res.json({ user: user.toSelf() });
}

// Stores an uploaded image and returns its id. Replaces nothing by itself.
async function savePhoto(user, dataUrl) {
  const { type, data } = decodeDataUrl(dataUrl, { what: 'Photos' });
  return (await Photo.create({ owner: user._id, type, data }))._id;
}

// POST /api/users/me/avatar  { photo }  — your profile picture.
export async function uploadAvatar(req, res) {
  const user = req.user;
  const old = ownPhotoId(user.avatar);
  user.avatar = photoUrl(await savePhoto(user, req.body.photo));
  await user.save();
  if (old) await Photo.deleteOne({ _id: old, owner: user._id });
  res.json({ user: user.toSelf() });
}

// DELETE /api/users/me/avatar — back to initials.
export async function removeAvatar(req, res) {
  const user = req.user;
  const old = ownPhotoId(user.avatar);
  user.avatar = '';
  await user.save();
  if (old) await Photo.deleteOne({ _id: old, owner: user._id });
  res.json({ user: user.toSelf() });
}

// POST /api/users/me/cover  { photo }  — a photo behind your card; also switches the cover to it.
export async function uploadCover(req, res) {
  const user = req.user;
  const old = user.coverPhoto;
  user.coverPhoto = await savePhoto(user, req.body.photo);
  user.cover = 'photo';
  await user.save();
  if (old) await Photo.deleteOne({ _id: old, owner: user._id });
  res.json({ user: user.toSelf() });
}

// DELETE /api/users/me/cover — removes the cover photo; the card goes back to a preset.
export async function removeCover(req, res) {
  const user = req.user;
  const old = user.coverPhoto;
  user.coverPhoto = null;
  if (user.cover === 'photo') user.cover = 'dusk';
  await user.save();
  if (old) await Photo.deleteOne({ _id: old, owner: user._id });
  res.json({ user: user.toSelf() });
}

// GET /api/users/:id/activity — what someone has done at the hackathon, newest
// first: posts, their crew, the crew's check-ins and challenges, and whether
// they matched with you.
export async function getActivity(req, res) {
  const user = await User.findById(req.params.id);
  if (!user || user.isAdmin) throw new HttpError(404, 'User not found');
  const items = [];

  const posts = await Post.find({ author: user._id }, 'text createdAt').sort({ createdAt: -1 }).limit(10);
  for (const p of posts) {
    items.push({ kind: 'post', text: `Posted “${p.text.length > 60 ? `${p.text.slice(0, 57)}…` : p.text}”`, at: p.createdAt });
  }

  if (user.crew) {
    const crew = await Crew.findById(user.crew, 'name createdAt');
    if (crew) {
      items.push({ kind: 'crew', text: `Joined ${crew.name}`, at: crew.createdAt });
      const events = await Event.find({ 'entries.crew': crew._id }, 'title kind entries');
      for (const e of events) {
        const entry = e.entries.find((x) => x.crew?.equals(crew._id));
        if (entry?.status === 'completed') {
          items.push({
            kind: 'points',
            text: `${crew.name} ${e.kind === 'event' ? 'checked in at' : 'completed'} ${e.title} · +${entry.pointsAwarded}`,
            at: entry.completedAt,
          });
        } else if (entry?.status === 'submitted') {
          items.push({ kind: 'points', text: `${crew.name} submitted ${e.title}`, at: entry.joinedAt });
        }
      }
    }
  }

  // No date is kept for matches, so this one sorts last.
  if (req.user.matches.some((id) => id.equals(user._id))) items.push({ kind: 'match', text: 'Matched with you', at: null });

  items.sort((a, b) => (b.at ? b.at.getTime() : -Infinity) - (a.at ? a.at.getTime() : -Infinity));
  res.json({ activity: items.slice(0, 20) });
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
  await TeamRequest.deleteMany({ $or: [{ from: id }, { to: id }] });
  if (req.user.crew) await leaveCrewById(req.user.crew, id);
  // Their posts, photos, likes and comments go too. Chat lines stay, unsigned.
  await Promise.all([
    Post.deleteMany({ author: id }),
    Photo.deleteMany({ owner: id }),
    Post.updateMany({}, { $pull: { likes: id, comments: { author: id } } }),
  ]);
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
    await Message.deleteMany({ crew: crew._id });
  }
}
