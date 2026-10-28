import User from '../models/User.js';
import { compatibility, reasonTags } from '../utils/matching.js';
import { HttpError } from '../middleware/error.js';

// GET /api/matches — your matches with contact details, newest first.
export async function getMatches(req, res) {
  const me = req.user;
  const people = await User.find({ _id: { $in: me.matches } });
  const order = new Map(me.matches.map((id, i) => [id.toString(), i]));

  const matches = people
    .sort((a, b) => order.get(b.id) - order.get(a.id))
    .map((p) => ({
      ...p.toPublic(),
      email: p.email,
      inCrew: Boolean(p.crew),
      score: compatibility([me], p),
      tags: reasonTags([me], p),
    }));

  res.json({ count: matches.length, matches });
}

// DELETE /api/matches/:id — unmatch. They won't show up in your deck again.
export async function unmatch(req, res) {
  const me = req.user;
  const { id } = req.params;
  if (!me.matches.some((m) => m.equals(id))) throw new HttpError(404, 'Not one of your matches');

  await Promise.all([
    User.updateOne({ _id: me._id }, { $pull: { matches: id, swipedRight: id }, $addToSet: { swipedLeft: id } }),
    User.updateOne({ _id: id }, { $pull: { matches: me._id } }),
  ]);
  res.status(204).end();
}
